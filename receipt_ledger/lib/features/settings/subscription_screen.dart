import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../data/services/purchase_service.dart';
import '../../data/services/quota_service.dart';
import '../../core/entitlements.dart';
import '../../core/theme/app_theme.dart';

/// 프리미엄 구독 관리 화면
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // Offerings 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).loadOfferings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('프리미엄 구독'),
        actions: [
          // 구매 복원 버튼
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: '구매 복원',
            onPressed: subscription.isLoading ? null : _restorePurchases,
          ),
        ],
      ),
      body: subscription.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 현재 상태 카드
                  _buildStatusCard(subscription),
                  const SizedBox(height: 24),

                  // 에러 표시
                  if (subscription.error != null) ...[
                    _buildErrorCard(subscription.error!),
                    const SizedBox(height: 16),
                  ],

                  // 프리미엄이 아닌 경우 구독 옵션 표시
                  if (!subscription.isPremium) ...[
                    _buildFeaturesCard(),
                    const SizedBox(height: 24),
                    
                    // RevenueCat Paywall 버튼
                    _buildPaywallButton(),
                  ],

                  // 프리미엄인 경우 Customer Center 표시
                  if (subscription.isPremium) ...[
                    const SizedBox(height: 24),
                    _buildCustomerCenterButton(),
                    const SizedBox(height: 16),
                    _buildSubscriptionDetailsCard(subscription),
                  ],

                  // 디버그 섹션 (개발 중에만)
                  if (!const bool.fromEnvironment('dart.vm.product')) ...[
                    const SizedBox(height: 32),
                    _buildDebugSection(subscription),
                  ],
                ],
              ),
            ),
    );
  }

  /// 현재 상태 카드
  Widget _buildStatusCard(SubscriptionState subscription) {
    final isPremium = subscription.isPremium;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isPremium
            ? const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.grey[800]!, Colors.grey[700]!],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isPremium
                ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 아이콘
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? Icons.workspace_premium : Icons.star_outline,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // 상태 텍스트
          Text(
            isPremium
                ? (subscription.isLifetime ? '평생 이용권' : '프리미엄 구독 중')
                : '무료 플랜',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // 상세 정보
          if (isPremium) ...[
            if (subscription.expirationDate != null)
              Text(
                '만료: ${_formatDate(subscription.expirationDate!)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              )
            else if (subscription.isLifetime)
              Text(
                '평생 사용 가능',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
          ] else ...[
            Builder(
              builder: (context) {
                final quotaState = ref.watch(quotaProvider);
                final remaining = quotaState.getRemainingFreeQuota();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '무료 OCR 남은 횟수: $remaining/${QuotaConfig.freeTotalLimit}회',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// 에러 카드
  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// 프리미엄 기능 목록 카드
  Widget _buildFeaturesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text(
                '프리미엄 혜택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...SubscriptionFeatures.basicFeatures.map(
            (feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    feature,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// RevenueCat Paywall 버튼
  Widget _buildPaywallButton() {
    return ElevatedButton(
      onPressed: _showPaywall,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium),
          SizedBox(width: 8),
          Text(
            '프리미엄 구독하기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  /// Customer Center 버튼
  Widget _buildCustomerCenterButton() {
    return OutlinedButton(
      onPressed: _showCustomerCenter,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6366F1),
        side: const BorderSide(color: Color(0xFF6366F1)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings),
          SizedBox(width: 8),
          Text(
            '구독 관리',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// 구독 상세 정보
  Widget _buildSubscriptionDetailsCard(SubscriptionState subscription) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '구독 정보',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
          _buildInfoRow('상품', subscription.activeProductId ?? '-'),
          if (subscription.expirationDate != null)
            _buildInfoRow('만료일', _formatDate(subscription.expirationDate!)),
          if (subscription.customerInfo?.originalAppUserId != null)
            _buildInfoRow(
              '사용자 ID',
              subscription.customerInfo!.originalAppUserId,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// 디버그 섹션
  Widget _buildDebugSection(SubscriptionState subscription) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                '디버그 (개발용)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tier: ${subscription.tier}\n'
            'Is Premium: ${subscription.tier != SubscriptionTier.free}\n'
            'Product: ${subscription.activeProductId ?? "none"}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () {
                  ref.read(quotaProvider.notifier).resetQuota();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('쿼터 리셋됨')),
                  );
                },
                child: const Text('Reset Quota'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(subscriptionProvider.notifier).checkSubscriptionStatus();
                },
                child: const Text('Refresh Status'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Actions
  // ===========================================================================

  /// RevenueCat Paywall 표시
  Future<void> _showPaywall() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('웹에서는 결제를 지원하지 않습니다')),
      );
      return;
    }

    final result = await ref.read(subscriptionProvider.notifier).presentPaywall();

    if (!mounted) return;

    switch (result) {
      case PaywallResult.purchased:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 프리미엄 구독 완료!'),
            backgroundColor: AppColors.income,
          ),
        );
        break;
      case PaywallResult.restored:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 구매 복원 완료!'),
            backgroundColor: AppColors.income,
          ),
        );
        break;
      case PaywallResult.cancelled:
        // 취소는 메시지 표시 안함
        break;
      case PaywallResult.error:
        // 에러는 상태에서 처리됨
        break;
      default:
        break;
    }
  }

  /// Customer Center 표시
  Future<void> _showCustomerCenter() async {
    await ref.read(subscriptionProvider.notifier).presentCustomerCenter();
  }

  /// 구매 복원
  Future<void> _restorePurchases() async {
    final restored =
        await ref.read(subscriptionProvider.notifier).restorePurchases();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(restored ? '✅ 구매 복원 완료!' : '복원할 구매가 없습니다'),
        backgroundColor: restored ? AppColors.income : null,
      ),
    );
  }

  /// 수동 패키지 구매
  Future<void> _purchasePackage(Package package) async {
    final success =
        await ref.read(subscriptionProvider.notifier).purchasePackage(package);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 구매 완료!'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _getPackageTitle(Package package) {
    switch (package.packageType) {
      case PackageType.monthly:
        return '월간 구독';
      case PackageType.annual:
        return '연간 구독';
      case PackageType.lifetime:
        return '평생 이용권';
      default:
        return package.storeProduct.title;
    }
  }

  String _getPackageDescription(Package package) {
    switch (package.packageType) {
      case PackageType.monthly:
        return '매월 자동 갱신';
      case PackageType.annual:
        return '연간 결제 시 17% 할인';
      case PackageType.lifetime:
        return '한 번 구매로 평생 사용';
      default:
        return package.storeProduct.description;
    }
  }
}
