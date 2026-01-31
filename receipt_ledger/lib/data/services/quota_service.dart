import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/entitlements.dart';

/// 사용량 쿼터 상태
@immutable
class QuotaState {
  final int dailyUsed;
  final int monthlyUsed;
  final int totalUsed; // Free 등급용 총 사용량
  final DateTime lastResetDate;
  final int lastResetMonth;

  const QuotaState({
    this.dailyUsed = 0,
    this.monthlyUsed = 0,
    this.totalUsed = 0,
    required this.lastResetDate,
    required this.lastResetMonth,
  });

  QuotaState copyWith({
    int? dailyUsed,
    int? monthlyUsed,
    int? totalUsed,
    DateTime? lastResetDate,
    int? lastResetMonth,
  }) {
    return QuotaState(
      dailyUsed: dailyUsed ?? this.dailyUsed,
      monthlyUsed: monthlyUsed ?? this.monthlyUsed,
      totalUsed: totalUsed ?? this.totalUsed,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      lastResetMonth: lastResetMonth ?? this.lastResetMonth,
    );
  }
}

/// 쿼터 서비스 - 사용량 추적 및 제한 관리
class QuotaNotifier extends StateNotifier<QuotaState> {
  QuotaNotifier() : super(QuotaState(
    lastResetDate: DateTime.now(),
    lastResetMonth: DateTime.now().month,
  ));

  static const String _dailyUsedKey = 'quota_daily_used';
  static const String _monthlyUsedKey = 'quota_monthly_used';
  static const String _totalUsedKey = 'quota_total_used';
  static const String _lastResetDateKey = 'quota_last_reset_date';
  static const String _lastResetMonthKey = 'quota_last_reset_month';

  /// 초기화 및 데이터 로드
  Future<void> init() async {
    await _loadQuota();
    await _checkAndResetIfNeeded();
  }

  /// 저장된 쿼터 데이터 로드
  Future<void> _loadQuota() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final dailyUsed = prefs.getInt(_dailyUsedKey) ?? 0;
      final monthlyUsed = prefs.getInt(_monthlyUsedKey) ?? 0;
      final totalUsed = prefs.getInt(_totalUsedKey) ?? 0;
      final lastResetDateStr = prefs.getString(_lastResetDateKey);
      final lastResetMonth = prefs.getInt(_lastResetMonthKey) ?? DateTime.now().month;
      
      DateTime lastResetDate = DateTime.now();
      if (lastResetDateStr != null) {
        lastResetDate = DateTime.tryParse(lastResetDateStr) ?? DateTime.now();
      }
      
      state = QuotaState(
        dailyUsed: dailyUsed,
        monthlyUsed: monthlyUsed,
        totalUsed: totalUsed,
        lastResetDate: lastResetDate,
        lastResetMonth: lastResetMonth,
      );
    } catch (e) {
      debugPrint('[QuotaService] Error loading quota: $e');
    }
  }

  /// 날짜/월 변경 시 리셋 확인
  Future<void> _checkAndResetIfNeeded() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastReset = DateTime(
      state.lastResetDate.year,
      state.lastResetDate.month,
      state.lastResetDate.day,
    );
    
    bool needsSave = false;
    int newDailyUsed = state.dailyUsed;
    int newMonthlyUsed = state.monthlyUsed;
    DateTime newLastResetDate = state.lastResetDate;
    int newLastResetMonth = state.lastResetMonth;
    
    // 날짜가 바뀌면 일일 사용량 리셋
    if (today.isAfter(lastReset)) {
      newDailyUsed = 0;
      newLastResetDate = today;
      needsSave = true;
      debugPrint('[QuotaService] Daily quota reset');
    }
    
    // 월이 바뀌면 월간 사용량 리셋
    if (now.month != state.lastResetMonth) {
      newMonthlyUsed = 0;
      newLastResetMonth = now.month;
      needsSave = true;
      debugPrint('[QuotaService] Monthly quota reset');
    }
    
    if (needsSave) {
      state = state.copyWith(
        dailyUsed: newDailyUsed,
        monthlyUsed: newMonthlyUsed,
        lastResetDate: newLastResetDate,
        lastResetMonth: newLastResetMonth,
      );
      await _saveQuota();
    }
  }

  /// 쿼터 데이터 저장
  Future<void> _saveQuota() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_dailyUsedKey, state.dailyUsed);
      await prefs.setInt(_monthlyUsedKey, state.monthlyUsed);
      await prefs.setInt(_totalUsedKey, state.totalUsed);
      await prefs.setString(_lastResetDateKey, state.lastResetDate.toIso8601String());
      await prefs.setInt(_lastResetMonthKey, state.lastResetMonth);
    } catch (e) {
      debugPrint('[QuotaService] Error saving quota: $e');
    }
  }

  /// OCR 사용 가능 여부 확인
  bool canUseOcr(SubscriptionTier tier) {
    _checkAndResetIfNeeded();
    
    final dailyLimit = QuotaConfig.getDailyLimit(tier);
    final monthlyLimit = QuotaConfig.getMonthlyLimit(tier);
    
    // 일일 제한 확인
    if (state.dailyUsed >= dailyLimit) {
      return false;
    }
    
    // Free 등급은 총 사용량 확인
    if (tier == SubscriptionTier.free) {
      if (state.totalUsed >= QuotaConfig.freeTotalLimit) {
        return false;
      }
    }
    
    // 월간 제한 확인 (-1은 무제한)
    if (monthlyLimit > 0 && state.monthlyUsed >= monthlyLimit) {
      return false;
    }
    
    return true;
  }

  /// 남은 일일 횟수
  int getRemainingDaily(SubscriptionTier tier) {
    final limit = QuotaConfig.getDailyLimit(tier);
    return (limit - state.dailyUsed).clamp(0, limit);
  }

  /// 남은 월간 횟수 (-1 = 무제한)
  int getRemainingMonthly(SubscriptionTier tier) {
    final limit = QuotaConfig.getMonthlyLimit(tier);
    if (limit < 0) return -1; // 무제한
    
    if (tier == SubscriptionTier.free) {
      // Free는 총 남은 횟수 반환
      return (QuotaConfig.freeTotalLimit - state.totalUsed).clamp(0, QuotaConfig.freeTotalLimit);
    }
    
    return (limit - state.monthlyUsed).clamp(0, limit);
  }

  /// OCR 사용 시 카운트 증가
  Future<void> incrementUsage() async {
    state = state.copyWith(
      dailyUsed: state.dailyUsed + 1,
      monthlyUsed: state.monthlyUsed + 1,
      totalUsed: state.totalUsed + 1,
    );
    await _saveQuota();
    debugPrint('[QuotaService] Usage incremented: daily=${state.dailyUsed}, monthly=${state.monthlyUsed}, total=${state.totalUsed}');
  }

  /// 쿼터 리셋 (디버그용)
  Future<void> resetQuota() async {
    state = QuotaState(
      lastResetDate: DateTime.now(),
      lastResetMonth: DateTime.now().month,
    );
    await _saveQuota();
    debugPrint('[QuotaService] Quota reset');
  }
}

/// 쿼터 Provider
final quotaProvider = StateNotifierProvider<QuotaNotifier, QuotaState>((ref) {
  return QuotaNotifier();
});
