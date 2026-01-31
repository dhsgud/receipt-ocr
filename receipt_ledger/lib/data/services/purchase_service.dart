import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../core/entitlements.dart';

// ============================================================================
// Subscription State
// ============================================================================

/// 구독 상태를 나타내는 불변 클래스
@immutable
class SubscriptionState {
  final bool isLoading;
  final SubscriptionTier tier;
  final DateTime? expirationDate;
  final String? error;
  final CustomerInfo? customerInfo;
  final Offerings? offerings;
  final String? activeProductId;

  const SubscriptionState({
    this.isLoading = false,
    this.tier = SubscriptionTier.free,
    this.expirationDate,
    this.error,
    this.customerInfo,
    this.offerings,
    this.activeProductId,
  });

  /// 프리미엄 여부 (Basic 이상)
  bool get isPremium => tier != SubscriptionTier.free;
  
  /// 광고 제거 여부 (Basic 이상)
  bool get isAdFree => tier != SubscriptionTier.free;
  
  /// 평생 이용권 여부
  bool get isLifetime => activeProductId == lifetimeProductId;
  
  /// 클라우드 동기화 가능 여부 (Basic 이상)
  bool get canSync => tier != SubscriptionTier.free;
  
  /// 멀티 디바이스 지원 여부 (Pro만)
  bool get canUseMultiDevice => tier == SubscriptionTier.pro;

  SubscriptionState copyWith({
    bool? isLoading,
    SubscriptionTier? tier,
    DateTime? expirationDate,
    String? error,
    CustomerInfo? customerInfo,
    Offerings? offerings,
    String? activeProductId,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      tier: tier ?? this.tier,
      expirationDate: expirationDate ?? this.expirationDate,
      error: error,
      customerInfo: customerInfo ?? this.customerInfo,
      offerings: offerings ?? this.offerings,
      activeProductId: activeProductId ?? this.activeProductId,
    );
  }
}

