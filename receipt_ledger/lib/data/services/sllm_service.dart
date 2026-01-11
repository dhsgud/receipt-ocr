import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../models/receipt.dart';

/// Service for SLLM OCR integration
class SllmService {
  final Dio _dio;

  SllmService() : _dio = Dio(BaseOptions(
    baseUrl: AppConstants.sllmBaseUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 180),  // 3분 - 비전 모델 이미지 처리 시간 고려
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  /// Parse receipt image from bytes (web-compatible)
  Future<ReceiptData> parseReceiptFromBytes(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);
      return await _parseReceiptFromBase64(base64Image);
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    } catch (e) {
      throw Exception('영수증 분석 실패: $e');
    }
  }

  /// Get user-friendly error message from DioException
  String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'SLLM 서버 연결 시간 초과. 네트워크를 확인해주세요.';
      case DioExceptionType.connectionError:
        return 'SLLM 서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.\n서버 주소: ${AppConstants.sllmBaseUrl}';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          return 'SLLM API 엔드포인트를 찾을 수 없습니다 (404). API 경로를 확인해주세요.\n현재 설정: ${AppConstants.sllmBaseUrl}${AppConstants.sllmOcrEndpoint}';
        } else if (statusCode == 500) {
          return 'SLLM 서버 내부 오류 (500). 서버 로그를 확인해주세요.';
        } else if (statusCode == 401 || statusCode == 403) {
          return 'SLLM 서버 인증 실패. API 키가 필요할 수 있습니다.';
        }
        return 'SLLM 서버 오류: HTTP $statusCode';
      default:
        return 'SLLM 오류: ${e.message}';
    }
  }

  /// Internal method to parse receipt from base64 encoded image
  Future<ReceiptData> _parseReceiptFromBase64(String base64Image) async {
    try {
      // Try OpenAI-compatible format first (most common for local LLMs)
      final payload = {
        'model': 'default',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': '''이 영수증 이미지를 분석하고 다음 정보를 JSON 형식으로 추출해주세요:
{
  "store_name": "상호명",
  "date": "YYYY-MM-DD 형식의 날짜",
  "total_amount": 총 금액 (숫자만),
  "items": [
    {
      "name": "상품명",
      "quantity": 수량,
      "unit_price": 단가,
      "total_price": 금액
    }
  ],
  "raw_text": "영수증 전체 텍스트"
}

JSON만 반환하고 다른 텍스트는 포함하지 마세요.'''
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image'
                }
              }
            ]
          }
        ],
        'max_tokens': 1000,
      };

      // Send request to SLLM server
      final response = await _dio.post(
        AppConstants.sllmOcrEndpoint,
        data: payload,
      );

      // Parse response
      if (response.statusCode == 200) {
        final responseData = response.data;
        
        // Handle OpenAI-compatible response format
        Map<String, dynamic> jsonData;
        if (responseData is Map<String, dynamic>) {
          // Try to extract from choices[0].message.content
          final choices = responseData['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final message = choices[0]['message'] as Map<String, dynamic>?;
            final content = message?['content'] as String?;
            if (content != null) {
              jsonData = _extractJsonFromText(content);
            } else {
              jsonData = responseData;
            }
          } else {
            // Check if response contains a 'result' or 'response' field
            jsonData = responseData['result'] as Map<String, dynamic>? ??
                       responseData['response'] as Map<String, dynamic>? ??
                       responseData;
          }
        } else if (responseData is String) {
          jsonData = _extractJsonFromText(responseData);
        } else {
          throw Exception('Unexpected response format');
        }

        return ReceiptData.fromSllmResponse(jsonData);
      } else {
        throw Exception('SLLM request failed: ${response.statusCode}');
      }
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('영수증 분석 실패: $e');
    }
  }

  /// Extract JSON from text that may contain other content
  Map<String, dynamic> _extractJsonFromText(String text) {
    // Find JSON object in the text
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final match = jsonPattern.firstMatch(text);
    
    if (match != null) {
      try {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      } catch (_) {
        // If parsing fails, return minimal data
      }
    }

    // Try to extract data manually from text
    return _parseReceiptText(text);
  }

  /// Parse receipt data from raw OCR text
  Map<String, dynamic> _parseReceiptText(String text) {
    final result = <String, dynamic>{
      'raw_text': text,
    };

    // Try to extract total amount (common patterns in Korean receipts)
    final amountPatterns = [
      RegExp(r'총[\s]?금[\s]?액[\s:]*([0-9,]+)'),
      RegExp(r'합[\s]?계[\s:]*([0-9,]+)'),
      RegExp(r'결[\s]?제[\s:]*([0-9,]+)'),
      RegExp(r'TOTAL[\s:]*([0-9,]+)'),
    ];

    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        result['total_amount'] = int.tryParse(amountStr);
        break;
      }
    }

    // Try to extract date
    final datePattern = RegExp(r'(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})');
    final dateMatch = datePattern.firstMatch(text);
    if (dateMatch != null) {
      result['date'] = '${dateMatch.group(1)}-${dateMatch.group(2)!.padLeft(2, '0')}-${dateMatch.group(3)!.padLeft(2, '0')}';
    }

    return result;
  }

  /// Test connection to SLLM server
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
