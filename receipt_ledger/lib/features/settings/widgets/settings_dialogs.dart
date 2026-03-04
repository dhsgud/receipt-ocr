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
  final partnerEmailController = TextEditingController();
  bool isSending = false;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppColors.primary),
            SizedBox(width: 8),
            Text('파트너 요청'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '파트너의 이메일을 입력하세요.\n상대방이 수락하면 데이터가 공유됩니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: partnerEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: '파트너 이메일',
                hintText: 'partner@example.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '상대방이 같은 앱에 가입되어 있어야 합니다',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: isSending ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: isSending ? null : () async {
              final email = partnerEmailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('유효한 이메일을 입력해주세요')),
                );
                return;
              }

              setState(() => isSending = true);

              final syncService = ref.read(syncServiceProvider);
              final result = await syncService.sendPartnerRequest(
                email,
                nickname: syncService.myNickname,
              );

              if (context.mounted) {
                Navigator.pop(context);
                final isOk = result['status'] == 'ok';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? (isOk ? '요청 전송 완료' : '요청 실패')),
                    backgroundColor: isOk ? AppColors.income : AppColors.expense,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: isSending
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('요청 보내기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

void showPartnerRequestsDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<dynamic> incomingRequests,
  required List<dynamic> outgoingRequests,
  required VoidCallback onChanged,
}) {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        bool isProcessing = false;

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: AppColors.primary),
              SizedBox(width: 8),
              Text('파트너 요청'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Incoming requests
                  if (incomingRequests.isNotEmpty) ...[
                    const Text(
                      '받은 요청',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...incomingRequests.map((req) {
                      final fromEmail = req['from_email'] as String? ?? '';
                      final fromNickname = req['from_nickname'] as String? ?? '';
                      final requestId = req['id'] as int;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, size: 20, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (fromNickname.isNotEmpty)
                                        Text(
                                          fromNickname,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      Text(
                                        fromEmail,
                                        style: TextStyle(
                                          fontSize: fromNickname.isNotEmpty ? 12 : 14,
                                          color: fromNickname.isNotEmpty ? Colors.grey : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: isProcessing ? null : () async {
                                    setState(() => isProcessing = true);
                                    final syncService = ref.read(syncServiceProvider);
                                    final result = await syncService.rejectPartnerRequest(requestId);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(result['message'] ?? '거절됨'),
                                          backgroundColor: AppColors.expense,
                                        ),
                                      );
                                      onChanged();
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.expense,
                                    side: const BorderSide(color: AppColors.expense),
                                  ),
                                  child: const Text('거절'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isProcessing ? null : () async {
                                    setState(() => isProcessing = true);
                                    final syncService = ref.read(syncServiceProvider);
                                    final result = await syncService.acceptPartnerRequest(requestId);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      final isOk = result['status'] == 'ok';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isOk
                                              ? '파트너가 연결되었습니다! 동기화를 시작합니다...'
                                              : (result['message'] ?? '수락 실패')),
                                          backgroundColor: isOk ? AppColors.income : AppColors.expense,
                                        ),
                                      );
                                      if (isOk) {
                                        final partnerEmail = result['partner_email'] as String? ?? '';
                                        final partnerNickname = result['partner_nickname'] as String? ?? '';
                                        onChanged();
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.income,
                                  ),
                                  child: const Text('수락', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  // Outgoing pending requests
                  if (outgoingRequests.isNotEmpty) ...[
                    if (incomingRequests.isNotEmpty) const SizedBox(height: 16),
                    const Text(
                      '보낸 요청 (대기 중)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...outgoingRequests.map((req) {
                      final toEmail = req['to_email'] as String? ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_empty, size: 20, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                toEmail,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Text(
                              '대기 중',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  // No requests at all
                  if (incomingRequests.isEmpty && outgoingRequests.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          '파트너 요청이 없습니다',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        );
      },
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
