/// RevenueCat 상수 정의
/// 
/// 이 파일은 RevenueCat 인앱 결제를 위한 모든 상수를 정의합니다.
library;

// ============================================================================
// RevenueCat API Keys
// ============================================================================

/// RevenueCat API Key (모든 플랫폼에서 동일한 키 사용)
const String revenueCatApiKey = 'test_XrYkyXGIFqIDKMEuoLJElJcLUPb';

// ============================================================================
// Entitlement Identifiers
// ============================================================================

/// Basic 등급 Entitlement ID
const String basicEntitlement = 'basic';

/// Pro 등급 Entitlement ID
const String proEntitlement = 'Pro';

/// 레거시 호환용 (기존 receipt Pro → pro로 매핑)
const String legacyPremiumEntitlement = 'receipt Pro';

// ============================================================================
// Product Identifiers
// ============================================================================

/// Basic 월간 구독 상품 ID
const String basicMonthlyProductId = 'basic_monthly';

/// Basic 연간 구독 상품 ID
const String basicYearlyProductId = 'basic_yearly';

/// Pro 월간 구독 상품 ID
const String proMonthlyProductId = 'premium_monthly';

/// Pro 연간 구독 상품 ID
const String proYearlyProductId = 'premium_yearly';

/// 평생 이용권 상품 ID (Pro 등급)
const String lifetimeProductId = 'lifetime';

/// 모든 상품 ID 목록
const List<String> allProductIds = [
  basicMonthlyProductId,
  basicYearlyProductId,
  proMonthlyProductId,
  proYearlyProductId,
  lifetimeProductId,
];

// ============================================================================
// Subscription Tiers
// ============================================================================

/// 구독 등급 enum
enum SubscriptionTier {
  free,
  basic,
  pro,
}

// ============================================================================
// Quota Configuration (사용량 제한)
// ============================================================================

class QuotaConfig {
  // Free 등급
  static const int freeDailyLimit = 3;
  static const int freeTotalLimit = 10; // 평생 총 횟수
  static const int freeBatchLimit = 3;
  
  // Basic 등급
  static const int basicDailyLimit = 20;
  static const int basicMonthlyLimit = 300;
  static const int basicBatchLimit = 10;
  
  // Pro 등급
  static const int proDailyLimit = 100;
  static const int proMonthlyLimit = -1; // -1 = 무제한
  static const int proBatchLimit = 30;
  
  /// 등급별 일일 제한 반환
  static int getDailyLimit(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return freeDailyLimit;
      case SubscriptionTier.basic:
        return basicDailyLimit;
      case SubscriptionTier.pro:
        return proDailyLimit;
    }
  }
  
  /// 등급별 월간 제한 반환 (-1 = 무제한)
  static int getMonthlyLimit(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return freeTotalLimit; // Free는 월간이 아닌 총 횟수
      case SubscriptionTier.basic:
        return basicMonthlyLimit;
      case SubscriptionTier.pro:
        return proMonthlyLimit;
    }
  }
  
  /// 등급별 일괄 업로드 제한 반환
  static int getBatchLimit(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return freeBatchLimit;
      case SubscriptionTier.basic:
        return basicBatchLimit;
      case SubscriptionTier.pro:
        return proBatchLimit;
    }
  }
}

// ============================================================================
// Pricing Information (Display Only - 실제 가격은 스토어에서 가져옴)
// ============================================================================

class PricingInfo {
  // Basic 등급
  static const String basicMonthlyPrice = '₩1,900';
  static const String basicYearlyPrice = '₩19,000';
  
  // Pro 등급
  static const String proMonthlyPrice = '₩4,900';
  static const String proYearlyPrice = '₩49,000';
  
  // 평생 이용권
  static const String lifetimePrice = '₩59,000';
  
  /// 레거시 호환용
  static const int freeTrialCount = QuotaConfig.freeTotalLimit;
}

// ============================================================================
// Ad Configuration
// ============================================================================

class AdConfig {
  /// 테스트 배너 광고 ID (개발용)
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  
  /// 실제 배너 광고 ID (프로덕션) - 추후 교체 필요
  static const String bannerAdUnitIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String bannerAdUnitIdIos = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  
  /// 광고 표시 여부 (Free 등급만 true)
  static bool shouldShowAds(SubscriptionTier tier) {
    return tier == SubscriptionTier.free;
  }
}

// ============================================================================
// Feature Flags
// ============================================================================

class SubscriptionFeatures {
  /// Free 등급 기능
  static const List<String> freeFeatures = [
    '기본 영수증 OCR 스캔',
    '일일 3회 제한',
    '로컬 데이터 저장',
  ];
  
  /// Basic 등급 기능
  static const List<String> basicFeatures = [
    '일일 20회 OCR 스캔',
    '월 300회 OCR 제한',
    '광고 제거',
    '클라우드 동기화',
    '상세 지출 리포트',
  ];
  
  /// Pro 등급 기능
  static const List<String> proFeatures = [
    '일일 100회 OCR 스캔',
    '무제한 월간 OCR',
    '광고 제거',
    '클라우드 동기화',
    '상세 지출 리포트',
    '멀티 디바이스 지원',
    '우선 고객 지원',
  ];
}
