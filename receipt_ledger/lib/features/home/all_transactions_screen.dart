import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/transaction_dialogs.dart';
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
                    ? Colors.white.withValues(alpha: 0.08)
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
                                final syncService = ref.read(syncServiceProvider);
                                final ownerName = syncService.getOwnerName(transaction.ownerKey);
                                final isMine = syncService.isMyTransaction(transaction.ownerKey);

                                return TransactionListItem(
                                  emoji: category.emoji,
                                  title: transaction.description,
                                  subtitle:
                                      '${transaction.category} • ${Formatters.time(transaction.date)}${transaction.storeName != null && transaction.storeName!.isNotEmpty ? ' • ${transaction.storeName}' : ''}',
                                  amount: Formatters.currency(
                                      transaction.amount),
                                  isIncome: transaction.isIncome,
                                  ownerLabel: syncService.isPaired ? ownerName : null,
                                  isMyTransaction: isMine,
                                  onTap: () {
                                    showTransactionDetailsDialog(
                                      context: context,
                                      ref: ref,
                                      transaction: transaction,
                                    );
                                  },
                                  onLongPress: () {
                                    showTransactionMenu(
                                      context: context,
                                      ref: ref,
                                      transaction: transaction,
                                    );
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
            color: AppColors.primary.withValues(alpha: 0.2),
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
            color: Colors.white.withValues(alpha: 0.3),
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
            color: Colors.white.withValues(alpha: 0.3),
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
}
