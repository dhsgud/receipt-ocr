import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../budget/budget_management_screen.dart';
import 'fixed_expense_screen.dart';
import '../statistics/spending_analysis_screen.dart';

class CategoryDashboardScreen extends ConsumerStatefulWidget {
  const CategoryDashboardScreen({super.key});

  @override
  ConsumerState<CategoryDashboardScreen> createState() => _CategoryDashboardScreenState();
}

class _CategoryDashboardScreenState extends ConsumerState<CategoryDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리 및 예산 관리'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '예산'), // Budget
            Tab(text: '고정비'), // Fixed Expenses
            Tab(text: '분석'), // Analysis
          ],
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontSize: 16),
          indicatorWeight: 3,
          labelPadding: EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BudgetManagementView(),   // Refactored to view
          FixedExpenseView(),       // Refactored to view
          SpendingAnalysisView(),   // Refactored to view
        ],
      ),
    );
  }
}
