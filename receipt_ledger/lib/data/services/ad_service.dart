import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 광고 ID 상수
class AdIds {
  // Android 배너 광고 ID
  static const String androidBanner = 'ca-app-pub-1570373945115921/9288437588';
  
  // Android 리워드 광고 ID
  static const String androidRewarded = 'ca-app-pub-1570373945115921/5269593106';
  
  // iOS 배너 광고 ID (실제 프로덕션)
  static const String iosBanner = 'ca-app-pub-1570373945115921/1911635707';
  
  // iOS 리워드 광고 ID (실제 프로덕션)
  static const String iosRewarded = 'ca-app-pub-1570373945115921/5572154476';
  
  /// 플랫폼에 맞는 배너 광고 ID 반환
  static String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidBanner;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosBanner;
    }
    return androidBanner;
  }
  
  /// 플랫폼에 맞는 리워드 광고 ID 반환
  static String get rewardedAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidRewarded;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosRewarded;
    }
    return androidRewarded;
  }
}

/// 광고 상태
@immutable
class AdState {
  final bool isInitialized;
  final bool isBannerLoaded;
  final bool isRewardedLoaded;
  final bool isRewardedLoading;
  final BannerAd? bannerAd;
  final RewardedAd? rewardedAd;

  const AdState({
    this.isInitialized = false,
    this.isBannerLoaded = false,
    this.isRewardedLoaded = false,
    this.isRewardedLoading = false,
    this.bannerAd,
    this.rewardedAd,
  });

  AdState copyWith({
    bool? isInitialized,
    bool? isBannerLoaded,
    bool? isRewardedLoaded,
    bool? isRewardedLoading,
    BannerAd? bannerAd,
    RewardedAd? rewardedAd,
    bool clearRewarded = false,
  }) {
    return AdState(
      isInitialized: isInitialized ?? this.isInitialized,
      isBannerLoaded: isBannerLoaded ?? this.isBannerLoaded,
      isRewardedLoaded: isRewardedLoaded ?? this.isRewardedLoaded,
      isRewardedLoading: isRewardedLoading ?? this.isRewardedLoading,
      bannerAd: bannerAd ?? this.bannerAd,
      rewardedAd: clearRewarded ? null : (rewardedAd ?? this.rewardedAd),
    );
  }
}

/// 광고 서비스 - Google AdMob 관리
class AdNotifier extends StateNotifier<AdState> {
  AdNotifier() : super(const AdState());

  int _rewardedLoadRetryCount = 0;
  static const int _maxRetries = 3;

  /// AdMob 초기화
  Future<void> init() async {
    if (kIsWeb) return;
    
    try {
      await MobileAds.instance.initialize();
      
      state = state.copyWith(isInitialized: true);
      
      // 배너 광고 로드
      await loadBannerAd();
      // 리워드 광고 미리 로드
      await loadRewardedAd();
    } catch (e) {
      debugPrint('[AdService] init failed: $e');
      state = state.copyWith(isInitialized: false);
    }
  }

  /// 배너 광고 로드
  Future<void> loadBannerAd() async {
    if (!state.isInitialized || kIsWeb) return;

    final bannerAd = BannerAd(
      adUnitId: AdIds.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          state = state.copyWith(isBannerLoaded: true, bannerAd: ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdService] Banner failed: ${error.message}');
          ad.dispose();
          state = state.copyWith(isBannerLoaded: false);
        },
      ),
    );

    await bannerAd.load();
  }

  /// 리워드 광고 로드
  Future<void> loadRewardedAd() async {
    if (!state.isInitialized || kIsWeb) return;
    if (state.isRewardedLoading) return; // 중복 로드 방지
    
    state = state.copyWith(isRewardedLoading: true);
    
    await RewardedAd.load(
      adUnitId: AdIds.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Rewarded ad loaded successfully');
          _rewardedLoadRetryCount = 0;
          state = state.copyWith(
            isRewardedLoaded: true, 
            isRewardedLoading: false,
            rewardedAd: ad,
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Rewarded ad failed to load: ${error.message} (code: ${error.code})');
          state = state.copyWith(
            isRewardedLoaded: false, 
            isRewardedLoading: false,
          );
          
          // 자동 재시도 (최대 3회, 지수 백오프)
          if (_rewardedLoadRetryCount < _maxRetries) {
            _rewardedLoadRetryCount++;
            final delay = Duration(seconds: _rewardedLoadRetryCount * 2);
            debugPrint('[AdService] Retrying rewarded ad load in ${delay.inSeconds}s (attempt $_rewardedLoadRetryCount)');
            Future.delayed(delay, () {
              if (!state.isRewardedLoaded) {
                loadRewardedAd();
              }
            });
          }
        },
      ),
    );
  }

  /// 리워드 광고가 준비될 때까지 대기 (최대 10초)
  Future<bool> waitForRewardedAd() async {
    if (isRewardedAdReady) return true;
    
    // 아직 로드 안 됐으면 시도
    if (!state.isRewardedLoading) {
      _rewardedLoadRetryCount = 0;
      await loadRewardedAd();
    }
    
    // 최대 10초 대기
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (isRewardedAdReady) return true;
    }
    
    return isRewardedAdReady;
  }

  /// 리워드 광고 표시 및 보상 콜백
  Future<bool> showRewardedAd({
    required Function() onRewarded,
  }) async {
    if (!state.isRewardedLoaded || state.rewardedAd == null) {
      debugPrint('[AdService] Rewarded ad not ready');
      return false;
    }
    
    bool wasRewarded = false;
    final completer = Completer<void>();
    
    state.rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdService] Rewarded ad dismissed');
        ad.dispose();
        state = state.copyWith(isRewardedLoaded: false, isRewardedLoading: false, clearRewarded: true);
        // 다음 광고 미리 로드
        _rewardedLoadRetryCount = 0;
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Rewarded ad failed to show: ${error.message}');
        ad.dispose();
        state = state.copyWith(isRewardedLoaded: false, isRewardedLoading: false, clearRewarded: true);
        _rewardedLoadRetryCount = 0;
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete();
      },
    );
    
    await state.rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
        wasRewarded = true;
        onRewarded();
      },
    );
    
    // 광고가 완전히 닫힐 때까지 대기 (최대 30초 타임아웃)
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('[AdService] Rewarded ad timeout');
      },
    );
    
    return wasRewarded;
  }

  /// 리워드 광고 준비 여부
  bool get isRewardedAdReady => state.isRewardedLoaded && state.rewardedAd != null;

  /// 광고 정리
  void disposeBannerAd() {
    state.bannerAd?.dispose();
    state = state.copyWith(isBannerLoaded: false, bannerAd: null);
  }

  @override
  void dispose() {
    state.bannerAd?.dispose();
    state.rewardedAd?.dispose();
    super.dispose();
  }
}

/// 광고 Provider
final adProvider = StateNotifierProvider<AdNotifier, AdState>((ref) {
  return AdNotifier();
});

/// 광고 표시 여부 Provider
/// 항상 광고 표시 (구독 제거됨)
final shouldShowAdsProvider = Provider<bool>((ref) {
  final adState = ref.watch(adProvider);
  return adState.isInitialized;
});
