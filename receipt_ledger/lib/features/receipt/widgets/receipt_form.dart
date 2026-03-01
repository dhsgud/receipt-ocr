import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/category.dart';

class ReceiptForm extends StatefulWidget {
  final TextEditingController amountController;
  final TextEditingController descriptionController;
  final TextEditingController memoController;
  final bool isIncome;
  final DateTime selectedDate;
  final String? selectedCategory;
  final Function(bool) onIncomeChanged;
  final Function(DateTime) onDateChanged;
  final Function(String) onCategoryChanged;
  final VoidCallback onSave;

  const ReceiptForm({
    super.key,
    required this.amountController,
    required this.descriptionController,
    required this.memoController,
    required this.isIncome,
    required this.selectedDate,
    required this.selectedCategory,
    required this.onIncomeChanged,
    required this.onDateChanged,
    required this.onCategoryChanged,
    required this.onSave,
  });

  @override
  State<ReceiptForm> createState() => _ReceiptFormState();
}

class _ReceiptFormState extends State<ReceiptForm> {
  static const _quickExpenseIds = ['food', 'housing', 'health'];
  static const _quickIncomeIds = ['income_salary'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Income/Expense Toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildToggleButton(
                  label: '지출',
                  isSelected: !widget.isIncome,
                  onTap: () => widget.onIncomeChanged(false),
                  color: AppColors.expense,
                ),
              ),
              Expanded(
                child: _buildToggleButton(
                  label: '수입',
                  isSelected: widget.isIncome,
                  onTap: () => widget.onIncomeChanged(true),
                  color: AppColors.income,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Amount
        TextField(
          controller: widget.amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: '금액',
            prefixText: '₩ ',
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextField(
          controller: widget.descriptionController,
          decoration: InputDecoration(
            labelText: '설명',
            hintText: '거래 내용을 입력하세요',
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Category
        _buildCategorySelector(),
        const SizedBox(height: 16),

        // Memo
        TextField(
          controller: widget.memoController,
          decoration: InputDecoration(
            labelText: '메모',
            hintText: '한줄 메모를 입력하세요 (선택)',
            prefixIcon: const Icon(Icons.sticky_note_2_outlined, color: AppColors.primary),
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          maxLength: 50,
        ),
        const SizedBox(height: 8),

        // Date
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: widget.selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (date != null) {
              widget.onDateChanged(date);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  Formatters.dateKorean(widget.selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Save Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: widget.onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '저장하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    // 지출/수입에 따라 퀵 카테고리 결정
    final List<Category> quickCategories;
    if (widget.isIncome) {
      quickCategories = Category.incomeCategories
          .where((c) => _quickIncomeIds.contains(c.id))
          .toList();
    } else {
      quickCategories = Category.expenseParentCategories
          .where((c) => _quickExpenseIds.contains(c.id))
          .toList();
    }

    // 현재 선택된 카테고리가 퀵 목록에 없으면 표시용으로 추가
    final selectedCat = (widget.isIncome ? Category.incomeCategories : Category.expenseParentCategories)
        .cast<Category?>()
        .firstWhere((c) => c?.name == widget.selectedCategory, orElse: () => null);
    final bool isSelectedInQuick = quickCategories.any((c) => c.name == widget.selectedCategory);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 퀵 카테고리 칩들
        ...quickCategories.map((category) {
          final isSelected = widget.selectedCategory == category.name;
          return GestureDetector(
            onTap: () => widget.onCategoryChanged(category.name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? category.color.withValues(alpha: 0.2) // Updated to withValues
                    : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? category.color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    category.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // 퀵 목록에 없는 카테고리가 선택된 경우 해당 칩 표시
        if (!isSelectedInQuick && selectedCat != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selectedCat.color.withValues(alpha: 0.2), // Updated to withValues
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selectedCat.color, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(selectedCat.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  selectedCat.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

        // 더보기 버튼
        GestureDetector(
          onTap: () => _showCategorySearchSheet(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), // Updated to withValues
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '더보기',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCategorySearchSheet() {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // 지출/수입에 따라 카테고리 목록 결정
            final allCategories = widget.isIncome
                ? Category.incomeCategories
                : Category.expenseParentCategories;

            // 검색 필터링
            final filtered = searchQuery.isEmpty
                ? allCategories
                : allCategories
                    .where((c) =>
                        c.name.contains(searchQuery) ||
                        c.emoji.contains(searchQuery))
                    .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // 핸들 바
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3), // Updated to withValues
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 타이틀
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          widget.isIncome ? '수입 카테고리' : '지출 카테고리',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.withValues(alpha: 0.1), // Updated to withValues
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 검색 바
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      autofocus: false,
                      onChanged: (value) => setSheetState(() => searchQuery = value),
                      decoration: InputDecoration(
                        hintText: '카테고리 검색...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(context).cardTheme.color,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 카테고리 그리드
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 48, color: Colors.grey.withValues(alpha: 0.4)), // Updated
                                const SizedBox(height: 8),
                                const Text('검색 결과가 없습니다', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.1,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final category = filtered[index];
                              final isSelected = widget.selectedCategory == category.name;
                              
                              return GestureDetector(
                                onTap: () {
                                  widget.onCategoryChanged(category.name);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? category.color.withValues(alpha: 0.2)
                                        : Theme.of(context).cardTheme.color,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? category.color : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(category.emoji, style: const TextStyle(fontSize: 28)),
                                      const SizedBox(height: 4),
                                      Text(
                                        category.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
