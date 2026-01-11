/// SLLM Server Configuration and App Constants
class AppConstants {
  // SLLM OCR Server (Legacy - VL model)
  // 포트 번호: 0408 -> 408 (앞의 0 제거)
  static const String sllmBaseUrl = 'http://183.96.3.137:408';
  static const String sllmOcrEndpoint = '/v1/chat/completions';
  
  // OCR Server (PaddleOCR on Raspberry Pi)
  // sync_server와 같은 URL 사용
  static const String ocrEndpoint = '/api/ocr';
  
  // Sync Server (same machine as SLLM server)
  static const String syncServerUrl = 'http://183.96.3.137:9999';

  
  // App Info
  static const String appName = 'Receipt Ledger';
  static const String appVersion = '1.0.0';
  
  // Default Categories
  static const List<String> defaultCategories = [
    '식비',
    '교통',
    '쇼핑',
    '의료',
    '여가',
    '공과금',
    '카페',
    '편의점',
    '마트',
    '기타',
  ];
  
  // Sync Settings
  static const int syncPort = 8080;
  static const Duration syncTimeout = Duration(seconds: 10);
}
