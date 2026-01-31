import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/entitlements.dart';

/// 광고 상태 (AdMob 비활성화 상태)
@immutable
class AdState {
  final bool isInitialized;
  final bool isBannerLoaded;

  const AdState({
    this.isInitialized = false,
    this.isBannerLoaded = false,
  });

  AdState copyWith({
    bool? isInitialized,
    bool? isBannerLoaded,
  }) {
    return AdState(
      isInitialized: isInitialized ?? this.isInitialized,
      isBannerLoaded: isBannerLoaded ?? this.isBannerLoaded,
    );
  }
}

/// 광고 서비스 - Google AdMob 관리 (Stub)
/// 
/// 실제 AdMob을 활성화하려면:
/// 1. pubspec.yaml에서 google_mobile_ads 주석 해제
/// 2. iOS Info.plist에 GADApplicationIdentifier 추가
/// 3. Android AndroidManifest.xml에 AdMob App ID 추가
/// 4. 이 파일을 원래 버전으로 복원
class AdNotifier extends StateNotifier<AdState> {
  AdNotifier() : super(const AdState());

  /// AdMob 초기화 (비활성화됨)
  Future<void> init() async {
    debugPrint('[AdService] AdMob disabled - configure iOS/Android first');
    state = state.copyWith(isInitialized: false);
  }

  /// 배너 광고 로드 (비활성화됨)
  Future<void> loadBannerAd() async {
    // AdMob 비활성화 상태
  }

  /// 광고 정리 (비활성화됨)
  void disposeBannerAd() {
    state = state.copyWith(isBannerLoaded: false);
  }
}

/// 광고 Provider
final adProvider = StateNotifierProvider<AdNotifier, AdState>((ref) {
  return AdNotifier();
});

/// 광고 표시 여부 Provider
/// AdMob 비활성화 상태이므로 항상 false 반환
final shouldShowAdsProvider = Provider<bool>((ref) {
  return false;
});
