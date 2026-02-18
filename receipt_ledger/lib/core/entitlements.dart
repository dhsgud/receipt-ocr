/// RevenueCat 상수 정의
/// 
/// 이 파일은 RevenueCat 인앱 결제를 위한 모든 상수를 정의합니다.
library;

// ============================================================================
// RevenueCat API Keys
// ============================================================================

/// RevenueCat API Key (모든 플랫폼에서 동일한 키 사용)
const String revenueCatApiKey = bool.fromEnvironment('dart.vm.product')
    ? 'goog_cmNZaYwgXEHhVCWWixvBbyGNIVI' // Production (Google Play)
    : 'test_XrYkyXGIFqIDKMEuoLJElJcLUPb'; // Test Store (Debug)

// ============================================================================
// Entitlement Identifiers
// ============================================================================

/// Basic 등급 Entitlement ID (유일한 유료 등급)
const String basicEntitlement = 'basic';

/// 레거시 호환용
const String legacyPremiumEntitlement = 'receipt Pro';
const String proEntitlement = 'Pro'; // 레거시 호환

// ============================================================================
// Product Identifiers
// ============================================================================

/// Basic 월간 구독 상품 ID
const String basicMonthlyProductId = 'basic_monthly';

/// Basic 연간 구독 상품 ID
const String basicYearlyProductId = 'basic_yearly';

/// 평생 이용권 상품 ID
const String lifetimeProductId = 'lifetime';

/// 모든 상품 ID 목록
const List<String> allProductIds = [
  basicMonthlyProductId,
  basicYearlyProductId,
  lifetimeProductId,
];

// ============================================================================
// Subscription Tiers (단순화: Free / Basic)
// ============================================================================

/// 구독 등급 enum
enum SubscriptionTier {
  free,
  basic,
  pro, // 레거시 호환용, basic과 동일 취급
}

// ============================================================================
// Quota Configuration (사용량 제한)
// ============================================================================

class QuotaConfig {
  // Free 등급
  static const int freeTotalLimit = 999999; // 테스트용 무제한 (원래 5)
  static const int freeBatchLimit = 3;
  
  // Basic/Pro 등급 (무제한)
  static const int basicDailyLimit = -1; // -1 = 무제한
  static const int basicMonthlyLimit = -1;
  static const int basicBatchLimit = 30;
  
  /// 등급별 일일 제한 반환 (-1 = 무제한)
  static int getDailyLimit(SubscriptionTier tier) {
    if (tier == SubscriptionTier.free) {
      return freeTotalLimit; // Free는 총 횟수만 적용
    }
    return basicDailyLimit;
  }
  
  /// 등급별 월간 제한 반환 (-1 = 무제한)
  static int getMonthlyLimit(SubscriptionTier tier) {
    if (tier == SubscriptionTier.free) {
      return freeTotalLimit; // Free는 총 횟수
    }
    return basicMonthlyLimit;
  }
  
  /// 등급별 일괄 업로드 제한 반환
  static int getBatchLimit(SubscriptionTier tier) {
    if (tier == SubscriptionTier.free) {
      return freeBatchLimit;
    }
    return basicBatchLimit;
  }
}

// ============================================================================
// RevenueCat Subscriber Attributes (쿼터 추적용)
// ============================================================================

class QuotaAttributes {
  /// 총 OCR 사용 횟수
  static const String totalOcrUsed = 'total_ocr_used';
  
  /// 광고 시청으로 얻은 보너스 횟수
  static const String bonusQuota = 'bonus_quota';
}

// ============================================================================
// Pricing Information (Display Only - 실제 가격은 스토어에서 가져옴)
// ============================================================================

class PricingInfo {
  // Basic 등급
  static const String basicMonthlyPrice = '₩1,900';
  static const String basicYearlyPrice = '₩19,000';
  
  // 평생 이용권
  static const String lifetimePrice = '₩39,000';
  
  /// 무료 체험 횟수
  static const int freeTrialCount = QuotaConfig.freeTotalLimit;
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
  
  /// 실제 리워드 광고 ID (AdMob에서 생성 필요)
  static const String rewardedAdUnitIdAndroid = 'ca-app-pub-1570373945115921/5269593106';
  
  /// 광고 표시 여부 (Free 등급만 true)
  static bool shouldShowAds(SubscriptionTier tier) {
    return tier == SubscriptionTier.free;
  }
  
  /// 광고 시청 당 보너스 횟수
  static const int rewardedAdBonus = 1;
}

// ============================================================================
// Feature Flags
// ============================================================================

class SubscriptionFeatures {
  /// Free 등급 기능
  static const List<String> freeFeatures = [
    '영수증 업로드 5회 무료',
    '광고 시청으로 추가 기회 획득',
    '로컬 데이터 저장',
  ];
  
  /// Basic 등급 기능
  static const List<String> basicFeatures = [
    '무제한 영수증 업로드',
    '광고 제거',
    '클라우드 동기화',
    '멀티 디바이스 지원',
    '상세 지출 리포트',
  ];
}
