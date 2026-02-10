import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/category.dart';
import '../../shared/providers/app_providers.dart';

/// 고급 소비 분석 화면
/// 고급 소비 분석 화면
class SpendingAnalysisView extends ConsumerStatefulWidget {
  const SpendingAnalysisView({super.key});

  @override
  ConsumerState<SpendingAnalysisView> createState() =>
      _SpendingAnalysisViewState();
}

class _SpendingAnalysisViewState
    extends ConsumerState<SpendingAnalysisView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '월별 트렌드'),
              Tab(text: '전월 비교'),
              Tab(text: '카테고리 분석'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMonthlyTrendTab(),
              _buildComparisonTab(),
              _buildCategoryAnalysisTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 월별 트렌드 탭
  // ============================================================

  Widget _buildMonthlyTrendTab() {
    // 최근 6개월 데이터 (임시)
    final monthlyData = _getMonthlyTrendData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 6개월 지출 추이',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // 바 차트
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxValue(monthlyData) * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        _currencyFormat.format(rod.toY),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < monthlyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthlyData[index].label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _compactCurrency(value),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getMaxValue(monthlyData) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200],
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: monthlyData.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.expense,
                        color: AppColors.expense,
                        width: 24,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 월별 상세 리스트
          const Text(
            '월별 상세',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...monthlyData.reversed.map((data) => _buildMonthlyDetailItem(data)),
        ],
      ),
    );
  }

  Widget _buildMonthlyDetailItem(MonthlyData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  data.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('지출'),
                      Text(
                        _currencyFormat.format(data.expense),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('수입'),
                      Text(
                        _currencyFormat.format(data.income),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 전월 비교 탭
  // ============================================================

  Widget _buildComparisonTab() {
    final now = DateTime.now();
    final thisMonth = '${now.month}월';
    final lastMonth = '${now.month - 1 == 0 ? 12 : now.month - 1}월';

    // 임시 데이터
    const thisMonthExpense = 1500000.0;
    const lastMonthExpense = 1800000.0;
    final diff = thisMonthExpense - lastMonthExpense;
    final diffPercent = (diff / lastMonthExpense * 100).abs();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 비교 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '$thisMonth vs $lastMonth',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompareItem(
                          label: lastMonth,
                          amount: lastMonthExpense,
                          isSelected: false,
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.grey),
                      Expanded(
                        child: _buildCompareItem(
                          label: thisMonth,
                          amount: thisMonthExpense,
                          isSelected: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: diff < 0
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          diff < 0 ? Icons.trending_down : Icons.trending_up,
                          color: diff < 0 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${diff < 0 ? '▼' : '▲'} ${_currencyFormat.format(diff.abs())} (${diffPercent.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: diff < 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 카테고리별 비교
          const Text(
            '카테고리별 변화',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...Category.expenseParentCategories.take(5).map((cat) {
            return _buildCategoryCompareItem(cat, -50000, -10);
          }),
        ],
      ),
    );
  }

  Widget _buildCompareItem({
    required String label,
    required double amount,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCompareItem(Category category, double diff, double percent) {
    final isDecrease = diff < 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(category.emoji, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDecrease
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${isDecrease ? '▼' : '▲'} ${percent.abs().toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDecrease ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 카테고리 분석 탭
  // ============================================================

  Widget _buildCategoryAnalysisTab() {
    final monthlyStats = ref.watch(monthlyStatsProvider);

    return monthlyStats.when(
      data: (stats) {
        if (stats.categoryTotals.isEmpty) {
          return const Center(
            child: Text('데이터가 없습니다'),
          );
        }

        final sortedEntries = stats.categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 파이 차트
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sections: _buildPieChartSections(stats.categoryTotals),
                    centerSpaceRadius: 50,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 카테고리 순위
              const Text(
                '지출 순위',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...sortedEntries.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final categoryName = entry.value.key;
                final amount = entry.value.value;
                final category = Category.findByName(categoryName);
                final percentage = amount / stats.expense * 100;

                return _buildCategoryRankItem(
                  rank: rank,
                  category: category,
                  amount: amount,
                  percentage: percentage,
                );
              }),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('오류가 발생했습니다')),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    Map<String, double> categoryTotals,
  ) {
    final total = categoryTotals.values.fold<double>(0.0, (a, b) => a + b);
    
    return categoryTotals.entries.map((entry) {
      final category = Category.findByName(entry.key);
      final percentage = entry.value / total * 100;

      return PieChartSectionData(
        value: entry.value,
        title: percentage >= 5 ? '${percentage.toStringAsFixed(0)}%' : '',
        color: category.color,
        radius: 45,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildCategoryRankItem({
    required int rank,
    required Category category,
    required double amount,
    required double percentage,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 순위
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? [Colors.amber, Colors.grey[400], Colors.brown[300]][rank - 1]
                    : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 카테고리
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(category.emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            // 정보
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
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(category.color),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 금액
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFormat.format(amount),
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
      ),
    );
  }

  // ============================================================
  // Helper Methods
  // ============================================================

  List<MonthlyData> _getMonthlyTrendData() {
    // TODO: 실제 데이터베이스에서 로드
    final now = DateTime.now();
    return List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index);
      return MonthlyData(
        label: '${month.month}월',
        expense: (1000000 + (index * 200000) + (index % 2 == 0 ? 100000 : -100000)).toDouble(),
        income: (2000000 + (index * 100000)).toDouble(),
      );
    });
  }

  double _getMaxValue(List<MonthlyData> data) {
    if (data.isEmpty) return 1000000;
    return data.map((d) => d.expense).reduce((a, b) => a > b ? a : b);
  }

  String _compactCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(0)}백만';
    } else if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(0)}만';
    }
    return value.toStringAsFixed(0);
  }
}

class MonthlyData {
  final String label;
  final double expense;
  final double income;

  MonthlyData({
    required this.label,
    required this.expense,
    required this.income,
  });
}
