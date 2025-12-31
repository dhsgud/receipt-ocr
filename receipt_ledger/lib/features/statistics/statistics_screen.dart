import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = ref.watch(currentMonthProvider);
    final monthlyStats = ref.watch(monthlyStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('통계'),
        actions: [
          IconButton(
            onPressed: () {
              // Previous month
              ref.read(currentMonthProvider.notifier).state = DateTime(
                currentMonth.year,
                currentMonth.month - 1,
              );
            },
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton(
            onPressed: () {},
            child: Text(
              Formatters.month(currentMonth),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () {
              // Next month
              ref.read(currentMonthProvider.notifier).state = DateTime(
                currentMonth.year,
                currentMonth.month + 1,
              );
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: monthlyStats.when(
        data: (stats) => _buildContent(context, stats),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('오류가 발생했습니다')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, MonthlyStats stats) {
    if (stats.expense == 0 && stats.income == 0) {
      return const EmptyState(
        icon: Icons.pie_chart_outline,
        title: '데이터가 없습니다',
        subtitle: '이번 달 거래 내역을 추가해주세요',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: '수입',
                  value: Formatters.currency(stats.income),
                  valueColor: AppColors.income,
                  icon: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: '지출',
                  value: Formatters.currency(stats.expense),
                  valueColor: AppColors.expense,
                  icon: Icons.arrow_upward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatCard(
            label: '잔액',
            value: Formatters.currency(stats.balance),
            valueColor: stats.balance >= 0 ? AppColors.income : AppColors.expense,
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 32),

          // Pie Chart
          if (stats.categoryTotals.isNotEmpty) ...[
            const Text(
              '카테고리별 지출',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: _buildPieChartSections(stats.categoryTotals),
                  centerSpaceRadius: 60,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category List
            ...stats.categoryTotals.entries.map((entry) {
              final category = Category.findByName(entry.key);
              final percentage = entry.value / stats.expense * 100;
              return _buildCategoryItem(
                category,
                entry.value,
                percentage,
              );
            }),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    Map<String, double> categoryTotals,
  ) {
    final total = categoryTotals.values.fold<double>(0.0, (double a, double b) => a + b);
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.map((entry) {
      final category = Category.findByName(entry.key);
      final percentage = entry.value / total * 100;

      return PieChartSectionData(
        value: entry.value,
        title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
        color: category.color,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildCategoryItem(Category category, double amount, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(category.emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(category.color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.currency(amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
