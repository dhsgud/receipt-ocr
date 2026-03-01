import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/entitlements.dart';

/// 사용량 쿼터 상태
@immutable
class QuotaState {
  final int totalUsed; // 총 OCR 사용량
  final int bonusQuota; // 광고로 얻은 보너스 횟수
  final bool isSynced; // 서버 동기화 여부

  const QuotaState({
    this.totalUsed = 0,
    this.bonusQuota = 0,
    this.isSynced = false,
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
    bool? isSynced,
  }) {
    return QuotaState(
      totalUsed: totalUsed ?? this.totalUsed,
      bonusQuota: bonusQuota ?? this.bonusQuota,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

/// 쿼터 서비스 - 서버 + 로컬 하이브리드 관리
class QuotaNotifier extends StateNotifier<QuotaState> {
  QuotaNotifier() : super(const QuotaState());

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

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
      // Silently fail — use defaults
    }
  }

  /// 로컬 스토리지에 저장
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_totalUsedKey, state.totalUsed);
      await prefs.setInt(_bonusQuotaKey, state.bonusQuota);
    } catch (e) {
      // Silently fail
    }
  }

  /// 서버에서 쿼터 동기화
  Future<void> syncFromServer(String serverUrl, String userEmail) async {
    try {
      final response = await _dio.get(
        '$serverUrl/api/quota',
        options: Options(headers: {'X-User-Email': userEmail}),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        state = QuotaState(
          totalUsed: data['total_used'] as int,
          bonusQuota: data['bonus_quota'] as int,
          isSynced: true,
        );
        await _saveToLocal();
      }
    } catch (e) {
      // 서버 연결 실패 시 로컬 데이터 유지
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

  /// OCR 사용 시 카운트 증가 (서버가 이미 증가시킴 → 로컬만 동기화)
  Future<void> incrementUsage() async {
    state = state.copyWith(
      totalUsed: state.totalUsed + 1,
    );
    await _saveToLocal();
  }

  /// 서버 동기화 후 로컬 상태 갱신 (OCR 성공 후 호출)
  Future<void> syncAfterOcr(String serverUrl, String userEmail) async {
    // 로컬을 먼저 즉시 증가 (UX 반응성)
    await incrementUsage();
    // 서버에서 실제 값 동기화
    await syncFromServer(serverUrl, userEmail);
  }

  /// 광고 시청으로 보너스 추가 (서버에 요청)
  Future<bool> addBonusFromAdOnServer(String serverUrl, String userEmail) async {
    try {
      final response = await _dio.post(
        '$serverUrl/api/quota/bonus',
        options: Options(headers: {'X-User-Email': userEmail}),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        state = QuotaState(
          totalUsed: data['total_used'] as int,
          bonusQuota: data['bonus_quota'] as int,
          isSynced: true,
        );
        await _saveToLocal();
        return true;
      }
    } catch (e) {
      // 서버 실패 시 로컬에만 추가 (fallback)
      await addBonusFromAd();
    }
    return false;
  }

  /// 광고 시청으로 보너스 추가 (로컬 fallback)
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
