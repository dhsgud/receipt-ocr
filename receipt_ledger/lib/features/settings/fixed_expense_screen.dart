import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/category.dart';
import '../../data/models/fixed_expense.dart';
import '../../shared/providers/app_providers.dart';

/// 고정비 관리 화면
class FixedExpenseView extends ConsumerStatefulWidget {
  const FixedExpenseView({super.key});

  @override
  ConsumerState<FixedExpenseView> createState() => _FixedExpenseViewState();
}

class _FixedExpenseViewState extends ConsumerState<FixedExpenseView> {
  final _currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
  List<FixedExpense> _fixedExpenses = [];

  @override
  void initState() {
    super.initState();
    _loadFixedExpenses();
  }

  Future<void> _loadFixedExpenses() async {
    final repo = ref.read(fixedExpenseRepositoryProvider);
    final expenses = await repo.getAllFixedExpenses();
    setState(() {
      _fixedExpenses = expenses;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalMonthly = _calculateMonthlyTotal();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 월 고정비 총액 카드
        _buildTotalCard(totalMonthly),

        // 고정비 목록 또는 빈 상태
        if (_fixedExpenses.isEmpty)
          _buildEmptyState()
        else
          ..._buildFixedExpenseItems(),

        // 고정비 추가 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddFixedExpenseDialog,
              icon: const Icon(Icons.add),
              label: const Text('고정비 추가'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 월 고정비 총액 계산
  double _calculateMonthlyTotal() {
    return _fixedExpenses
        .where((e) => e.isActive)
        .fold(0.0, (sum, e) {
      switch (e.frequency) {
        case FixedExpenseFrequency.monthly:
          return sum + e.amount;
        case FixedExpenseFrequency.weekly:
          return sum + (e.amount * 4.33); // 평균 4.33주
        case FixedExpenseFrequency.biweekly:
          return sum + (e.amount * 2.17);
        case FixedExpenseFrequency.quarterly:
          return sum + (e.amount / 3);
        case FixedExpenseFrequency.yearly:
          return sum + (e.amount / 12);
      }
    });
  }

  /// 월 고정비 총액 카드
  Widget _buildTotalCard(double total) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '월 고정비 총액',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(total),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_fixedExpenses.where((e) => e.isActive).length}개 항목',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            '등록된 고정비가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '아래 버튼을 눌러 고정비를 추가하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// 고정비 아이템 목록 (Column에 spread 가능)
  List<Widget> _buildFixedExpenseItems() {
    // 결제일 임박 순으로 정렬
    final sorted = List<FixedExpense>.from(_fixedExpenses)
      ..sort((a, b) => a.daysUntilPayment().compareTo(b.daysUntilPayment()));

    return sorted.map((expense) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildFixedExpenseItem(expense),
    )).toList();
  }

  /// 고정비 아이템
  Widget _buildFixedExpenseItem(FixedExpense expense) {
    final category = Category.findById(expense.categoryId);
    final daysUntil = expense.daysUntilPayment();
    final isDueSoon = daysUntil <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEditFixedExpenseDialog(expense),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 카테고리 아이콘
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (category?.color ?? Colors.grey).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    category?.emoji ?? '📦',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: expense.isActive ? null : Colors.grey,
                        decoration: expense.isActive ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${expense.frequency.displayName} ${expense.paymentDay}일',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (expense.autoRecord) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '자동기록',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 금액 및 D-Day
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(expense.amount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDueSoon
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      daysUntil == 0 ? 'D-Day' : 'D-$daysUntil',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDueSoon ? Colors.red : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Dialogs
  // ============================================================

  void _showAddFixedExpenseDialog() {
    _showFixedExpenseForm(null);
  }

  void _showEditFixedExpenseDialog(FixedExpense expense) {
    _showFixedExpenseForm(expense);
  }

  void _showFixedExpenseForm(FixedExpense? existing) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final amountController = TextEditingController(
      text: existing != null ? existing.amount.toInt().toString() : '',
    );
    String selectedCategoryId = existing?.categoryId ?? 'housing';
    int paymentDay = existing?.paymentDay ?? 25;
    FixedExpenseFrequency frequency = existing?.frequency ?? FixedExpenseFrequency.monthly;
    bool autoRecord = existing?.autoRecord ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '고정비 추가' : '고정비 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이름
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    hintText: '예: 월세, 통신비',
                  ),
                ),
                const SizedBox(height: 16),

                // 금액
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '금액',
                    prefixText: '₩ ',
                  ),
                ),
                const SizedBox(height: 16),

