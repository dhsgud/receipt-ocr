import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/receipt.dart';

/// OCR 모드에 따른 영수증 분석 서비스
class SllmService {
  final Dio _dio;

  SllmService() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 600), // Match server timeout
    headers: {'Content-Type': 'application/json'},
  ));

  /// OCR 모드에 따라 적절한 서버로 요청
  /// [cancelToken]을 전달하면 요청을 취소할 수 있음
  Future<ReceiptData> parseReceiptFromBytes(
    Uint8List imageBytes, {
    required String mode,  // 'externalLlama', 'server', 'local', 'auto'
    String? externalLlamaUrl,
    String? ocrServerUrl,
    String? provider, // 'auto', 'gemini', 'gpt', 'claude', 'grok' (Only used when mode='server')
    CancelToken? cancelToken,
  }) async {
    try {
      switch (mode) {
        case 'externalLlama':
          return await _parseWithExternalLlama(
            imageBytes, 
            externalLlamaUrl ?? 'http://183.96.3.137:408',
            cancelToken: cancelToken,
          );
        case 'server':
          return await _parseWithOcrServer(
            imageBytes, 
            ocrServerUrl ?? 'http://183.96.3.137:9999',
            provider: provider ?? 'auto',
            cancelToken: cancelToken,
          );
        case 'local':
          throw Exception('로컬 OCR은 LocalOcrService를 사용하세요');
        case 'auto':
        default:
          // 자동: 외부 llama.cpp 먼저 시도, 실패시 OCR 서버
          try {
            return await _parseWithExternalLlama(
              imageBytes, 
              externalLlamaUrl ?? 'http://183.96.3.137:408',
              cancelToken: cancelToken,
            );
          } catch (e) {
            if (e is DioException && e.type == DioExceptionType.cancel) {
              rethrow; // 취소된 경우 재시도하지 않음
            }
            debugPrint('[SllmService] External llama failed: $e, trying OCR server');
            return await _parseWithOcrServer(
              imageBytes, 
              ocrServerUrl ?? 'http://183.96.3.137:9999',
              cancelToken: cancelToken,
            );
          }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw Exception('요청이 취소되었습니다');
      }
      throw Exception(_getDioErrorMessage(e));
    } catch (e) {
      throw Exception('영수증 분석 실패: $e');
    }
  }

  /// 외부 llama.cpp 서버로 직접 요청 (Vision 모델)
  Future<ReceiptData> _parseWithExternalLlama(Uint8List imageBytes, String serverUrl, {CancelToken? cancelToken}) async {
    final base64Image = base64Encode(imageBytes);
    
    final prompt = """영수증을 분석해주세요.

## 분석 단계 (순서대로)
1️⃣ 상호명 확인: 약국→의료, 카페→카페, 편의점→편의점, 마트→마트, 주유소→교통, 병원→의료, 식당→식비
2️⃣ 품목 확인: 약→의료, 커피→카페, 음식→식비, 주유→교통
3️⃣ 상호+품목 종합하여 카테고리 결정

## JSON 형식
{"store_name":"상호명","date":"YYYY-MM-DD","total_amount":금액,"category":"카테고리","is_income":false,"items":[{"name":"품목","quantity":수량,"unit_price":단가,"total_price":금액}]}

## 카테고리: 의료, 카페, 편의점, 마트, 식비, 교통, 쇼핑, 생활, 문화, 기타

JSON만 반환.""";

    final response = await _dio.post(
      '$serverUrl/v1/chat/completions',
      data: {
        'model': 'user-model',
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
              }
            ]
          }
        ],
        'temperature': 0.1,
        'max_tokens': 1024,
      },
      cancelToken: cancelToken,
    );

    if (response.statusCode == 200) {
      final content = response.data['choices'][0]['message']['content'] as String;
      final parsed = _parseJsonFromResponse(content);
      return ReceiptData.fromSllmResponse(parsed);
    } else {
      throw Exception('External llama request failed: ${response.statusCode}');
    }
  }

  /// 내부 OCR 서버로 요청 (Python FastAPI)
  Future<ReceiptData> _parseWithOcrServer(Uint8List imageBytes, String serverUrl, {String provider = 'auto', CancelToken? cancelToken}) async {
    final base64Image = base64Encode(imageBytes);
    
    final response = await _dio.post(
      '$serverUrl/api/ocr',
      data: {
        'image': 'data:image/jpeg;base64,$base64Image',
        'preprocess': true,
        'provider': provider,
      },
      cancelToken: cancelToken,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return ReceiptData.fromSllmResponse(data);
    } else {
      throw Exception('OCR server request failed: ${response.statusCode}');
    }
  }

  /// JSON 파싱 (마크다운 코드 블록 처리 포함)
  Map<String, dynamic> _parseJsonFromResponse(String content) {
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
      debugPrint('[SllmService] JSON parse error: $jsonStr');
      return {
        'store_name': 'Unknown',
        'date': DateTime.now().toString().split(' ')[0],
        'total_amount': 0,
        'items': [],
        'category': '기타',
      };
    }
  }

  /// DioException 에러 메시지
  String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'OCR 서버 연결 시간 초과. 네트워크를 확인해주세요.';
      case DioExceptionType.connectionError:
        return 'OCR 서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          return 'OCR API 엔드포인트를 찾을 수 없습니다 (404).';
        } else if (statusCode == 500) {
          return 'OCR 서버 내부 오류 (500). 서버 로그를 확인해주세요.';
        }
        return 'OCR 서버 오류: HTTP $statusCode';
      default:
        return 'OCR 오류: ${e.message}';
    }
  }

  /// 외부 llama.cpp 서버 연결 테스트
  Future<bool> testExternalLlama(String serverUrl) async {
    try {
      final response = await _dio.get('$serverUrl/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// OCR 서버 연결 테스트
  Future<bool> testOcrServer(String serverUrl) async {
    try {
      final response = await _dio.get('$serverUrl/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
