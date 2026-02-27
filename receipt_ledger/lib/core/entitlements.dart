/// 앱 설정 상수 정의
/// 
/// 광고 기반 수익화 모델
library;

// ============================================================================
// Quota Configuration (사용량 제한)
// ============================================================================

class QuotaConfig {
  /// 무료 OCR 총 제한 횟수 (첫 1회만 무료)
  static const int freeTotalLimit = 1;
  
  /// 일괄 업로드 제한
  static const int batchLimit = 30;
}

// ============================================================================
// Ad Configuration
// ============================================================================

class AdConfig {
  /// 테스트 배너 광고 ID (개발용)
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  
  /// 테스트 리워드 광고 ID (개발용)
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  
  /// 실제 배너 광고 ID
  static const String bannerAdUnitIdAndroid = 'ca-app-pub-1570373945115921/9288437588';
  
  /// 실제 리워드 광고 ID
  static const String rewardedAdUnitIdAndroid = 'ca-app-pub-1570373945115921/5269593106';
  
  /// 광고 시청 당 보너스 횟수
  static const int rewardedAdBonus = 1;
}
