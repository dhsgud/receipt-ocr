import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/savings_goal.dart';
import '../providers/app_providers.dart';

/// 목표 금액 설정 다이얼로그
void showSavingsGoalDialog({
  required BuildContext context,
  required WidgetRef ref,
  SavingsGoal? existingGoal,
}) {
  final amountController = TextEditingController(
    text: existingGoal != null ? existingGoal.goalAmount.toInt().toString() : '',
  );
  GoalType selectedType = existingGoal?.goalType ?? GoalType.saving;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                existingGoal != null ? '목표 수정' : '목표 설정',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 목표 타입 선택
                Text(
                  '목표 유형',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _GoalTypeChip(
                        label: '💰 저축 목표',
                        isSelected: selectedType == GoalType.saving,
                        onTap: () => setDialogState(() {
                          selectedType = GoalType.saving;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GoalTypeChip(
                        label: '🛒 지출 한도',
                        isSelected: selectedType == GoalType.spendingLimit,
                        onTap: () => setDialogState(() {
                          selectedType = GoalType.spendingLimit;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 금액 입력
                Text(
                  '목표 금액',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    prefixText: '₩ ',
                    prefixStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    hintText: selectedType == GoalType.saving
                        ? '예: 500000'
                        : '예: 1000000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 설명 텍스트
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedType == GoalType.saving
                              ? '수입에서 지출을 뺀 금액이 목표에 도달하면 달성!'
                              : '이번 달 총 지출이 설정 금액 이하이면 달성!',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (existingGoal != null)
              TextButton(
                onPressed: () {
                  final now = DateTime.now();
                  ref.read(savingsGoalRepositoryProvider)
                      .deleteGoal(now.year, now.month);
                  ref.invalidate(currentMonthGoalProvider);
                  ref.invalidate(goalProgressProvider);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('목표가 삭제되었습니다')),
                  );
                },
                child: const Text(
                  '삭제',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('올바른 금액을 입력해주세요')),
                  );
                  return;
                }

                final syncService = ref.read(syncServiceProvider);
                final ownerKey = syncService.myKey.isEmpty
                    ? 'default'
                    : syncService.myKey;
                final now = DateTime.now();

                final goal = SavingsGoal.create(
                  year: now.year,
                  month: now.month,
                  goalAmount: amount,
                  goalType: selectedType,
                  ownerKey: ownerKey,
                );

                ref.read(savingsGoalRepositoryProvider).saveGoal(goal);
                ref.invalidate(currentMonthGoalProvider);
                ref.invalidate(goalProgressProvider);
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '목표가 ${Formatters.currency(amount)}으로 설정되었습니다',
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('저장'),
            ),
          ],
        );
      },
    ),
  );
}

/// 목표 타입 선택 칩
class _GoalTypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalTypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[400]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
