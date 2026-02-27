/// App Constants
class AppConstants {
  // OCR Server (Gemini Vision API)
  static const String ocrEndpoint = '/api/ocr';
  
  // Sync Server
  /// 기본 서버 URL (설정에서 변경 가능)
  static const String syncServerUrl = 'http://183.96.3.137:9999';

  
  // App Info
  static const String appName = 'Receipt Ledger';
  static const String appVersion = '0.1.0';
  
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
