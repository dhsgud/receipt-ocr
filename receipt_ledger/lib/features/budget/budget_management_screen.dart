import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/category.dart';
import '../../data/models/budget.dart';
import '../../shared/providers/app_providers.dart';

/// 예산 관리 화면
class BudgetManagementView extends ConsumerStatefulWidget {
  const BudgetManagementView({super.key});

  @override
  ConsumerState<BudgetManagementView> createState() =>
      _BudgetManagementViewState();
}

class _BudgetManagementViewState
    extends ConsumerState<BudgetManagementView> {
  late int _selectedYear;
  late int _selectedMonth;
  Budget? _currentBudget;
  Map<String, double> _categorySpending = {};
  final _currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final budgetRepo = ref.read(budgetRepositoryProvider);
    final transactionRepo = ref.read(transactionRepositoryProvider);
    final syncService = ref.read(syncServiceProvider);
    
    final budget = await budgetRepo.getBudget(_selectedYear, _selectedMonth);
    final spending = await transactionRepo.getMonthlyCategoryTotals(
      _selectedYear, _selectedMonth,
    );
    
    setState(() {
      _currentBudget = budget ?? Budget.create(
        year: _selectedYear,
        month: _selectedMonth,
        totalBudget: 0,
        ownerKey: syncService.myKey.isEmpty ? 'default' : syncService.myKey,
      );
      _categorySpending = spending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 월 선택 헤더
          _buildMonthHeader(),
          const SizedBox(height: 24),

          // 총 예산 설정
          _buildTotalBudgetCard(),
          const SizedBox(height: 24),

          // 카테고리별 예산 설정
          _buildCategoryBudgetSection(),
        ],
      ),
    );
  }

  /// 월 선택 헤더
  Widget _buildMonthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        GestureDetector(
          onTap: _showMonthPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_selectedYear년 $_selectedMonth월',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  /// 총 예산 카드
  Widget _buildTotalBudgetCard() {
    final totalBudget = _currentBudget?.totalBudget ?? 0;
    final allocatedBudget = _currentBudget?.categoryBudgets.values
            .fold(0.0, (sum, val) => sum + val) ?? 0;
    final remainingBudget = totalBudget - allocatedBudget;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '이번 달 총 예산',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  onPressed: _showSetTotalBudgetDialog,
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: '예산 수정',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _currencyFormat.format(totalBudget),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildBudgetInfoItem(
                    '배정됨',
                    allocatedBudget,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildBudgetInfoItem(
                    '미배정',
                    remainingBudget,
                    remainingBudget < 0 ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
            if (totalBudget > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (allocatedBudget / totalBudget).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                color: allocatedBudget > totalBudget ? Colors.red : AppColors.primary,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetInfoItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 카테고리별 예산 섹션
  Widget _buildCategoryBudgetSection() {
    final parentCategories = Category.expenseParentCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '카테고리별 예산',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...parentCategories.map((category) => _buildCategoryBudgetItem(category)),
      ],
    );
  }

  /// 카테고리 예산 아이템
  Widget _buildCategoryBudgetItem(Category category) {
    final budget = _currentBudget?.getCategoryBudget(category.id) ?? 0;
    final spent = _categorySpending[category.id] ?? 0;
    final percentage = budget > 0 ? (spent / budget * 100) : 0.0;
    final isOverBudget = spent > budget && budget > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showSetCategoryBudgetDialog(category),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (budget > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_currencyFormat.format(spent)} / ${_currencyFormat.format(budget)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOverBudget ? Colors.red : Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (budget > 0)
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isOverBudget ? Colors.red : AppColors.primary,
                      ),
                    )
                  else
                    Text(
                      '+',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey[400],
                      ),
                    ),
                ],
              ),
              if (budget > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (spent / budget).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: isOverBudget ? Colors.red : category.color,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Dialogs
  // ============================================================

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('월 선택'),
        content: SizedBox(
          height: 300,
          width: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelected = month == _selectedMonth;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedMonth = month;
                  });
                  _loadBudget();
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$month월',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedYear--;
                  });
                  Navigator.pop(context);
                  _showMonthPicker();
                },
                child: Text('◀ ${_selectedYear - 1}'),
              ),
              Text('$_selectedYear년'),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedYear++;
                  });
                  Navigator.pop(context);
                  _showMonthPicker();
                },
                child: Text('${_selectedYear + 1} ▶'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSetTotalBudgetDialog() {
    final controller = TextEditingController(
      text: (_currentBudget?.totalBudget ?? 0).toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('총 예산 설정'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '총 예산 금액',
            prefixText: '₩ ',
            hintText: '예: 2000000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              _setTotalBudget(amount);
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showSetCategoryBudgetDialog(Category category) {
    final currentBudget = _currentBudget?.getCategoryBudget(category.id) ?? 0;
    final controller = TextEditingController(
      text: currentBudget > 0 ? currentBudget.toInt().toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(category.emoji),
            const SizedBox(width: 8),
            Text('${category.name} 예산'),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '예산 금액',
            prefixText: '₩ ',
            hintText: '예: 300000',
          ),
        ),
        actions: [
          if (currentBudget > 0)
            TextButton(
              onPressed: () {
                _setCategoryBudget(category.id, 0);
                Navigator.pop(context);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              _setCategoryBudget(category.id, amount);
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Budget Operations
  // ============================================================

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
    _loadBudget();
  }

  void _setTotalBudget(double amount) {
    setState(() {
      _currentBudget = _currentBudget?.copyWith(
        totalBudget: amount,
        updatedAt: DateTime.now(),
      );
    });
    // 로컬 저장소에 저장
    if (_currentBudget != null) {
      ref.read(budgetRepositoryProvider).saveBudget(_currentBudget!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('총 예산이 ${_currencyFormat.format(amount)}으로 설정되었습니다.')),
    );
  }

  void _setCategoryBudget(String categoryId, double amount) {
    setState(() {
      _currentBudget = _currentBudget?.updateCategoryBudget(categoryId, amount);
    });
    // 로컬 저장소에 저장
    if (_currentBudget != null) {
      ref.read(budgetRepositoryProvider).saveBudget(_currentBudget!);
    }
    final category = Category.findById(categoryId);
    if (amount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${category?.name} 예산이 ${_currencyFormat.format(amount)}으로 설정되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${category?.name} 예산이 삭제되었습니다.')),
      );
    }
  }
}
