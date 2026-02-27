import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import 'category_dashboard_screen.dart';
import 'calendar_settings_screen.dart';
import 'widgets/sync_section.dart';
import 'widgets/partner_section.dart';
import 'widgets/notification_section.dart';
import 'widgets/data_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isInitialized = false;
  String _myQrData = '';
  String _myKey = '';
  String? _partnerKey;
  bool _isServerConnected = false;
  bool _isSyncing = false;
  String _myNickname = '';
  String _partnerNickname = '';
  bool _showSyncTutorial = false;

  @override
  void initState() {
    super.initState();
    _initializeSync();
  }

  Future<void> _initializeSync() async {
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.initialize();
      
      final qrData = syncService.generateQrData();
      final isConnected = await syncService.testConnection();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _myQrData = qrData;
          _myKey = syncService.myKey;
          _partnerKey = syncService.partnerKey;
          _isServerConnected = isConnected;
          _myNickname = syncService.myNickname;
          _partnerNickname = syncService.partnerNickname;
        });
        
        final prefs = await SharedPreferences.getInstance();
        if (mounted) {
          setState(() {
            _showSyncTutorial = !(prefs.getBool('sync_tutorial_completed') ?? false);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _myQrData = 'Error';
          _myKey = 'Error loading key';
        });
      }
    }
  }

  Future<void> _dismissSyncTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_tutorial_completed', true);
    setState(() {
      _showSyncTutorial = false;
    });
  }

  Future<void> _testServerConnection() async {
    final syncService = ref.read(syncServiceProvider);
    final isConnected = await syncService.testConnection();
    
    setState(() {
      _isServerConnected = isConnected;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isConnected ? '서버 연결 성공!' : '서버에 연결할 수 없습니다'),
          backgroundColor: isConnected ? AppColors.income : AppColors.expense,
        ),
      );
    }
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
    });

    final syncService = ref.read(syncServiceProvider);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('동기화 중...')),
    );

    final result = await syncService.syncWithServer();
    
    // Refresh data
    ref.invalidate(transactionsProvider);
    ref.invalidate(monthlyTransactionsProvider);
    ref.invalidate(monthlyStatsProvider);

    setState(() {
      _isSyncing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success 
              ? '동기화 완료! (업로드: ${result.uploaded}, 다운로드: ${result.downloaded})'
              : '동기화 실패: ${result.message}'),
          backgroundColor: result.success ? AppColors.income : AppColors.expense,
        ),
      );
    }
  }

  Future<void> _onPartnerLinked(String key, String nickname) async {
    setState(() {
      _partnerKey = key;
      _partnerNickname = nickname;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('파트너 연결 완료! 데이터 동기화를 시작합니다...'),
          backgroundColor: AppColors.income,
        ),
      );

      // Auto-trigger full sync after partner pairing
      setState(() {
        _isSyncing = true;
      });

      final syncService = ref.read(syncServiceProvider);
      final result = await syncService.fullSync();

      // Refresh data
      ref.invalidate(transactionsProvider);
      ref.invalidate(monthlyTransactionsProvider);
      ref.invalidate(monthlyStatsProvider);

      setState(() {
        _isSyncing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success 
                ? '동기화 완료! (업로드: ${result.uploaded}, 다운로드: ${result.downloaded})'
                : '동기화 실패: ${result.message}'),
            backgroundColor: result.success ? AppColors.income : AppColors.expense,
          ),
        );
      }
    }
  }

  void _onPartnerCleared() {
    setState(() {
      _partnerKey = null;
      _partnerNickname = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [

                // Theme
                const Text(
                  '테마',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                StyledCard(
                  child: Row(
                    children: [
                      const Icon(Icons.dark_mode),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '다크 모드',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Switch.adaptive(
                        value: isDarkMode,
                        onChanged: (value) {
                          ref.read(themeModeProvider.notifier).state = value;
                        },
                        activeTrackColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Category & Budget
                const Text(
                  '카테고리 및 예산 관리',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                StyledCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CategoryDashboardScreen(),
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.dashboard_customize, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '통합 관리 대시보드',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '카테고리, 예산, 고정비, 지출 분석',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Sync
                SyncSection(
                  isServerConnected: _isServerConnected,
                  isSyncing: _isSyncing,
                  partnerKey: _partnerKey,
                  showSyncTutorial: _showSyncTutorial,
                  onDismissTutorial: _dismissSyncTutorial,
                  onSync: _syncNow,
                  onTestConnection: _testServerConnection,
                  myNickname: _myNickname,
                  myKey: _myKey,
                  myQrData: _myQrData,
                  onNicknameChanged: (val) {
                    setState(() => _myNickname = val);
                    ref.read(myNicknameProvider.notifier).state = val;
                  },
                ),
                const SizedBox(height: 32),

                // Partner Sharing
                PartnerSection(
                  myNickname: _myNickname,
                  myKey: _myKey,
                  myQrData: _myQrData,
                  partnerKey: _partnerKey,
                  partnerNickname: _partnerNickname,
                  onNicknameChanged: (val) {
                    setState(() => _myNickname = val);
                    // Also update provider just in case
                    ref.read(myNicknameProvider.notifier).state = val;
                  },
                  onPartnerLinked: _onPartnerLinked,
                  onPartnerCleared: _onPartnerCleared,
                ),
                const SizedBox(height: 32),
                
                // Calendar Integration
                const Text(
                  '캘린더 연동',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                StyledCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CalendarSettingsScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '캘린더 동기화 설정',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Consumer(
                              builder: (context, ref, _) {
                                final isEnabled = ref.watch(calendarSyncEnabledProvider);
                                return Text(
                                  isEnabled ? '활성화됨' : '비활성화됨',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isEnabled ? AppColors.income : Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Notification Monitoring
                const NotificationSection(),
                const SizedBox(height: 32),

                // Data Management
                DataManagementSection(
                  onRestoreSuccess: (newKey, newQr) {
                    setState(() {
                      _myKey = newKey;
                      _myQrData = newQr;
                    });
                  },
                  onResetSuccess: () {
                    // Update UI if needed
                    setState(() {});
                  },
                ),
                const SizedBox(height: 32),

                // App Info
                const Text(
                  '앱 정보',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                StyledCard(
                  child: Column(
                    children: [
                      _buildInfoRow('버전', '0.1.0'),
                      const Divider(height: 24),
                      _buildInfoRow('개발자', '김동한'),
                      const Divider(height: 24),
                      _buildInfoRow('문의 사항', 'fastfeelfreeai@gmail.com'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

