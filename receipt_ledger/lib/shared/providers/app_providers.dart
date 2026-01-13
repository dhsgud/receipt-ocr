import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/services/sllm_service.dart';
import '../../data/services/sync_service.dart';
import '../../data/models/transaction.dart';

/// Transaction repository provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

/// SLLM service provider
final sllmServiceProvider = Provider<SllmService>((ref) {
  return SllmService();
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return SyncService(repository);
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

/// Monthly statistics
final monthlyStatsProvider = FutureProvider<MonthlyStats>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final currentMonth = ref.watch(currentMonthProvider);
  
  final income = await repository.getMonthlyIncome(
    currentMonth.year,
    currentMonth.month,
  );
  final expense = await repository.getMonthlyExpense(
    currentMonth.year,
    currentMonth.month,
  );
  final categoryTotals = await repository.getMonthlyCategoryTotals(
    currentMonth.year,
    currentMonth.month,
  );
  
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

/// OCR 모드 설정
enum OcrMode {
  server,  // 항상 서버 OCR 사용
  local,   // 항상 로컬 OCR 사용 (모델 로드 필요)
  auto,    // 로컬 모델이 로드되어 있으면 로컬, 아니면 서버
}

/// OCR 모드 provider (기본값: auto)
final ocrModeProvider = StateProvider<OcrMode>((ref) {
  return OcrMode.auto;
});
