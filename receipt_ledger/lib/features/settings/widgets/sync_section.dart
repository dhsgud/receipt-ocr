import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/sync_tutorial_overlay.dart';
import 'settings_dialogs.dart';

class SyncSection extends ConsumerWidget {
  final bool isServerConnected;
  final bool isSyncing;
  final String? partnerKey;
  final bool showSyncTutorial;
  final VoidCallback onDismissTutorial;
  final VoidCallback onSync;
  final VoidCallback onTestConnection;
  
  // For tutorial callbacks
  final String myNickname;
  final Function(String) onNicknameChanged;
  final String myKey;
  final String myQrData;

  const SyncSection({
    super.key,
    required this.isServerConnected,
    required this.isSyncing,
    required this.partnerKey,
    required this.showSyncTutorial,
    required this.onDismissTutorial,
    required this.onSync,
    required this.onTestConnection,
    required this.myNickname,
    required this.onNicknameChanged,
    required this.myKey,
    required this.myQrData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '데이터 동기화',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),

        // Sync Tutorial Banner
        if (showSyncTutorial)
          SyncTutorialBanner(
            onDismiss: onDismissTutorial,
            onSetNickname: () => showNicknameDialog(
              context: context,
              ref: ref,
              currentNickname: myNickname,
              onNicknameChanged: onNicknameChanged,
            ),
            onShowQr: () => showMyQrDialog(
              context: context,
              qrData: myQrData,
              myKey: myKey,
            ),
            onSync: onSync,
          ),

        // Server Connection Status
        StyledCard(
          onTap: onTestConnection,
          child: Row(
            children: [
              Icon(
                isServerConnected ? Icons.cloud_done : Icons.cloud_off,
                color: isServerConnected ? AppColors.income : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '동기화 서버',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isServerConnected ? '연결됨' : '연결 안됨 (탭하여 재시도)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isServerConnected
                            ? AppColors.income
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isServerConnected)
                const Icon(Icons.check_circle, color: AppColors.income, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Partner not connected warning
        if (isServerConnected && partnerKey == null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '동기화하려면 먼저 파트너를 연결해주세요',
                    style: TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Sync Now Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isServerConnected && !isSyncing
                ? onSync
                : null,
            icon: isSyncing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync, color: Colors.white),
            label: Text(
              isSyncing
                  ? '동기화 중...'
                  : '지금 동기화',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
