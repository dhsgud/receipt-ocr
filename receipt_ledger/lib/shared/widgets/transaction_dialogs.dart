import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';
import '../providers/app_providers.dart';

// =============================================================================
// Shared transaction management dialogs & widgets
// Used by HomeScreen, CalendarScreen, and AllTransactionsScreen.
// =============================================================================

/// Shows a bottom sheet context menu for a transaction (long-press action).
void showTransactionMenu({
  required BuildContext context,
  required WidgetRef ref,
  required TransactionModel transaction,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Transaction summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        Category.findByName(transaction.category).emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.currency(transaction.amount),
                          style: TextStyle(
                            fontSize: 14,
                            color: transaction.isIncome
                                ? AppColors.income
                                : AppColors.expense,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            // Menu options
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, color: Colors.blue),
              ),
              title: const Text('상세 정보'),
              subtitle: const Text('거래 내역 자세히 보기'),
              onTap: () {
                Navigator.pop(ctx);
                showTransactionDetailsDialog(
                  context: context,
                  ref: ref,
                  transaction: transaction,
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.edit_outlined, color: Colors.orange),
              ),
              title: const Text('수정'),
              subtitle: const Text('거래 내용 편집하기'),
              onTap: () {
                Navigator.pop(ctx);
                showEditTransactionDialog(
                  context: context,
                  ref: ref,
                  transaction: transaction,
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title:
                  const Text('삭제', style: TextStyle(color: Colors.red)),
              subtitle: const Text('이 거래 내역 삭제하기'),
              onTap: () {
                Navigator.pop(ctx);
                showDeleteTransactionDialog(
                  context: context,
                  ref: ref,
                  transaction: transaction,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Shows a detail dialog for a transaction.
void showTransactionDetailsDialog({
  required BuildContext context,
  required WidgetRef ref,
  required TransactionModel transaction,
}) {
  final category = Category.findByName(transaction.category);
  final syncService = ref.read(syncServiceProvider);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          const Expanded(child: Text('거래 상세 정보')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb) ReceiptImageWithServer(ref: ref, transaction: transaction),
            DetailRow(label: '설명', value: transaction.description),
            if (transaction.memo != null && transaction.memo!.isNotEmpty)
              DetailRow(label: '메모', value: transaction.memo!),
            DetailRow(
              label: '금액',
              value:
                  '${transaction.isIncome ? '+' : '-'}${Formatters.currency(transaction.amount)}',
            ),
            DetailRow(label: '카테고리', value: transaction.category),
            DetailRow(label: '날짜', value: Formatters.date(transaction.date)),
            DetailRow(label: '시간', value: Formatters.time(transaction.date)),
            if (transaction.storeName != null &&
                transaction.storeName!.isNotEmpty)
              DetailRow(label: '상점명', value: transaction.storeName!),
            DetailRow(
                label: '유형', value: transaction.isIncome ? '수입' : '지출'),
            DetailRow(
              label: '등록자',
              value: syncService.getOwnerName(transaction.ownerKey),
            ),
            DetailRow(
                label: '동기화',
                value: transaction.isSynced ? '완료' : '대기중'),
            DetailRow(
                label: '생성일',
                value: Formatters.date(transaction.createdAt)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

/// Shows an edit dialog for a transaction.
void showEditTransactionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required TransactionModel transaction,
}) {
  final descController = TextEditingController(text: transaction.description);
  final amountController =
      TextEditingController(text: transaction.amount.toStringAsFixed(0));
  final storeController =
      TextEditingController(text: transaction.storeName ?? '');
  final memoController =
      TextEditingController(text: transaction.memo ?? '');
  String selectedCategory = transaction.category;
  bool isIncome = transaction.isIncome;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('거래 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '설명',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '금액',
                  border: OutlineInputBorder(),
                  prefixText: '₩ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storeController,
                decoration: const InputDecoration(
                  labelText: '상점명 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: '카테고리',
                  border: OutlineInputBorder(),
                ),
                items: Category.defaultCategories.map((cat) {
                  return DropdownMenuItem(
                    value: cat.name,
                    child: Text('${cat.emoji} ${cat.name}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: memoController,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('수입'),
                subtitle: Text(
                    isIncome ? '이 거래는 수입입니다' : '이 거래는 지출입니다'),
                value: isIncome,
                onChanged: (value) {
                  setDialogState(() => isIncome = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedTransaction = transaction.copyWith(
                description: descController.text.trim(),
                amount: double.tryParse(amountController.text) ??
                    transaction.amount,
                storeName: storeController.text.trim().isEmpty
                    ? null
                    : storeController.text.trim(),
                category: selectedCategory,
                isIncome: isIncome,
                memo: memoController.text.trim().isEmpty
                    ? null
                    : memoController.text.trim(),
                updatedAt: DateTime.now(),
                isSynced: false,
              );

              final repository = ref.read(transactionRepositoryProvider);
              await repository.updateTransaction(updatedTransaction);

              // Refresh providers
              ref.invalidate(transactionsProvider);
              ref.invalidate(selectedDateTransactionsProvider);
              ref.invalidate(monthlyStatsProvider);
              ref.invalidate(monthlyTransactionsProvider);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('거래가 수정되었습니다'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    ),
  );
}

/// Shows a delete confirmation dialog for a transaction.
void showDeleteTransactionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required TransactionModel transaction,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('거래 삭제'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이 거래를 정말 삭제하시겠습니까?'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  Category.findByName(transaction.category).emoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${transaction.isIncome ? '+' : '-'}${Formatters.currency(transaction.amount)}',
                        style: TextStyle(
                          color: transaction.isIncome
                              ? AppColors.income
                              : AppColors.expense,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '삭제된 거래는 복구할 수 없습니다.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final repository = ref.read(transactionRepositoryProvider);
            await repository.deleteTransaction(transaction.id);

            // Refresh providers
            ref.invalidate(transactionsProvider);
            ref.invalidate(selectedDateTransactionsProvider);
            ref.invalidate(monthlyStatsProvider);
            ref.invalidate(monthlyTransactionsProvider);

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('거래가 삭제되었습니다'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('삭제'),
        ),
      ],
    ),
  );
}

// =============================================================================
// Shared widgets
// =============================================================================

/// A label-value row used in detail dialogs.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const DetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loads receipt image from sync service cache and displays it.
class ReceiptImageWithServer extends StatelessWidget {
  final WidgetRef ref;
  final TransactionModel transaction;

  const ReceiptImageWithServer({
    super.key,
    required this.ref,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final syncService = ref.read(syncServiceProvider);

    return FutureBuilder<String?>(
      future: syncService.imageCacheService.getImagePath(
        transaction.id,
        transaction.receiptImagePath,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final imagePath = snapshot.data;
        if (imagePath == null || imagePath.isEmpty) {
          return const SizedBox.shrink();
        }

        return ReceiptImageSection(imagePath: imagePath);
      },
    );
  }
}

/// Displays a receipt image with tap-to-expand.
class ReceiptImageSection extends StatelessWidget {
  final String imagePath;

  const ReceiptImageSection({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '영수증 이미지',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => showFullScreenImage(context, imagePath),
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in,
                              color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('탭하여 확대',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Full screen interactive image viewer for receipts.
void showFullScreenImage(BuildContext context, String imagePath) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('영수증 이미지',
              style: TextStyle(color: Colors.white)),
        ),
        body: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(File(imagePath), fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}
