import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../models/receipt.dart';

/// Service for OCR integration
/// PaddleOCR 서버만 사용 (SLLM 제거)
class SllmService {
  final Dio _ocrDio;  // PaddleOCR 서버용

  SllmService() 
    : _ocrDio = Dio(BaseOptions(
        baseUrl: AppConstants.syncServerUrl,  // OCR는 sync_server와 같은 URL
        connectTimeout: const Duration(seconds: 60),   // 연결 타임아웃 60초
        receiveTimeout: const Duration(seconds: 300),  // 응답 타임아웃 300초 (5분)
        headers: {'Content-Type': 'application/json'},
      ));

  /// Parse receipt image from bytes (web-compatible)
  Future<ReceiptData> parseReceiptFromBytes(Uint8List imageBytes) async {
    try {
      return await _parseWithPaddleOCR(imageBytes);
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    } catch (e) {
      throw Exception('영수증 분석 실패: $e');
    }
  }

  /// PaddleOCR 서버로 영수증 처리
  Future<ReceiptData> _parseWithPaddleOCR(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    
    final response = await _ocrDio.post(
      AppConstants.ocrEndpoint,
      data: {
        'image': 'data:image/jpeg;base64,$base64Image',
        'preprocess': true,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return ReceiptData.fromSllmResponse(data);
    } else {
      throw Exception('OCR request failed: ${response.statusCode}');
    }
  }

  /// Get user-friendly error message from DioException
  String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'OCR 서버 연결 시간 초과. 네트워크를 확인해주세요.';
      case DioExceptionType.connectionError:
        return 'OCR 서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.\n서버 주소: ${AppConstants.syncServerUrl}';
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

  /// Test connection to OCR server
  Future<bool> testConnection() async {
    try {
      final response = await _ocrDio.get('/api/ocr/status');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Check OCR server status
  Future<Map<String, dynamic>> getOcrStatus() async {
    try {
      final response = await _ocrDio.get('/api/ocr/status');
      if (response.statusCode == 200) {
        return {
          'available': true,
          'type': 'paddleocr',
          ...response.data as Map<String, dynamic>,
        };
      }
    } catch (_) {}
    
    return {
      'available': false,
      'type': 'none',
    };
  }
}
