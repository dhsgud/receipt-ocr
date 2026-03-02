import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/app_providers.dart';

void showNicknameDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentNickname,
  required Function(String) onNicknameChanged,
}) {
  final controller = TextEditingController(text: currentNickname);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('내 닉네임 설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '파트너에게 보여질 내 이름표를 설정하세요',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: '닉네임',
              hintText: '예: 동한, 지수',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () async {
            final nickname = controller.text.trim();
            if (nickname.isNotEmpty) {
              final syncService = ref.read(syncServiceProvider);
              await syncService.setMyNickname(nickname);
              onNicknameChanged(nickname);
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('닉네임이 설정되었습니다'),
                    backgroundColor: AppColors.income,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('저장', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

void showMyQrDialog({
  required BuildContext context,
  required String qrData,
  required String myKey,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        '내 QR 코드',
        style: TextStyle(color: Colors.black),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (qrData.isNotEmpty && qrData != 'Error')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            )
          else
            const Text('QR 코드를 생성할 수 없습니다'),
          const SizedBox(height: 16),
          Text(
            '키: ${myKey.length > 20 ? '${myKey.substring(0, 20)}...' : myKey}',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '파트너에게 이 QR 코드를 보여주거나\n키를 공유하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: myKey));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('키가 클립보드에 복사되었습니다')),
            );
          },
          child: const Text('키 복사'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

void showAddPartnerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Function(String key, String nickname) onPartnerLinked,
}) {
  final partnerKeyController = TextEditingController();
  final partnerNicknameController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('파트너 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '파트너의 공유 키와 닉네임을 입력하세요',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: partnerKeyController,
            decoration: InputDecoration(
              labelText: '파트너 키',
              hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: partnerNicknameController,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: '파트너 닉네임 (선택)',
              hintText: '예: 지수, 영희',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () async {
            final key = partnerKeyController.text.trim();
            if (key.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('파트너 키를 입력해주세요')),
              );
              return;
            }

            final syncService = ref.read(syncServiceProvider);
            await syncService.setPartnerKey(key);
            
            final partnerNickname = partnerNicknameController.text.trim();
            if (partnerNickname.isNotEmpty) {
              await syncService.setPartnerNickname(partnerNickname);
            }
            
            onPartnerLinked(key, partnerNickname);
            
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('연결', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

void showRestoreKeyDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Function(String oldKey) onRestore,
  String? userEmail,
  VoidCallback? onRestoreFromEmail,
}) {
  // 이메일 로그인된 상태: 간단한 확인 다이얼로그
  if (userEmail != null && userEmail.contains('@') && onRestoreFromEmail != null) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore, color: AppColors.primary),
            SizedBox(width: 8),
            Text('데이터 복원'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '로그인한 계정의 데이터를 서버에서 복원합니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      userEmail,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '같은 계정으로 로그인하면 앱 재설치 후에도\n데이터를 복원할 수 있습니다',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRestoreFromEmail();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('복원', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return;
  }

  // 비로그인 상태: 기존 UUID 키 입력 방식
  final keyController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.restore, color: AppColors.primary),
          SizedBox(width: 8),
          Text('데이터 복원'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '앱 재설치 전에 복사해둔 동기화 키를 입력하면\n서버에서 이전 데이터를 복원합니다.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '현재 내 키는 설정 > 파트너 공유 > 내 공유 키에서 미리 복사해두세요',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: keyController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: '이전 동기화 키',
              hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.key),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final oldKey = keyController.text.trim();
            if (oldKey.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('키를 입력해주세요')),
              );
              return;
            }
            Navigator.pop(context);
            onRestore(oldKey);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('복원', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

Future<bool> showResetDataDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('데이터 초기화'),
        ],
      ),
      content: const Text(
        '모든 거래 내역이 영구적으로 삭제됩니다.\n\n이 작업은 되돌릴 수 없습니다.\n정말 삭제하시겠습니까?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
