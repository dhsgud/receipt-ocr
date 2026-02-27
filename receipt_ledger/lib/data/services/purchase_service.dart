import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Subscription State (simplified - always free, ad-supported)
// ============================================================================

/// 구독 상태 — 이제 항상 무료 (광고 기반)
class SubscriptionState {
  const SubscriptionState();

  /// 프리미엄 여부 — 항상 false (구독 제거됨)
  bool get isPremium => false;
  
  /// 광고 제거 여부 — 항상 false (항상 광고 표시)
  bool get isAdFree => false;
}

// ============================================================================
// Provider (호환성 유지)
// ============================================================================

final subscriptionProvider = Provider<SubscriptionState>((ref) {
  return const SubscriptionState();
});
