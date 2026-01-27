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
  externalLlama,  // 외부 llama.cpp 서버 (라즈베리파이 등)
  server,         // 내부 OCR 서버 (Python FastAPI)
  local,          // 로컬 디바이스 (on-device, 모델 로드 필요)
  auto,           // 자동 선택 (로컬 > 외부 > 서버 순)
}

/// OCR 모드 provider (기본값: auto)
final ocrModeProvider = StateProvider<OcrMode>((ref) {
  return OcrMode.server; // Default to our Python Hybrid Server
});

/// 외부 llama.cpp 서버 URL (설정에서 변경 가능)
final externalLlamaUrlProvider = StateProvider<String>((ref) {
  return 'http://183.96.3.137:408';
});

/// 내부 OCR 서버 URL
final ocrServerUrlProvider = StateProvider<String>((ref) {
  return 'http://183.96.3.137:9999';
});

/// OCR 제공자 (Server Mode일 때 사용)
/// 'auto' (Hybrid), 'gemini', 'gpt', 'claude', 'grok'
final ocrProviderProvider = StateProvider<String>((ref) {
  return 'auto'; 
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

