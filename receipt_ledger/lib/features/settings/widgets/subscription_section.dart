import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/entitlements.dart';
import '../../../data/services/quota_service.dart';
import '../../../shared/widgets/common_widgets.dart';

/// OCR 사용량 섹션 (구독 제거 → 광고 기반)
class SubscriptionSection extends ConsumerWidget {
  const SubscriptionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '분석 사용량',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, _) {
            final quotaState = ref.watch(quotaProvider);
            final remaining = quotaState.getRemainingFreeQuota();
            final total = QuotaConfig.freeTotalLimit + quotaState.bonusQuota;
            
            return StyledCard(
              child: Row(
                children: [
                  Icon(
                    remaining > 0 ? Icons.camera_alt : Icons.lock,
                    color: remaining > 0
                        ? const Color(0xFF6366F1)
                        : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '영수증 분석',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          remaining > 0
                              ? '남은 횟수: $remaining/$total회'
                              : '광고 시청으로 추가 사용 가능',
                          style: TextStyle(
                            fontSize: 12,
                            color: remaining > 0 ? Colors.grey : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (quotaState.bonusQuota > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '광고 보너스 +${quotaState.bonusQuota}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
