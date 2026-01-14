import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  
  /// 롱프레스 시 컨텍스트 메뉴 표시
  void _showTransactionMenu(BuildContext context, TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들 바
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // 거래 요약 정보
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
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
              // 메뉴 옵션들
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info_outline, color: Colors.blue),
                ),
                title: const Text('상세 정보'),
                subtitle: const Text('거래 내역 자세히 보기'),
                onTap: () {
                  Navigator.pop(context);
                  _showTransactionDetails(context, transaction);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined, color: Colors.orange),
                ),
                title: const Text('수정'),
                subtitle: const Text('거래 내용 편집하기'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, transaction);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                title: const Text('삭제', style: TextStyle(color: Colors.red)),
                subtitle: const Text('이 거래 내역 삭제하기'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, transaction);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 상세 정보 다이얼로그
  void _showTransactionDetails(BuildContext context, TransactionModel transaction) {
    final category = Category.findByName(transaction.category);
    
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
              _buildDetailRow('설명', transaction.description),
              _buildDetailRow('금액', '${transaction.isIncome ? '+' : '-'}${Formatters.currency(transaction.amount)}'),
              _buildDetailRow('카테고리', transaction.category),
              _buildDetailRow('날짜', Formatters.date(transaction.date)),
              _buildDetailRow('시간', Formatters.time(transaction.date)),
              if (transaction.storeName != null && transaction.storeName!.isNotEmpty)
                _buildDetailRow('상점명', transaction.storeName!),
              _buildDetailRow('유형', transaction.isIncome ? '수입' : '지출'),
              _buildDetailRow('동기화', transaction.isSynced ? '완료' : '대기중'),
              _buildDetailRow('생성일', Formatters.date(transaction.createdAt)),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 수정 다이얼로그
  void _showEditDialog(BuildContext context, TransactionModel transaction) {
    final descController = TextEditingController(text: transaction.description);
    final amountController = TextEditingController(text: transaction.amount.toStringAsFixed(0));
    final storeController = TextEditingController(text: transaction.storeName ?? '');
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
                SwitchListTile(
                  title: const Text('수입'),
                  subtitle: Text(isIncome ? '이 거래는 수입입니다' : '이 거래는 지출입니다'),
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
                  amount: double.tryParse(amountController.text) ?? transaction.amount,
                  storeName: storeController.text.trim().isEmpty ? null : storeController.text.trim(),
                  category: selectedCategory,
                  isIncome: isIncome,
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

  /// 삭제 확인 다이얼로그
  void _showDeleteConfirmation(BuildContext context, TransactionModel transaction) {
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
                color: Colors.grey.withOpacity(0.1),
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
                          style: const TextStyle(fontWeight: FontWeight.w500),
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

  @override
  Widget build(BuildContext context) {
    final monthlyStats = ref.watch(monthlyStatsProvider);
    final selectedDateTransactions = ref.watch(selectedDateTransactionsProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '안녕하세요 👋',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.month(DateTime.now()),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Monthly Summary Card
                    monthlyStats.when(
                      data: (stats) => _buildSummaryCard(stats),
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // Today's Transactions Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.dateShort(selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to all transactions
                      },
                      child: const Text('전체보기'),
                    ),
                  ],
                ),
              ),
            ),

            // Transactions List
            selectedDateTransactions.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: '거래 내역이 없습니다',
                      subtitle: '영수증을 촬영하여 거래를 추가해보세요',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final transaction = transactions[index];
                        final category = Category.findByName(transaction.category);

                        return TransactionListItem(
                          emoji: category.emoji,
                          title: transaction.description,
                          subtitle: '${transaction.category} • ${Formatters.time(transaction.date)}',
                          amount: Formatters.currency(transaction.amount),
                          isIncome: transaction.isIncome,
                          onTap: () {
                            _showTransactionDetails(context, transaction);
                          },
                          onLongPress: () {
                            _showTransactionMenu(context, transaction);
                          },
                        );
                      },
                      childCount: transactions.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SliverFillRemaining(
                child: Center(child: Text('오류가 발생했습니다')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(MonthlyStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 달 잔액',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.currency(stats.balance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  '수입',
                  Formatters.currency(stats.income),
                  Icons.arrow_downward,
                  Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMiniStat(
                  '지출',
                  Formatters.currency(stats.expense),
                  Icons.arrow_upward,
                  Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
