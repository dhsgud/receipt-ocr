import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/fixed_expense_repository.dart';
import '../../data/repositories/savings_goal_repository.dart';
import '../../data/services/sllm_service.dart';
import '../../data/services/sync_service.dart';
import '../../data/models/transaction.dart';
import '../../data/models/savings_goal.dart';

/// 통계 소유자 필터
enum StatsOwnerFilter {
  all,  // 전체 (나 + 파트너)
  mine, // 개인 (나만)
}

/// Transaction repository provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

/// Budget repository provider
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository();
});

/// Fixed expense repository provider
final fixedExpenseRepositoryProvider = Provider<FixedExpenseRepository>((ref) {
  return FixedExpenseRepository();
});

/// Gemini OCR service provider
final sllmServiceProvider = Provider<SllmService>((ref) {
  return SllmService();
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final budgetRepository = ref.watch(budgetRepositoryProvider);
  final fixedExpenseRepository = ref.watch(fixedExpenseRepositoryProvider);
  return SyncService(repository, budgetRepository, fixedExpenseRepository);
});

/// All transactions provider with auto-refresh
final transactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return await repository.getAllTransactions();
});

/// Selected date provider for calendar
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Current month provider for calendar navigation
final currentMonthProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Transactions for selected date
final selectedDateTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  return await repository.getTransactionsByDate(selectedDate);
});

/// Monthly transactions for current view
final monthlyTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final currentMonth = ref.watch(currentMonthProvider);
  return await repository.getTransactionsByMonth(
    currentMonth.year,
    currentMonth.month,
  );
});

/// 통계 소유자 필터 Provider
final statsOwnerFilterProvider = StateProvider<StatsOwnerFilter>((ref) {
  return StatsOwnerFilter.all;
});

/// Monthly statistics (with owner filter)
final monthlyStatsProvider = FutureProvider<MonthlyStats>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final currentMonth = ref.watch(currentMonthProvider);
  final ownerFilter = ref.watch(statsOwnerFilterProvider);
  final syncService = ref.watch(syncServiceProvider);
  
  // Get all transactions for the month
  final allTransactions = await repository.getTransactionsByMonth(
    currentMonth.year,
    currentMonth.month,
  );
  
  // Apply owner filter
  final transactions = ownerFilter == StatsOwnerFilter.mine && syncService.myKey != null
      ? allTransactions.where((t) => t.ownerKey == syncService.myKey).toList()
      : allTransactions;
  
  final income = transactions
      .where((t) => t.isIncome)
      .fold<double>(0.0, (sum, t) => sum + t.amount);
  final expense = transactions
      .where((t) => !t.isIncome)
      .fold<double>(0.0, (sum, t) => sum + t.amount);
  
  final categoryTotals = <String, double>{};
  for (final t in transactions) {
    if (!t.isIncome) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }
  }
  
  return MonthlyStats(
    income: income,
    expense: expense,
    balance: income - expense,
    categoryTotals: categoryTotals,
  );
});

/// Monthly statistics data class
class MonthlyStats {
  final double income;
  final double expense;
  final double balance;
  final Map<String, double> categoryTotals;

  MonthlyStats({
    required this.income,
    required this.expense,
    required this.balance,
    required this.categoryTotals,
  });
}

/// Theme mode provider
final themeModeProvider = StateProvider<bool>((ref) {
  return true; // Default to dark mode
});

/// Sync status provider
final syncStatusProvider = StateProvider<SyncStatus>((ref) {
  return SyncStatus.disconnected;
});

enum SyncStatus {
  disconnected,
  connected,
  syncing,
  error,
}

/// 내 닉네임 Provider
final myNicknameProvider = StateProvider<String>((ref) => '');

/// 파트너 닉네임 Provider
final partnerNicknameProvider = StateProvider<String>((ref) => '');

/// OCR 서버 URL (Gemini 전용)
final ocrServerUrlProvider = StateProvider<String>((ref) {
  return AppConstants.syncServerUrl;
});

/// OCR 제공자 (Gemini 전용)
final ocrProviderProvider = StateProvider<String>((ref) {
  return 'gemini';
});

// ============================================================================
// 캘린더 연동 관련 Providers
// ============================================================================

/// 캘린더 동기화 활성화 여부
final calendarSyncEnabledProvider = StateProvider<bool>((ref) => false);

/// 선택된 캘린더 ID
final selectedCalendarIdProvider = StateProvider<String?>((ref) => null);

// ============================================================================
// 알림 모니터링 관련 Providers
// ============================================================================

/// 알림 모니터링 활성화 여부 (StateProvider로 UI 상태 관리)
final notificationMonitorEnabledProvider = StateProvider<bool>((ref) => false);

// ============================================================================
// 예산 알림 관련 Providers
// ============================================================================

/// 예산 초과 알림 활성화 여부
final budgetAlertEnabledProvider = StateProvider<bool>((ref) => true);

// ============================================================================
// 목표 금액 관련 Providers
// ============================================================================

/// Savings goal repository provider
final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  return SavingsGoalRepository();
});

/// 이번 달 목표 데이터
final currentMonthGoalProvider = FutureProvider<SavingsGoal?>((ref) async {
  final repo = ref.watch(savingsGoalRepositoryProvider);
  final currentMonth = ref.watch(currentMonthProvider);
  return await repo.getGoal(currentMonth.year, currentMonth.month);
});

/// 목표 달성률 데이터
class GoalProgress {
  final SavingsGoal goal;
  final double income;
  final double expense;
  final double progressPercent;
  final bool isAchieved;
  final double currentValue;  // 현재 저축액 or 현재 지출액

  GoalProgress({
    required this.goal,
    required this.income,
    required this.expense,
    required this.progressPercent,
    required this.isAchieved,
    required this.currentValue,
  });
}

/// 목표 프로그레스 Provider
final goalProgressProvider = FutureProvider<GoalProgress?>((ref) async {
  final goal = await ref.watch(currentMonthGoalProvider.future);
  if (goal == null) return null;

  final stats = await ref.watch(monthlyStatsProvider.future);

  final progress = goal.getProgress(
    income: stats.income,
    expense: stats.expense,
  );
  final achieved = goal.isAchieved(
    income: stats.income,
    expense: stats.expense,
  );

  final currentValue = goal.goalType == GoalType.saving
      ? (stats.income - stats.expense)
      : stats.expense;

  return GoalProgress(
    goal: goal,
    income: stats.income,
    expense: stats.expense,
    progressPercent: progress,
    isAchieved: achieved,
    currentValue: currentValue,
  );
});

