import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

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
              // 영수증 이미지 표시 (서버 이미지 지원)
              if (!kIsWeb)
                _buildReceiptImageWithServer(context, transaction),
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

  /// 서버 이미지 지원하는 영수증 이미지 위젯
  Widget _buildReceiptImageWithServer(BuildContext context, TransactionModel transaction) {
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


  /// 영수증 이미지 섹션 빌드
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
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
          ),
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
                  Image.file(
                    file,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '탭하여 확대',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
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

  /// 전체화면 이미지 뷰어
  void _showFullScreenImage(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              '영수증 이미지',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
              ),
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
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedDateTransactions = ref.watch(selectedDateTransactionsProvider);
    final monthlyTransactions = ref.watch(monthlyTransactionsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculate daily totals for markers (수입/지출 분리)
    final dailyExpense = <DateTime, double>{};
    final dailyIncome = <DateTime, double>{};
    monthlyTransactions.whenData((transactions) {
      for (final t in transactions) {
        final day = DateTime(t.date.year, t.date.month, t.date.day);
        if (t.isIncome) {
          dailyIncome[day] = (dailyIncome[day] ?? 0) + t.amount;
        } else {
          dailyExpense[day] = (dailyExpense[day] ?? 0) + t.amount;
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
              });
              ref.read(selectedDateProvider.notifier).state = DateTime.now();
              ref.read(currentMonthProvider.notifier).state = DateTime.now();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(selectedDate, day),
              onDaySelected: (selectedDay, focusedDay) {
                ref.read(selectedDateProvider.notifier).state = selectedDay;
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                ref.read(currentMonthProvider.notifier).state = focusedDay;
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                ),
                titleTextStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.primary,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  color: isDarkMode ? Colors.red[300] : Colors.red,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppColors.expense,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final day = DateTime(date.year, date.month, date.day);
                  final expense = dailyExpense[day];
                  final income = dailyIncome[day];
                  
                  // 수입/지출 모두 없으면 표시 안함
                  if ((expense == null || expense == 0) && (income == null || income == 0)) {
                    return null;
                  }

                  return Positioned(
                    bottom: 1,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 수입 배지 (초록색)
                        if (income != null && income > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            margin: const EdgeInsets.only(right: 1),
                            decoration: BoxDecoration(
                              color: AppColors.income.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '+${_formatShortAmount(income)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        // 지출 배지 (빨간색)
                        if (expense != null && expense > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.expense.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              _formatShortAmount(expense),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Selected Date Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  Formatters.dateKorean(selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                selectedDateTransactions.when(
                  data: (transactions) {
                    final total = transactions
                        .where((t) => !t.isIncome)
                        .fold<double>(0.0, (double sum, t) => sum + t.amount);
                    return Text(
                      '지출 ${Formatters.currency(total)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.expense,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Transactions List
          Expanded(
            child: selectedDateTransactions.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_available,
                    title: '거래 내역이 없습니다',
                    subtitle: '이 날짜에 등록된 거래가 없습니다',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final category = Category.findByName(transaction.category);

                    return TransactionListItem(
                      emoji: category.emoji,
                      title: transaction.description,
                      subtitle: transaction.category,
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
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('오류가 발생했습니다')),
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortAmount(double amount) {
    if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(0)}만';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}천';
    }
    return amount.toStringAsFixed(0);
  }
}

