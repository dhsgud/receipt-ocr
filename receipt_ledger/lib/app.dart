import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/app_providers.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/services/notification_monitor_service.dart';
import 'features/home/home_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/receipt/receipt_screen.dart';
import 'features/statistics/statistics_screen.dart';
import 'features/settings/settings_screen.dart';


class ReceiptLedgerApp extends ConsumerWidget {
  const ReceiptLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Receipt Ledger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isSyncing = false;
  NotificationMonitorService? _notificationService;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarScreen(),
    const ReceiptScreen(),
    const StatisticsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Auto-sync on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performAutoSync();
      _initNotificationMonitoring();
    });
  }
  
  @override
  void dispose() {
    _notificationService?.dispose();
    super.dispose();
  }

  /// Initialize notification monitoring if enabled
  Future<void> _initNotificationMonitoring() async {
    // Only available on mobile
    if (kIsWeb) return;
    
    final repository = ref.read(transactionRepositoryProvider);
    _notificationService = NotificationMonitorService(repository);
    
    // Set callback to refresh data when new transaction is registered
    _notificationService!.onTransactionRegistered = () {
      ref.invalidate(transactionsProvider);
      ref.invalidate(selectedDateTransactionsProvider);
      ref.invalidate(monthlyTransactionsProvider);
      ref.invalidate(monthlyStatsProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💳 결제 알림에서 자동 등록되었습니다'),
            backgroundColor: AppColors.income,
            duration: Duration(seconds: 2),
          ),
        );
      }
    };
    
    // Check if monitoring was enabled previously
    final isEnabled = await _notificationService!.isEnabled();
    if (isEnabled) {
      final hasPermission = await _notificationService!.isPermissionGranted();
      if (hasPermission) {
        await _notificationService!.startMonitoring();
        ref.read(notificationMonitorEnabledProvider.notifier).state = true;
        debugPrint('[App] Notification monitoring started');
      }
    }
  }

  Future<void> _performAutoSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final syncService = ref.read(syncServiceProvider);
      
      // Initialize sync service
      await syncService.initialize();
      
      // Test connection first
      final isConnected = await syncService.testConnection();
      
      if (isConnected) {
        ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
        
        final result = await syncService.syncWithServer();
        
        if (result.success) {
          ref.read(syncStatusProvider.notifier).state = SyncStatus.connected;
          
          // Refresh data providers
          ref.invalidate(transactionsProvider);
          ref.invalidate(selectedDateTransactionsProvider);
          ref.invalidate(monthlyTransactionsProvider);
          ref.invalidate(monthlyStatsProvider);
          
          if (mounted && (result.uploaded > 0 || result.downloaded > 0)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('동기화 완료: ↑${result.uploaded} ↓${result.downloaded}'),
                backgroundColor: AppColors.income,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
        }
      } else {
        ref.read(syncStatusProvider.notifier).state = SyncStatus.disconnected;
      }
    } catch (e) {
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      debugPrint('Auto-sync error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: '캘린더',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_a_photo_outlined),
              selectedIcon: Icon(Icons.add_a_photo),
              label: '영수증',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart),
              label: '통계',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}

