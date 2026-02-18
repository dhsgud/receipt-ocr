import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/notification_monitor_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class NotificationSection extends ConsumerStatefulWidget {
  const NotificationSection({super.key});

  @override
  ConsumerState<NotificationSection> createState() => _NotificationSectionState();
}

class _NotificationSectionState extends ConsumerState<NotificationSection> {
  Future<void> _enableNotificationMonitoring() async {
    final repository = ref.read(transactionRepositoryProvider);
    final service = NotificationMonitorService(repository);
    
    // Check permission
    final hasPermission = await service.isPermissionGranted();
    
    if (!hasPermission) {
      // Request permission - opens Android settings
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림 접근 권한을 허용해주세요. 설정 화면으로 이동합니다...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      final granted = await service.requestPermission();
      
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('알림 접근 권한이 필요합니다'),
              backgroundColor: AppColors.expense,
            ),
          );
        }
        return;
      }
    }
    
    // Enable monitoring
    await service.setEnabled(true);
    ref.read(notificationMonitorEnabledProvider.notifier).state = true;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알림 모니터링이 활성화되었습니다'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  Future<void> _disableNotificationMonitoring() async {
    final repository = ref.read(transactionRepositoryProvider);
    final service = NotificationMonitorService(repository);
    
    await service.setEnabled(false);
    ref.read(notificationMonitorEnabledProvider.notifier).state = false;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 모니터링이 비활성화되었습니다')),
      );
    }
  }

  Widget _buildAppChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '결제 알림 자동 등록',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, _) {
            final isEnabled = ref.watch(notificationMonitorEnabledProvider);
            
            return StyledCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '알림 자동 감지',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEnabled 
                                  ? '결제 알림 → 자동 가계부 등록' 
                                  : '비활성화됨',
                              style: TextStyle(
                                fontSize: 12,
                                color: isEnabled ? AppColors.income : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (kIsWeb)
                        const Text(
                          '모바일 전용',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      else
                        Switch.adaptive(
                          value: isEnabled,
                          onChanged: (value) async {
                            if (value) {
                              await _enableNotificationMonitoring();
                            } else {
                              await _disableNotificationMonitoring();
                            }
                          },
                          activeTrackColor: AppColors.primary,
                        ),
                    ],
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      '지원 앱',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildAppChip('삼성페이'),
                        _buildAppChip('카카오페이'),
                        _buildAppChip('네이버페이'),
                        _buildAppChip('토스'),
                        _buildAppChip('카드사 앱'),
                        _buildAppChip('은행 앱'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '📌 결제 알림에서 금액, 가게명을 자동 추출하여\n    가계부에 등록합니다.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
