import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../data/services/ad_service.dart';

/// 배너 광고 위젯 (항상 표시)
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _adRequested = false;
  String _statusMessage = '광고 대기중...';

  @override
  void initState() {
    super.initState();
    // initState에서는 ref를 안전하게 사용할 수 없으므로 didChangeDependencies에서 처리
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AdMob이 초기화된 경우에만 광고 로드
    final isInitialized = ref.read(adProvider).isInitialized;
    if (!kIsWeb && isInitialized && !_adRequested) {
      _adRequested = true;
      _loadAd();
    }
  }

  void _loadAd() {
    // 웹에서는 광고 표시 안 함
    if (kIsWeb) return;

    if (mounted) {
      setState(() {
        _statusMessage = '광고 로드중... (${AdIds.bannerAdUnitId})';
      });
    }

    _bannerAd = BannerAd(
      adUnitId: AdIds.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
              _statusMessage = '광고 로드 성공!';
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[BannerAdWidget] Failed to load banner: ${error.message} (code: ${error.code})');
          ad.dispose();
          if (mounted) {
            setState(() {
              _statusMessage = '❌ ${error.message} (code:${error.code})';
            });
          }
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

    // AdMob 초기화 상태 구독 → 초기화 완료되면 광고 자동 로드
    final isInitialized = ref.watch(adProvider.select((s) => s.isInitialized));
    if (isInitialized && !_adRequested) {
      _adRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
    }

    // 광고가 로드된 경우 표시
    if (_isLoaded && _bannerAd != null) {
      return Container(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // 광고 로드 상태 표시 (디버그용 — 나중에 SizedBox.shrink()로 변경)
    return Container(
      height: 50,
      alignment: Alignment.center,
      child: Text(
        _statusMessage,
        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        textAlign: TextAlign.center,
      ),
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
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Center(child: child),
      ),
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
