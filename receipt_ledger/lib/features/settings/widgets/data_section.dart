import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import 'settings_dialogs.dart';

class DataManagementSection extends ConsumerStatefulWidget {
  final Function(String newKey, String newQr) onRestoreSuccess;
  final VoidCallback onResetSuccess;

  const DataManagementSection({
    super.key,
    required this.onRestoreSuccess,
    required this.onResetSuccess,
  });

  @override
  ConsumerState<DataManagementSection> createState() => _DataManagementSectionState();
}

class _DataManagementSectionState extends ConsumerState<DataManagementSection> {
  bool _isRestoring = false;

  Future<void> _handleRestore(String oldKey) async {
    if (oldKey.isEmpty) return;
    await _executeRestore(() async {
      final syncService = ref.read(syncServiceProvider);
      await syncService.initialize();
      return syncService.restoreMyKey(oldKey);
    });
  }

  Future<void> _handleRestoreFromEmail() async {
    await _executeRestore(() async {
      final syncService = ref.read(syncServiceProvider);
      await syncService.initialize();
      return syncService.restoreFromEmail();
    });
  }

  Future<void> _executeRestore(Future<dynamic> Function() restoreFn) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 데이터 복원 중...'),
          backgroundColor: Colors.blueGrey,
          duration: Duration(seconds: 10),
        ),
      );
    }

    setState(() { _isRestoring = true; });

    try {
      final result = await restoreFn();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success
                ? '✅ 데이터 복원 완료! (다운로드: ${result.downloaded}개)'
                : '❌ 복원 실패: ${result.message}'),
            backgroundColor: result.success ? AppColors.income : AppColors.expense,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (result.success) {
        final syncService = ref.read(syncServiceProvider);
        final newKey = syncService.myKey;
        final newQr = syncService.generateQrData();
        
        // Refresh providers
        ref.invalidate(transactionsProvider);
        ref.invalidate(selectedDateTransactionsProvider);
        ref.invalidate(monthlyTransactionsProvider);
        ref.invalidate(monthlyStatsProvider);
        
        widget.onRestoreSuccess(newKey, newQr);
      }
    } finally {
      if (mounted) {
        setState(() { _isRestoring = false; });
      }
    }
  }

  Future<void> _handleReset() async {
    final confirmed = await showResetDataDialog(context);
    
    if (confirmed) {
      final repository = ref.read(transactionRepositoryProvider);
      await repository.clearAllTransactions();
      
      // Refresh all data providers
      ref.invalidate(transactionsProvider);
      ref.invalidate(selectedDateTransactionsProvider);
      ref.invalidate(monthlyTransactionsProvider);
      ref.invalidate(monthlyStatsProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 거래 내역이 삭제되었습니다'),
            backgroundColor: AppColors.income,
          ),
        );
      }
      
      widget.onResetSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userEmail = authState.userEmail;
    final isLoggedIn = userEmail != null && userEmail.contains('@');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '데이터 관리',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        // Data Restore
        StyledCard(
          onTap: _isRestoring 
              ? null 
              : () => showRestoreKeyDialog(
                  context: context, 
                  ref: ref, 
                  onRestore: _handleRestore,
                  userEmail: userEmail,
                  onRestoreFromEmail: isLoggedIn ? _handleRestoreFromEmail : null,
                ),
          child: Row(
            children: [
              const Icon(Icons.restore, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '데이터 복원',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isRestoring 
                          ? '복원 중...' 
                          : isLoggedIn 
                              ? '로그인한 계정으로 서버에서 데이터 복원'
                              : '이전 키를 입력하여 서버에서 데이터 복원',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isRestoring)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Data Reset
        StyledCard(
          onTap: _handleReset,
          child: const Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '거래 데이터 초기화',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '모든 거래 내역을 삭제합니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }
}
