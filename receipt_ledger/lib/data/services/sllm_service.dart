import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../models/receipt.dart';

/// Gemini OCR 서버를 통한 영수증 분석 서비스
class SllmService {
  final Dio _dio;

  SllmService() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 600),
    headers: {'Content-Type': 'application/json'},
  ));

  /// Gemini OCR 서버로 영수증 분석 요청
  /// [cancelToken]을 전달하면 요청을 취소할 수 있음
  Future<ReceiptData> parseReceiptFromBytes(
    Uint8List imageBytes, {
    String? ocrServerUrl,
    String provider = 'gemini',
    CancelToken? cancelToken,
  }) async {
    try {
      return await _parseWithOcrServer(
        imageBytes, 
        ocrServerUrl ?? AppConstants.syncServerUrl,
        provider: provider,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw Exception('요청이 취소되었습니다');
      }
      throw Exception(_getDioErrorMessage(e));
    } catch (e) {
      throw Exception('영수증 분석 실패: $e');
    }
  }

  /// OCR 서버로 요청 (Python FastAPI + Gemini)
  Future<ReceiptData> _parseWithOcrServer(Uint8List imageBytes, String serverUrl, {String provider = 'gemini', CancelToken? cancelToken}) async {
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
      return ReceiptData.fromOcrResponse(data);
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
