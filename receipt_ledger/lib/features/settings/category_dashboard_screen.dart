import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../budget/budget_management_screen.dart';
import 'fixed_expense_screen.dart';

/// 예산 및 고정비 관리 화면
/// 단일 스크롤 화면으로 예산 설정 + 고정비 관리를 간단하게 제공
class CategoryDashboardScreen extends ConsumerWidget {
  const CategoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('예산 및 고정비 관리'),
      ),
      body: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 예산 관리 섹션
            BudgetManagementView(),

            Divider(height: 48, indent: 16, endIndent: 16),

            // 고정비 관리 섹션
            FixedExpenseView(),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
