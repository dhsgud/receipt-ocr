import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/entitlements.dart';

/// 광고 ID 상수
class AdIds {
  // Android 배너 광고 ID
  static const String androidBanner = 'ca-app-pub-1570373945115921/9288437588';
  
  // Android 리워드 광고 ID
  static const String androidRewarded = 'ca-app-pub-1570373945115921/5269593106';
  
  // iOS 배너 광고 ID (테스트)
  static const String iosBanner = 'ca-app-pub-3940256099942544/2934735716';
  
  // iOS 리워드 광고 ID (테스트)
  static const String iosRewarded = 'ca-app-pub-3940256099942544/1712485313';
  
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
  final BannerAd? bannerAd;
  final RewardedAd? rewardedAd;

  const AdState({
    this.isInitialized = false,
    this.isBannerLoaded = false,
    this.isRewardedLoaded = false,
    this.bannerAd,
    this.rewardedAd,
  });

  AdState copyWith({
    bool? isInitialized,
    bool? isBannerLoaded,
    bool? isRewardedLoaded,
    BannerAd? bannerAd,
    RewardedAd? rewardedAd,
    bool clearRewarded = false,
  }) {
    return AdState(
      isInitialized: isInitialized ?? this.isInitialized,
      isBannerLoaded: isBannerLoaded ?? this.isBannerLoaded,
      isRewardedLoaded: isRewardedLoaded ?? this.isRewardedLoaded,
      bannerAd: bannerAd ?? this.bannerAd,
      rewardedAd: clearRewarded ? null : (rewardedAd ?? this.rewardedAd),
    );
  }
}

/// 광고 서비스 - Google AdMob 관리
class AdNotifier extends StateNotifier<AdState> {
  AdNotifier() : super(const AdState());

  /// AdMob 초기화
  Future<void> init() async {
    if (kIsWeb) return;
    
    try {
      await MobileAds.instance.initialize();
      
      // 테스트 기기 설정 - 실제 광고 ID를 사용하면서도 테스트 광고를 표시
      // 로그에서 "Use RequestConfiguration.Builder.setTestDeviceIds(Arrays.asList("XXXXX"))"
      // 메시지를 확인하여 실제 디바이스 해시 ID를 아래에 추가하세요.
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: const bool.fromEnvironment('dart.vm.product')
              ? []
              : ['F84A7F5F2A7EBC7EDD9709EA35F339F2'],
        ),
      );
      debugPrint('[AdService] ✅ Test device configuration set');
      
      state = state.copyWith(isInitialized: true);
      debugPrint('[AdService] AdMob initialized successfully');
      
      // 배너 광고 로드
      await loadBannerAd();
      // 리워드 광고 미리 로드
      await loadRewardedAd();
    } catch (e) {
      debugPrint('[AdService] AdMob initialization failed: $e');
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
          debugPrint('[AdService] Banner ad loaded');
          state = state.copyWith(isBannerLoaded: true, bannerAd: ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdService] Banner ad failed to load: $error');
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
    
    await RewardedAd.load(
      adUnitId: AdIds.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Rewarded ad loaded');
          state = state.copyWith(isRewardedLoaded: true, rewardedAd: ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Rewarded ad failed to load: $error');
          state = state.copyWith(isRewardedLoaded: false);
        },
      ),
    );
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
    
    state.rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdService] Rewarded ad dismissed');
        ad.dispose();
        state = state.copyWith(isRewardedLoaded: false, clearRewarded: true);
        // 다음 광고 미리 로드
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Rewarded ad failed to show: $error');
        ad.dispose();
        state = state.copyWith(isRewardedLoaded: false, clearRewarded: true);
        loadRewardedAd();
      },
    );
    
    await state.rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
        wasRewarded = true;
        onRewarded();
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
/// 구독자가 아닌 경우에만 광고 표시
final shouldShowAdsProvider = Provider<bool>((ref) {
  final adState = ref.watch(adProvider);
  return adState.isInitialized;
});
