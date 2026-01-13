import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import '../models/receipt.dart';

/// 네이티브 플랫폼용 로컬 OCR 서비스 (llama_cpp_dart 0.2.x 기반)
class LocalOcrServiceImpl {
  LlamaParent? _llamaParent;
  bool _isLoaded = false;
  bool _isLoading = false;
  String? _modelPath;
  String? _mmprojPath;
  StreamSubscription<String>? _streamSubscription;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  /// 모델 로드 (isolate 기반)
  Future<void> initialize(String modelPath, String mmprojPath) async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;

    try {
      // 파일 존재 및 크기 확인
      final modelFile = File(modelPath);
      final mmprojFile = File(mmprojPath);
      
      if (!await modelFile.exists()) {
        throw Exception('Model file not found: $modelPath');
      }
      if (!await mmprojFile.exists()) {
        throw Exception('Mmproj file not found: $mmprojPath');
      }
      
      final modelSize = await modelFile.length();
      final mmprojSize = await mmprojFile.length();
      
      debugPrint('[LocalOCR] Model file: $modelPath');
      debugPrint('[LocalOCR] Model size: ${(modelSize / 1024 / 1024).toStringAsFixed(2)} MB');
      debugPrint('[LocalOCR] Mmproj file: $mmprojPath');
      debugPrint('[LocalOCR] Mmproj size: ${(mmprojSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // 파일 크기가 너무 작으면 다운로드 실패로 간주
      if (modelSize < 100 * 1024 * 1024) { // 100MB 미만이면 오류
        throw Exception('Model file seems incomplete: ${(modelSize / 1024 / 1024).toStringAsFixed(2)} MB (expected ~1GB+)');
      }
      if (mmprojSize < 1 * 1024 * 1024) { // 1MB 미만이면 오류
        throw Exception('Mmproj file seems incomplete: ${(mmprojSize / 1024 / 1024).toStringAsFixed(2)} MB');
      }

      _modelPath = modelPath;
      _mmprojPath = mmprojPath;

      // LlamaParent 설정 (isolate 기반으로 UI 블로킹 방지)
      // llama_cpp_dart 0.2.x API - Vision 모델은 mmproj 필수!
      final loadCommand = LlamaLoad(
        path: modelPath,
        mmprojPath: mmprojPath,  // Vision projector 파일 경로 추가
        modelParams: ModelParams(),
        contextParams: ContextParams(),
        samplingParams: SamplerParams(),
      );

      _llamaParent = LlamaParent(loadCommand);
      await _llamaParent!.init();

      _isLoaded = true;
      _isLoading = false;
      debugPrint('[LocalOCR] Model loaded successfully');
    } catch (e) {
      _isLoading = false;
      debugPrint('[LocalOCR] Failed to load model: $e');
      rethrow;
    }
  }

  /// 이미지에서 영수증 정보 추출 (바이트 배열)
  Future<ReceiptData> parseReceiptFromBytes(Uint8List imageBytes) async {
    if (!_isLoaded || _llamaParent == null) {
      throw Exception('Local OCR model not loaded. Please load the model first.');
    }

    try {
      // 1. 이미지를 base64로 인코딩
      final base64Image = base64Encode(imageBytes);

      // 2. Vision 프롬프트 구성 (ChatML 형식)
      final prompt = '''Extract receipt information as JSON:
- store_name: string
- date: YYYY-MM-DD
- total_amount: integer
- items: [{name, quantity, unit_price, total_price}]

Image: <image>data:image/jpeg;base64,$base64Image</image>

Return ONLY valid JSON:''';

      debugPrint('[LocalOCR] Starting inference...');

      // 3. 추론 실행
      final response = await _runInference(prompt);
      
      debugPrint('[LocalOCR] Response: ${response.substring(0, response.length.clamp(0, 100))}...');

      // 4. JSON 파싱
      final data = _parseJson(response);
      
      return ReceiptData.fromSllmResponse(data);
    } catch (e) {
      debugPrint('[LocalOCR] Error: $e');
      throw Exception('Local OCR failed: $e');
    }
  }

  /// 추론 실행 (스트림을 완료된 문자열로 변환)
  Future<String> _runInference(String prompt) async {
    final buffer = StringBuffer();
    final completer = Completer<String>();

    _streamSubscription?.cancel();
    _streamSubscription = _llamaParent!.stream.listen(
      (token) {
        buffer.write(token);
        // JSON 완료 체크
        final content = buffer.toString();
        if (content.contains('}') && _isCompleteJson(content)) {
          if (!completer.isCompleted) {
            completer.complete(content);
          }
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    // 프롬프트 전송
    _llamaParent!.sendPrompt(prompt);

    // 타임아웃 설정 (2분)
    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _streamSubscription?.cancel();
        final result = buffer.toString();
        if (result.isNotEmpty) {
          return result;
        }
        throw TimeoutException('Local OCR inference timed out');
      },
    );
  }

  bool _isCompleteJson(String content) {
    try {
      final startIdx = content.indexOf('{');
      if (startIdx == -1) return false;
      
      int braceCount = 0;
      for (int i = startIdx; i < content.length; i++) {
        if (content[i] == '{') braceCount++;
        if (content[i] == '}') braceCount--;
        if (braceCount == 0) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// JSON 파싱 (마크다운 코드 블록 처리 포함)
  Map<String, dynamic> _parseJson(String content) {
    String jsonStr = content.trim();

    // Markdown 코드 블록 제거
    if (jsonStr.contains('```json')) {
      jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
    } else if (jsonStr.contains('```')) {
      final parts = jsonStr.split('```');
      if (parts.length >= 2) {
        jsonStr = parts[1].trim();
      }
    }

    // JSON 객체 추출
    final startIndex = jsonStr.indexOf('{');
    final endIndex = jsonStr.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      jsonStr = jsonStr.substring(startIndex, endIndex + 1);
    }

    try {
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[LocalOCR] JSON parse error: $jsonStr');
      // 기본값 반환
      return {
        'store_name': 'Unknown',
        'date': DateTime.now().toString().split(' ')[0],
        'total_amount': 0,
        'items': [],
      };
    }
  }

  /// 리소스 해제
  void dispose() {
    _streamSubscription?.cancel();
    _llamaParent?.stop();  // stop isolate
    _llamaParent = null;
    _modelPath = null;
    _mmprojPath = null;
    _isLoaded = false;
    _isLoading = false;
    debugPrint('[LocalOCR] Model unloaded');
  }
}
