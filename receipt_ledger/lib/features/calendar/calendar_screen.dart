import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/transaction_dialogs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

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
      extendBody: true,
      appBar: AppBar(
        title: const Text('캘린더'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.today, color: AppColors.primary, size: 20),
              ),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime.now();
                });
                ref.read(selectedDateProvider.notifier).state = DateTime.now();
                ref.read(currentMonthProvider.notifier).state = DateTime.now();
              },
              tooltip: '오늘로 이동',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar Section with Glassmorphism
          Container(
            margin: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: isDarkMode 
                    ? Colors.white.withValues(alpha: 0.1) 
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              rowHeight: 70, // Increased height for text markers
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
              // Header Styling
              headerStyle: HeaderStyle(
                formatButtonVisible: false, // Hide format button for cleaner look
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                leftChevronIcon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_left, size: 20),
                ),
                rightChevronIcon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right, size: 20),
                ),
              ),
              // Calendar Style
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  color: isDarkMode ? Colors.red[300] : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
                defaultTextStyle: const TextStyle(fontWeight: FontWeight.w500),
                // Selected Day
                selectedDecoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF818CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                // Today
                todayDecoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                todayTextStyle: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Custom Markers
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final day = DateTime(date.year, date.month, date.day);
                  final expense = dailyExpense[day];
                  final income = dailyIncome[day];
                  
                  if ((expense == null || expense == 0) && (income == null || income == 0)) {
                    return null;
                  }

                  return Positioned(
                    bottom: 4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (income != null && income > 0)
                          _buildAmountMarker(context, income, AppColors.income),
                        if (expense != null && expense > 0) ...[
                          if (income != null && income > 0) const SizedBox(height: 2),
                          _buildAmountMarker(context, expense, AppColors.expense),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Selected Date Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Formatters.dateKorean(selectedDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getDayOfWeek(selectedDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Daily Summary
                selectedDateTransactions.when(
                  data: (transactions) {
                    final expense = transactions
                        .where((t) => !t.isIncome)
                        .fold(0.0, (sum, t) => sum + t.amount);
                    final income = transactions
                        .where((t) => t.isIncome)
                        .fold(0.0, (sum, t) => sum + t.amount);
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (income > 0)
                          Text(
                            '+ ${Formatters.currency(income)}',
                            style: const TextStyle(
                              color: AppColors.income,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        if (expense > 0)
                          Text(
                            '- ${Formatters.currency(expense)}',
                            style: const TextStyle(
                              color: AppColors.expense,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        if (income == 0 && expense == 0)
                          Text(
                            '내역 없음',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Transactions List
          Expanded(
            child: selectedDateTransactions.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_note,
                    title: '거래 내역이 없습니다',
                    subtitle: '이 날짜에 새로운 거래를 추가해보세요',
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    top: AppSpacing.md,
                    bottom: 100, // Bottom padding for FAB/BottomBar
                  ),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final category = Category.findByName(transaction.category);

                    return Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.xs),
                      child: TransactionListItem(
                        emoji: category.emoji,
                        title: transaction.description,
                        subtitle: transaction.category,
                        amount: Formatters.currency(transaction.amount),
                        isIncome: transaction.isIncome,
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
                      ),
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

  Widget _buildAmountMarker(BuildContext context, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Text(
        Formatters.compactCurrency(amount),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getDayOfWeek(DateTime date) {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${weekdays[date.weekday - 1]}요일';
  }
}
