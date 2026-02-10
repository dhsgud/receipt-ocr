import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';

class AllTransactionsScreen extends ConsumerStatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  ConsumerState<AllTransactionsScreen> createState() =>
      _AllTransactionsScreenState();
}

class _AllTransactionsScreenState
    extends ConsumerState<AllTransactionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 거래 목록을 날짜별로 그룹화
  Map<String, List<TransactionModel>> _groupByDate(
      List<TransactionModel> transactions) {
    final grouped = <String, List<TransactionModel>>{};
    for (final t in transactions) {
      final key = Formatters.date(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    return grouped;
  }

  /// 검색 필터링
  List<TransactionModel> _filterTransactions(
      List<TransactionModel> transactions) {
    if (_searchQuery.isEmpty) return transactions;
    final query = _searchQuery.toLowerCase();
    return transactions.where((t) {
      return t.description.toLowerCase().contains(query) ||
          (t.storeName?.toLowerCase().contains(query) ?? false) ||
          t.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allTransactions = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 거래 내역'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: '거래 내역 검색 (설명, 상점, 카테고리)',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey[500], size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500], size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 콘텐츠
          Expanded(
            child: allTransactions.when(
              data: (transactions) {
                final filtered = _filterTransactions(transactions);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? '검색 결과가 없습니다'
                              : '거래 내역이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? '다른 키워드로 검색해보세요'
                              : '영수증을 촬영하여 거래를 추가해보세요',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 요약 카드 데이터 계산
                final totalIncome = filtered
                    .where((t) => t.isIncome)
                    .fold<double>(0.0, (sum, t) => sum + t.amount);
                final totalExpense = filtered
                    .where((t) => !t.isIncome)
                    .fold<double>(0.0, (sum, t) => sum + t.amount);

                // 날짜별 그룹화
                final grouped = _groupByDate(filtered);
                final dateKeys = grouped.keys.toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(transactionsProvider);
                  },
                  child: CustomScrollView(
                    slivers: [
                      // 요약 카드
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: _buildSummaryRow(
                            totalCount: filtered.length,
                            totalIncome: totalIncome,
                            totalExpense: totalExpense,
                          ),
                        ),
                      ),

                      // 날짜별 그룹화된 거래 목록
                      for (int i = 0; i < dateKeys.length; i++) ...[
                        // 날짜 헤더
                        SliverToBoxAdapter(
                          child: _buildDateHeader(
                            dateKeys[i],
                            grouped[dateKeys[i]]!,
                          ),
                        ),
                        // 해당 날짜의 거래 목록
                        SliverPadding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final transaction =
                                    grouped[dateKeys[i]]![index];
                                final category = Category.findByName(
                                    transaction.category);

                                return TransactionListItem(
                                  emoji: category.emoji,
                                  title: transaction.description,
                                  subtitle:
                                      '${transaction.category} • ${Formatters.time(transaction.date)}${transaction.storeName != null && transaction.storeName!.isNotEmpty ? ' • ${transaction.storeName}' : ''}',
                                  amount: Formatters.currency(
                                      transaction.amount),
                                  isIncome: transaction.isIncome,
                                  onTap: () {
                                    _showTransactionDetails(
                                        context, transaction);
                                  },
                                  onLongPress: () {
                                    _showTransactionMenu(
                                        context, transaction);
                                  },
                                );
                              },
                              childCount: grouped[dateKeys[i]]!.length,
                            ),
                          ),
                        ),
                      ],

                      // 하단 여백
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 24),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      '데이터를 불러올 수 없습니다',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 요약 카드
  Widget _buildSummaryRow({
    required int totalCount,
    required double totalIncome,
    required double totalExpense,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              '총 ${totalCount}건',
              Icons.receipt_long,
              Colors.white70,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.white.withOpacity(0.3),
          ),
          Expanded(
            child: _buildSummaryItem(
              '+${Formatters.currency(totalIncome)}',
              Icons.arrow_downward,
              Colors.greenAccent,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.white.withOpacity(0.3),
          ),
          Expanded(
            child: _buildSummaryItem(
              '-${Formatters.currency(totalExpense)}',
              Icons.arrow_upward,
              Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String text, IconData icon, Color iconColor) {
    return Column(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 날짜 헤더
  Widget _buildDateHeader(
      String dateStr, List<TransactionModel> transactions) {
    final dayTotal = transactions.fold<double>(0.0, (sum, t) {
      return sum + (t.isIncome ? t.amount : -t.amount);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey[400],
            ),
          ),
          Text(
            '${dayTotal >= 0 ? '+' : ''}${Formatters.currency(dayTotal.abs())}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: dayTotal >= 0 ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 거래 상세/메뉴 (HomeScreen과 동일 로직)
  // =========================================================================

  void _showTransactionMenu(
      BuildContext context, TransactionModel transaction) {
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
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
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.info_outline, color: Colors.blue),
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
                  child: const Icon(Icons.edit_outlined,
                      color: Colors.orange),
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
                  child: const Icon(Icons.delete_outline,
                      color: Colors.red),
                ),
                title:
                    const Text('삭제', style: TextStyle(color: Colors.red)),
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

  void _showTransactionDetails(
      BuildContext context, TransactionModel transaction) {
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
              if (!kIsWeb) _buildReceiptImageWithServer(context, transaction),
              _buildDetailRow('설명', transaction.description),
              _buildDetailRow('금액',
                  '${transaction.isIncome ? '+' : '-'}${Formatters.currency(transaction.amount)}'),
              _buildDetailRow('카테고리', transaction.category),
              _buildDetailRow('날짜', Formatters.date(transaction.date)),
              _buildDetailRow('시간', Formatters.time(transaction.date)),
              if (transaction.storeName != null &&
                  transaction.storeName!.isNotEmpty)
                _buildDetailRow('상점명', transaction.storeName!),
              _buildDetailRow(
                  '유형', transaction.isIncome ? '수입' : '지출'),
              _buildDetailRow(
                  '동기화', transaction.isSynced ? '완료' : '대기중'),
              _buildDetailRow(
                  '생성일', Formatters.date(transaction.createdAt)),
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

  Widget _buildReceiptImageWithServer(
      BuildContext context, TransactionModel transaction) {
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

        return _buildReceiptImageSection(context, imagePath);
      },
    );
  }

  Widget _buildReceiptImageSection(BuildContext context, String imagePath) {
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
          onTap: () => _showFullScreenImage(context, imagePath),
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
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
                        color: Colors.black.withOpacity(0.6),
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

  void _showFullScreenImage(BuildContext context, String imagePath) {
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
              child:
                  Image.file(File(imagePath), fit: BoxFit.contain),
            ),
          ),
        ),
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

  void _showEditDialog(
      BuildContext context, TransactionModel transaction) {
    final descController =
        TextEditingController(text: transaction.description);
    final amountController =
        TextEditingController(text: transaction.amount.toStringAsFixed(0));
    final storeController =
        TextEditingController(text: transaction.storeName ?? '');
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
                  updatedAt: DateTime.now(),
                  isSynced: false,
                );

                final repository =
                    ref.read(transactionRepositoryProvider);
                await repository
                    .updateTransaction(updatedTransaction);

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

  void _showDeleteConfirmation(
      BuildContext context, TransactionModel transaction) {
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w500),
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
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
              final repository =
                  ref.read(transactionRepositoryProvider);
              await repository.deleteTransaction(transaction.id);

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
}
