import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        // My QR Code
        StyledCard(
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '내 QR 코드',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '파트너에게 이 QR을 보여주세요',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => showMyQrDialog(
                      context: context,
                      qrData: myQrData,
                      myKey: myKey,
                    ),
                    icon: const Icon(
                      Icons.fullscreen,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // My Key
        StyledCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.key),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '내 공유 키',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: myKey));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('키가 클립보드에 복사되었습니다')),
                      );
                    },
                    icon: const Icon(
                      Icons.copy,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  myKey.length > 20 
                      ? '${myKey.substring(0, 20)}...' 
                      : myKey,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Add Partner
        StyledCard(
          onTap: () => showAddPartnerDialog(
            context: context,
            ref: ref,
            onPartnerLinked: onPartnerLinked,
          ),
          child: Row(
            children: [
              const Icon(Icons.person_add),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '파트너 추가',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (partnerKey != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '연결됨: ${partnerNickname.isNotEmpty ? partnerNickname : partnerKey!.substring(0, 8)}...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),

        // Clear Partner Button
        if (partnerKey != null) ...[
          const SizedBox(height: 12),
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
        ],
      ],
    );
  }
}
