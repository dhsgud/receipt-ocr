import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/purchase_service.dart';
import '../../core/entitlements.dart';

/// 배너 광고 위젯 (Stub)
/// 
/// 실제 AdMob을 활성화하려면:
/// 1. pubspec.yaml에서 google_mobile_ads 주석 해제
/// 2. iOS Info.plist에 GADApplicationIdentifier 추가
/// 3. Android AndroidManifest.xml에 AdMob App ID 추가
/// 4. 이 파일을 원래 버전으로 복원
class BannerAdWidget extends ConsumerWidget {
  const BannerAdWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AdMob 비활성화 - 빈 위젯 반환
    return const SizedBox.shrink();
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
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Center(child: child),
    );
  }
}

/// Safe Area와 함께 사용하는 하단 배너 광고 (Stub)
class BottomBannerAd extends StatelessWidget {
  const BottomBannerAd({super.key});

  @override
  Widget build(BuildContext context) {
    // AdMob 비활성화 - 빈 위젯 반환
    return const SizedBox.shrink();
  }
}
