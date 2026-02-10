import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/purchase_service.dart';
import '../../core/entitlements.dart';

/// 배너 광고 위젯 (Free 등급만 표시)
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // 웹에서는 광고 표시 안 함
    if (kIsWeb) return;

    _bannerAd = BannerAd(
      adUnitId: AdIds.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[BannerAdWidget] ✅ Ad loaded successfully');
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[BannerAdWidget] ❌ Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 웹에서는 빈 위젯
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    // 프리미엄 사용자는 광고 비표시
    final subscription = ref.watch(subscriptionProvider);
    if (subscription.isPremium) {
      return const SizedBox.shrink();
    }

    // 광고가 로드되지 않은 경우 — 공간만 확보
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox(height: 50);
    }

    // 배너 광고 표시
    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// 광고 컨테이너 (배경, 패딩 포함)
class AdContainer extends StatelessWidget {
  final Widget child;
  
  const AdContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Center(child: child),
    );
  }
}

/// Safe Area와 함께 사용하는 상단 배너 광고
class TopBannerAd extends StatelessWidget {
  const TopBannerAd({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    
    return const AdContainer(
      child: BannerAdWidget(),
    );
  }
}

/// 하단 배너 광고
class BottomBannerAd extends StatelessWidget {
  const BottomBannerAd({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    
    return SafeArea(
      child: AdContainer(
        child: const BannerAdWidget(),
      ),
    );
  }
}