// ============================================================================
// Subscription Notifier
// ============================================================================

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(const SubscriptionState());

  bool _isInitialized = false;

  /// RevenueCat 초기화
  Future<void> init() async {
    if (_isInitialized) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      // 웹에서는 RevenueCat 미지원
      if (kIsWeb) {
        state = state.copyWith(isLoading: false);
        return;
      }
      
      // RevenueCat 설정
      await Purchases.setLogLevel(LogLevel.debug);
      
      final config = PurchasesConfiguration(revenueCatApiKey);
      await Purchases.configure(config);
      
      // 구독 상태 확인
      await checkSubscriptionStatus();
      
      // Offerings 로드
      await loadOfferings();
      
      _isInitialized = true;
      debugPrint('[PurchaseService] RevenueCat initialized successfully');
    } catch (e) {
      debugPrint('[PurchaseService] Error initializing: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 구독 상태 확인
  Future<void> checkSubscriptionStatus() async {
    if (kIsWeb) return;
    
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updateStateFromCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('[PurchaseService] Error checking status: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// CustomerInfo로부터 상태 업데이트
  void _updateStateFromCustomerInfo(CustomerInfo info) {
    SubscriptionTier tier = SubscriptionTier.free;
    DateTime? expDate;
    String? productId;
    
    // Pro 등급 확인 (우선순위 높음)
    final proEntitlementInfo = info.entitlements.all[proEntitlement];
    if (proEntitlementInfo?.isActive ?? false) {
      tier = SubscriptionTier.pro;
      if (proEntitlementInfo!.expirationDate != null) {
        expDate = DateTime.tryParse(proEntitlementInfo.expirationDate!);
      }
      productId = proEntitlementInfo.productIdentifier;
    } else {
      // Basic 등급 확인
      final basicEntitlementInfo = info.entitlements.all[basicEntitlement];
      if (basicEntitlementInfo?.isActive ?? false) {
        tier = SubscriptionTier.basic;
        if (basicEntitlementInfo!.expirationDate != null) {
          expDate = DateTime.tryParse(basicEntitlementInfo.expirationDate!);
        }
        productId = basicEntitlementInfo.productIdentifier;
      } else {
        // 레거시 호환 (기존 receipt Pro → pro로 처리)
        final legacyEntitlement = info.entitlements.all[legacyPremiumEntitlement];
        if (legacyEntitlement?.isActive ?? false) {
          tier = SubscriptionTier.pro;
          if (legacyEntitlement!.expirationDate != null) {
            expDate = DateTime.tryParse(legacyEntitlement.expirationDate!);
          }
          productId = legacyEntitlement.productIdentifier;
        }
      }
    }
    
    state = state.copyWith(
      isLoading: false,
      tier: tier,
      expirationDate: expDate,
      customerInfo: info,
      activeProductId: productId,
    );
    
    debugPrint('[PurchaseService] Tier: $tier, Product: $productId');
  }

  /// Offerings 로드
  Future<void> loadOfferings() async {
    if (kIsWeb) return;
    
    try {
      final offerings = await Purchases.getOfferings();
      state = state.copyWith(offerings: offerings);
      debugPrint('[PurchaseService] Loaded ${offerings.all.length} offerings');
    } catch (e) {
      debugPrint('[PurchaseService] Error loading offerings: $e');
    }
  }

  /// RevenueCat Paywall 표시 (UI SDK 사용)
  Future<PaywallResult> presentPaywall() async {
    if (kIsWeb) {
      return PaywallResult.cancelled;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await RevenueCatUI.presentPaywall();
      
      // 결과에 따라 상태 업데이트
      if (result == PaywallResult.purchased || 
          result == PaywallResult.restored) {
        await checkSubscriptionStatus();
      }
      
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      debugPrint('[PurchaseService] Paywall error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return PaywallResult.error;
    }
  }

  /// 특정 Offering으로 Paywall 표시
  Future<PaywallResult> presentPaywallForOffering(Offering offering, {String? requiredEntitlement}) async {
    if (kIsWeb) {
      return PaywallResult.cancelled;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded(
        requiredEntitlement ?? proEntitlement,
        offering: offering,
      );
      
      if (result == PaywallResult.purchased || 
          result == PaywallResult.restored) {
        await checkSubscriptionStatus();
      }
      
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      debugPrint('[PurchaseService] Paywall error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return PaywallResult.error;
    }
  }

  /// 수동 패키지 구매 (Paywall 없이)
  Future<bool> purchasePackage(Package package) async {
    if (kIsWeb) return false;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      _updateStateFromCustomerInfo(customerInfo);
      return state.isPremium;
    } on PurchasesErrorCode catch (e) {
      String errorMessage;
      switch (e) {
        case PurchasesErrorCode.purchaseCancelledError:
          errorMessage = '구매가 취소되었습니다';
          break;
        case PurchasesErrorCode.productAlreadyPurchasedError:
          errorMessage = '이미 구매한 상품입니다';
          await checkSubscriptionStatus();
          break;
        default:
          errorMessage = '구매 중 오류가 발생했습니다: $e';
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '구매 중 오류: $e',
      );
      return false;
    }
  }

  /// 구매 복원
  Future<bool> restorePurchases() async {
    if (kIsWeb) return false;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updateStateFromCustomerInfo(customerInfo);
      return state.isPremium;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '복원 실패: $e',
      );
      return false;
    }
  }

  /// Customer Center 표시 (iOS/Android 네이티브)
  Future<void> presentCustomerCenter() async {
    if (kIsWeb) return;
    
    try {
      await RevenueCatUI.presentCustomerCenter();
      // Customer Center 닫힌 후 상태 새로고침
      await checkSubscriptionStatus();
    } catch (e) {
      debugPrint('[PurchaseService] Customer Center error: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// 사용자 로그인 (선택적)
  Future<void> login(String userId) async {
    if (kIsWeb) return;
    
    try {
      final result = await Purchases.logIn(userId);
      _updateStateFromCustomerInfo(result.customerInfo);
    } catch (e) {
      debugPrint('[PurchaseService] Login error: $e');
    }
  }

  /// 사용자 로그아웃
  Future<void> logout() async {
    if (kIsWeb) return;
    
    try {
      final customerInfo = await Purchases.logOut();
      _updateStateFromCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('[PurchaseService] Logout error: $e');
    }
  }
}

// ============================================================================
// Provider
// ============================================================================

final subscriptionProvider = 
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});
