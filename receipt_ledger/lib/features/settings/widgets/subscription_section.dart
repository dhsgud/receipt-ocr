import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/entitlements.dart';
import '../../../data/services/purchase_service.dart';
import '../../../data/services/quota_service.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../subscription_screen.dart';

class SubscriptionSection extends ConsumerWidget {
  const SubscriptionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '구독',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, _) {
            final subscription = ref.watch(subscriptionProvider);
            return StyledCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen(),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(
                    subscription.isPremium
                        ? Icons.workspace_premium
                        : Icons.star_outline,
                    color: subscription.isPremium
                        ? const Color(0xFF6366F1)
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.tier != SubscriptionTier.free ? '프리미엄 구독 중' : '프리미엄 구독',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Builder(
                          builder: (context) {
                            final tier = subscription.tier;
                            if (tier != SubscriptionTier.free) {
                              return Text(
                                tier == SubscriptionTier.pro ? 'Pro: 무제한 OCR' : 'Basic: 무제한 OCR',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6366F1),
                                ),
                              );
                            }
                            final quotaState = ref.watch(quotaProvider);
                            final remaining = quotaState.getRemainingFreeQuota();
                            return Text(
                              '무료 OCR $remaining/${QuotaConfig.freeTotalLimit}회 남음',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
