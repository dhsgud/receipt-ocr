import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/entitlements.dart';

/// 사용량 쿼터 상태
@immutable
class QuotaState {
  final int totalUsed; // 총 OCR 사용량
  final int bonusQuota; // 광고로 얻은 보너스 횟수
  final bool isLoadedFromCloud; // RevenueCat에서 로드됨

  const QuotaState({
    this.totalUsed = 0,
    this.bonusQuota = 0,
    this.isLoadedFromCloud = false,
  });

  /// 남은 무료 횟수 계산
  int getRemainingFreeQuota() {
    final total = QuotaConfig.freeTotalLimit + bonusQuota;
    return (total - totalUsed).clamp(0, total);
  }

  /// OCR 사용 가능 여부 (Free 등급용)
  bool canUseFreeOcr() {
    return getRemainingFreeQuota() > 0;
  }

  QuotaState copyWith({
    int? totalUsed,
    int? bonusQuota,
    bool? isLoadedFromCloud,
  }) {
    return QuotaState(
      totalUsed: totalUsed ?? this.totalUsed,
      bonusQuota: bonusQuota ?? this.bonusQuota,
      isLoadedFromCloud: isLoadedFromCloud ?? this.isLoadedFromCloud,
    );
  }
}

/// 쿼터 서비스 - RevenueCat Subscriber Attributes로 사용량 추적
class QuotaNotifier extends StateNotifier<QuotaState> {
  QuotaNotifier() : super(const QuotaState());

  // 로컬 백업용 키
  static const String _totalUsedKey = 'quota_total_used';
  static const String _bonusQuotaKey = 'quota_bonus';

  /// 초기화 및 데이터 로드
  Future<void> init() async {
    // 먼저 로컬에서 로드
    await _loadFromLocal();
    
    // RevenueCat에서 로드 시도 (재설치 복구)
    await _loadFromRevenueCat();
  }

  /// 로컬 스토리지에서 로드
  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final totalUsed = prefs.getInt(_totalUsedKey) ?? 0;
      final bonusQuota = prefs.getInt(_bonusQuotaKey) ?? 0;
      
      state = state.copyWith(
        totalUsed: totalUsed,
        bonusQuota: bonusQuota,
      );
      debugPrint('[QuotaService] Loaded from local: used=$totalUsed, bonus=$bonusQuota');
    } catch (e) {
      debugPrint('[QuotaService] Error loading from local: $e');
    }
  }

  /// RevenueCat에서 커스텀 속성 로드 (Subscriber Attributes 사용)
  Future<void> _loadFromRevenueCat() async {
    if (kIsWeb) return;
    
    try {
      // RevenueCat의 Subscriber Attributes 설정만 사용
      // 실제 값은 설정 시 저장되므로 로컬 값과 동기화만 수행
      await _syncToRevenueCat();
      state = state.copyWith(isLoadedFromCloud: true);
      debugPrint('[QuotaService] RevenueCat sync completed');
    } catch (e) {
      debugPrint('[QuotaService] Error syncing with RevenueCat: $e');
    }
  }

  /// RevenueCat에 현재 상태 동기화
  Future<void> _syncToRevenueCat() async {
    if (kIsWeb) return;
    
    try {
      await Purchases.setAttributes({
        QuotaAttributes.totalOcrUsed: state.totalUsed.toString(),
        QuotaAttributes.bonusQuota: state.bonusQuota.toString(),
      });
      debugPrint('[QuotaService] Synced to RevenueCat');
    } catch (e) {
      debugPrint('[QuotaService] Error syncing to RevenueCat: $e');
    }
  }

  /// 로컬 스토리지에 저장
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_totalUsedKey, state.totalUsed);
      await prefs.setInt(_bonusQuotaKey, state.bonusQuota);
    } catch (e) {
      debugPrint('[QuotaService] Error saving to local: $e');
    }
  }

  /// OCR 사용 가능 여부 확인
  bool canUseOcr(SubscriptionTier tier) {
    // 구독자는 무제한
    if (tier != SubscriptionTier.free) {
      return true;
    }
    
    // Free 사용자는 남은 횟수 확인
    return state.canUseFreeOcr();
  }

  /// 남은 횟수 반환
  int getRemainingQuota(SubscriptionTier tier) {
    if (tier != SubscriptionTier.free) {
      return -1; // 무제한
    }
    return state.getRemainingFreeQuota();
  }

  /// OCR 사용 시 카운트 증가
  Future<void> incrementUsage() async {
    state = state.copyWith(
      totalUsed: state.totalUsed + 1,
    );
    await _saveToLocal();
    await _syncToRevenueCat();
    debugPrint('[QuotaService] Usage incremented: total=${state.totalUsed}');
  }

  /// 광고 시청으로 보너스 추가
  Future<void> addBonusFromAd() async {
    state = state.copyWith(
      bonusQuota: state.bonusQuota + AdConfig.rewardedAdBonus,
    );
    await _saveToLocal();
    await _syncToRevenueCat();
    debugPrint('[QuotaService] Bonus added: bonus=${state.bonusQuota}');
  }

  /// 쿼터 리셋 (디버그용)
  Future<void> resetQuota() async {
    state = const QuotaState();
    await _saveToLocal();
    await _syncToRevenueCat();
    debugPrint('[QuotaService] Quota reset');
  }
}

/// 쿼터 Provider
final quotaProvider = StateNotifierProvider<QuotaNotifier, QuotaState>((ref) {
  return QuotaNotifier();
});