                // 카테고리
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: '카테고리',
                  ),
                  items: Category.expenseParentCategories.map((cat) {
                    return DropdownMenuItem(
                      value: cat.id,
                      child: Text('${cat.emoji} ${cat.name}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCategoryId = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 반복 주기
                DropdownButtonFormField<FixedExpenseFrequency>(
                  initialValue: frequency,
                  decoration: const InputDecoration(
                    labelText: '반복 주기',
                  ),
                  items: FixedExpenseFrequency.values.map((freq) {
                    return DropdownMenuItem(
                      value: freq,
                      child: Text(freq.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => frequency = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 결제일
                Row(
                  children: [
                    const Text('결제일: '),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: paymentDay,
                      items: List.generate(31, (index) {
                        final day = index + 1;
                        return DropdownMenuItem(
                          value: day,
                          child: Text('$day일'),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => paymentDay = value);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 자동 기록
                SwitchListTile(
                  title: const Text('자동 기록'),
                  subtitle: const Text('결제일에 자동으로 지출 등록'),
                  value: autoRecord,
                  onChanged: (value) {
                    setDialogState(() => autoRecord = value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () {
                  _deleteFixedExpense(existing);
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
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text) ?? 0;

                if (name.isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이름과 금액을 입력해주세요')),
                  );
                  return;
                }

                if (existing == null) {
                  _addFixedExpense(
                    name: name,
                    amount: amount,
                    categoryId: selectedCategoryId,
                    paymentDay: paymentDay,
                    frequency: frequency,
                    autoRecord: autoRecord,
                  );
                } else {
                  _updateFixedExpense(
                    existing.copyWith(
                      name: name,
                      amount: amount,
                      categoryId: selectedCategoryId,
                      paymentDay: paymentDay,
                      frequency: frequency,
                      autoRecord: autoRecord,
                      updatedAt: DateTime.now(),
                    ),
                  );
                }
                Navigator.pop(context);
              },
              child: Text(existing == null ? '추가' : '저장'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Fixed Expense Operations
  // ============================================================

  Future<void> _addFixedExpense({
    required String name,
    required double amount,
    required String categoryId,
    required int paymentDay,
    required FixedExpenseFrequency frequency,
    required bool autoRecord,
  }) async {
    final syncService = ref.read(syncServiceProvider);
    final expense = FixedExpense.create(
      name: name,
      amount: amount,
      categoryId: categoryId,
      paymentDay: paymentDay,
      frequency: frequency,
      autoRecord: autoRecord,
      ownerKey: syncService.myKey.isEmpty ? 'default' : syncService.myKey,
    );

    setState(() {
      _fixedExpenses.add(expense);
    });

    // 로컬 저장소에 저장
    await ref.read(fixedExpenseRepositoryProvider).saveFixedExpense(expense);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name 고정비가 추가되었습니다.')),
      );
    }
  }

  Future<void> _updateFixedExpense(FixedExpense expense) async {
    setState(() {
      final index = _fixedExpenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _fixedExpenses[index] = expense;
      }
    });

    // 로컬 저장소에 저장
    await ref.read(fixedExpenseRepositoryProvider).saveFixedExpense(expense);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${expense.name} 고정비가 수정되었습니다.')),
      );
    }
  }

  Future<void> _deleteFixedExpense(FixedExpense expense) async {
    setState(() {
      _fixedExpenses.removeWhere((e) => e.id == expense.id);
    });

    // 로컬 저장소에서 삭제
    await ref.read(fixedExpenseRepositoryProvider).deleteFixedExpense(expense.id);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${expense.name} 고정비가 삭제되었습니다.')),
      );
    }
  } 
}
