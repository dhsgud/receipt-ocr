import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/entitlements.dart';

/// 사용량 쿼터 상태
@immutable
class QuotaState {
  final int totalUsed; // 총 OCR 사용량
  final int bonusQuota; // 광고로 얻은 보너스 횟수

  const QuotaState({
    this.totalUsed = 0,
    this.bonusQuota = 0,
  });

  /// 남은 무료 횟수 계산
  int getRemainingFreeQuota() {
    final total = QuotaConfig.freeTotalLimit + bonusQuota;
    return (total - totalUsed).clamp(0, total);
  }

  /// OCR 사용 가능 여부
  bool canUseFreeOcr() {
    return getRemainingFreeQuota() > 0;
  }

  QuotaState copyWith({
    int? totalUsed,
    int? bonusQuota,
  }) {
    return QuotaState(
      totalUsed: totalUsed ?? this.totalUsed,
      bonusQuota: bonusQuota ?? this.bonusQuota,
    );
  }
}

/// 쿼터 서비스 - 로컬 SharedPreferences로 사용량 추적
class QuotaNotifier extends StateNotifier<QuotaState> {
  QuotaNotifier() : super(const QuotaState());

  // 로컬 저장 키
  static const String _totalUsedKey = 'quota_total_used';
  static const String _bonusQuotaKey = 'quota_bonus';

  /// 초기화 및 데이터 로드
  Future<void> init() async {
    await _loadFromLocal();
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
    } catch (e) {
    }
  }

  /// 로컬 스토리지에 저장
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_totalUsedKey, state.totalUsed);
      await prefs.setInt(_bonusQuotaKey, state.bonusQuota);
    } catch (e) {
    }
  }

  /// OCR 사용 가능 여부 확인
  bool canUseOcr() {
    return state.canUseFreeOcr();
  }

  /// 남은 횟수 반환
  int getRemainingQuota() {
    return state.getRemainingFreeQuota();
  }

  /// OCR 사용 시 카운트 증가
  Future<void> incrementUsage() async {
    state = state.copyWith(
      totalUsed: state.totalUsed + 1,
    );
    await _saveToLocal();
  }

  /// 광고 시청으로 보너스 추가
  Future<void> addBonusFromAd() async {
    state = state.copyWith(
      bonusQuota: state.bonusQuota + AdConfig.rewardedAdBonus,
    );
    await _saveToLocal();
  }

  /// 쿼터 리셋 (디버그용)
  Future<void> resetQuota() async {
    state = const QuotaState();
    await _saveToLocal();
  }
}

/// 쿼터 Provider
final quotaProvider = StateNotifierProvider<QuotaNotifier, QuotaState>((ref) {
  return QuotaNotifier();
});
