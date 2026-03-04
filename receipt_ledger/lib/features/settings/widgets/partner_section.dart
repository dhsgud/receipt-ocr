import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'settings_dialogs.dart';

class PartnerSection extends ConsumerWidget {
  final String myNickname;
  final String myKey;
  final String myQrData;
  final String? partnerKey;
  final String partnerNickname;
  final Function(String) onNicknameChanged;
  final Function(String, String) onPartnerLinked;
  final VoidCallback onPartnerCleared;
  final List<dynamic> incomingRequests;
  final List<dynamic> outgoingRequests;
  final VoidCallback onRefreshRequests;

  const PartnerSection({
    super.key,
    required this.myNickname,
    required this.myKey,
    required this.myQrData,
    required this.partnerKey,
    required this.partnerNickname,
    required this.onNicknameChanged,
    required this.onPartnerLinked,
    required this.onPartnerCleared,
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    required this.onRefreshRequests,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasIncoming = incomingRequests.isNotEmpty;
    final hasOutgoing = outgoingRequests.isNotEmpty;
    final hasRequests = hasIncoming || hasOutgoing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '파트너 공유',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),

        // My Nickname
        StyledCard(
          onTap: () => showNicknameDialog(
            context: context,
            ref: ref,
            currentNickname: myNickname,
            onNicknameChanged: onNicknameChanged,
          ),
          child: Row(
            children: [
              const Icon(Icons.badge_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '내 닉네임',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      myNickname.isNotEmpty ? myNickname : '탭하여 설정',
                      style: TextStyle(
                        fontSize: 12,
                        color: myNickname.isNotEmpty
                            ? AppColors.income
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Partner Request / Connected Partner Status
        if (partnerKey != null && partnerKey!.isNotEmpty) ...[
          // Connected partner info
          StyledCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.people, color: AppColors.income, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '파트너 연결됨',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        partnerNickname.isNotEmpty
                            ? '$partnerNickname ($partnerKey)'
                            : partnerKey!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.income,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: AppColors.income),
                      SizedBox(width: 4),
                      Text(
                        '연결됨',
                        style: TextStyle(fontSize: 11, color: AppColors.income, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Disconnect button
          TextButton.icon(
            onPressed: onPartnerCleared,
            icon: const Icon(
              Icons.link_off,
              color: AppColors.expense,
            ),
            label: const Text(
              '파트너 연결 해제',
              style: TextStyle(color: AppColors.expense),
            ),
          ),
        ] else ...[
          // Send partner request button
          StyledCard(
            onTap: () => showAddPartnerDialog(
              context: context,
              ref: ref,
              onPartnerLinked: onPartnerLinked,
            ),
            child: Row(
              children: [
                const Icon(Icons.person_add, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '파트너 요청 보내기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasOutgoing
                            ? '대기 중인 요청 ${outgoingRequests.length}건'
                            : '이메일로 파트너를 초대하세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasOutgoing ? Colors.orange : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Incoming requests button (always visible)
        StyledCard(
          onTap: () => showPartnerRequestsDialog(
            context: context,
            ref: ref,
            incomingRequests: incomingRequests,
            outgoingRequests: outgoingRequests,
            onChanged: onRefreshRequests,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.mail_outline,
                    color: hasIncoming ? AppColors.primary : Colors.grey,
                  ),
                  if (hasIncoming)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.expense,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${incomingRequests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '받은 파트너 요청',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasIncoming
                          ? '${incomingRequests.length}건의 새 요청'
                          : '받은 요청이 없습니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasIncoming ? AppColors.primary : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasIncoming)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.expense,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }
}
