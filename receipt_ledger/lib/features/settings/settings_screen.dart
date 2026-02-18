import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/sync_tutorial_overlay.dart';
import '../../data/services/notification_monitor_service.dart';
import 'calendar_settings_screen.dart';
import 'subscription_screen.dart';

import 'category_management_screen.dart';
import 'category_dashboard_screen.dart';
import '../../data/services/purchase_service.dart';
import '../../data/services/quota_service.dart';
import '../../core/entitlements.dart';

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
  final _partnerKeyController = TextEditingController();
  final _partnerNicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeSync();
  }

  @override
  void dispose() {
    _partnerKeyController.dispose();
    _partnerNicknameController.dispose();
    super.dispose();
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
        // Check tutorial status
        final prefs = await SharedPreferences.getInstance();
        if (mounted) {
          setState(() {
            _showSyncTutorial = !(prefs.getBool('sync_tutorial_completed') ?? false);
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing sync: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _myQrData = 'Error';
          _myKey = 'Error loading key';
        });
      }
    }
  }

  void _showNicknameDialog() {
    final controller = TextEditingController(text: _myNickname);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 닉네임 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '파트너에게 보여질 내 이름표를 설정하세요',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: '닉네임',
                hintText: '예: 동한, 지수',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nickname = controller.text.trim();
              if (nickname.isNotEmpty) {
                final syncService = ref.read(syncServiceProvider);
                await syncService.setMyNickname(nickname);
                setState(() {
                  _myNickname = nickname;
                  _myQrData = syncService.generateQrData();
                });
                ref.read(myNicknameProvider.notifier).state = nickname;
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('닉네임이 설정되었습니다'),
                      backgroundColor: AppColors.income,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  Future<void> _manualPairWithPartner() async {
    final key = _partnerKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파트너 키를 입력해주세요')),
      );
      return;
    }

    final syncService = ref.read(syncServiceProvider);
    await syncService.setPartnerKey(key);
    
    // Save partner nickname if provided
    final partnerNickname = _partnerNicknameController.text.trim();
    if (partnerNickname.isNotEmpty) {
      await syncService.setPartnerNickname(partnerNickname);
      ref.read(partnerNicknameProvider.notifier).state = partnerNickname;
    }
    
    setState(() {
      _partnerKey = key;
      _partnerNickname = partnerNickname;
    });

    if (mounted) {
      Navigator.pop(context); // Close dialog first
      
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

      final result = await syncService.fullSync();

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

      // Refresh data after sync
      ref.invalidate(transactionsProvider);
      ref.invalidate(monthlyTransactionsProvider);
      ref.invalidate(monthlyStatsProvider);
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

    // Refresh data
    ref.invalidate(transactionsProvider);
    ref.invalidate(monthlyTransactionsProvider);
    ref.invalidate(monthlyStatsProvider);
  }

  Future<void> _clearPartner() async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.clearPartner();
    
    setState(() {
      _partnerKey = null;
    });
  }

  void _copyKeyToClipboard() {
    Clipboard.setData(ClipboardData(text: _myKey));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('키가 클립보드에 복사되었습니다')),
    );
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
                // Subscription Section
                const Text(
                  '구독',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final subscription = ref.watch(subscriptionProvider);
                    return StyledCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            subscription.isPremium
                                ? Icons.workspace_premium
                                : Icons.star_outline,
                            color: subscription.isPremium
                                ? const Color(0xFF6366F1)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subscription.tier != SubscriptionTier.free ? '프리미엄 구독 중' : '프리미엄 구독',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Builder(
                                  builder: (context) {
                                    final tier = subscription.tier;
                                    if (tier != SubscriptionTier.free) {
                                      return Text(
                                        tier == SubscriptionTier.pro ? 'Pro: 무제한 OCR' : 'Basic: 무제한 OCR',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6366F1),
                                        ),
                                      );
                                    }
                                    final quotaState = ref.watch(quotaProvider);
                                    final remaining = quotaState.getRemainingFreeQuota();
                                    return Text(
                                      '무료 OCR $remaining/${QuotaConfig.freeTotalLimit}회 남음',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
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
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Theme Section
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

                // Category Management Section
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

                // Sync Section
                const Text(
                  '데이터 동기화',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),

                // Sync Tutorial Banner
                if (_showSyncTutorial)
                  SyncTutorialBanner(
                    onDismiss: _dismissSyncTutorial,
                    onSetNickname: _showNicknameDialog,
                    onShowQr: _showMyQrDialog,
                    onSync: _syncNow,
                  ),

                // Server Connection Status
                StyledCard(
                  onTap: _testServerConnection,
                  child: Row(
                    children: [
                      Icon(
                        _isServerConnected ? Icons.cloud_done : Icons.cloud_off,
                        color: _isServerConnected ? AppColors.income : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '동기화 서버',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isServerConnected ? '연결됨' : '연결 안됨 (탭하여 재시도)',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isServerConnected
                                    ? AppColors.income
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isServerConnected)
                        const Icon(Icons.check_circle, color: AppColors.income, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Partner not connected warning
                if (_isServerConnected && _partnerKey == null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '동기화하려면 먼저 파트너를 연결해주세요',
                            style: TextStyle(fontSize: 13, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Sync Now Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isServerConnected && !_isSyncing && _partnerKey != null
                        ? _syncNow
                        : null,
                    icon: _isSyncing 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync, color: Colors.white),
                    label: Text(
                      _isSyncing
                          ? '동기화 중...'
                          : (_partnerKey == null ? '파트너 연결 필요' : '지금 동기화'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Partner Section
                const Text(
                  '파트너 공유',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),

                // My Nickname
                StyledCard(
                  onTap: _showNicknameDialog,
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '내 닉네임',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _myNickname.isNotEmpty ? _myNickname : '탭하여 설정',
                              style: TextStyle(
                                fontSize: 12,
                                color: _myNickname.isNotEmpty
                                    ? AppColors.income
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // My QR Code
                StyledCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '내 QR 코드',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '파트너에게 이 QR을 보여주세요',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showMyQrDialog(),
                            icon: const Icon(
                              Icons.fullscreen,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // My Key (for manual sharing)
                StyledCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.key),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '내 공유 키',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _copyKeyToClipboard,
                            icon: const Icon(
                              Icons.copy,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _myKey.length > 20 
                              ? '${_myKey.substring(0, 20)}...' 
                              : _myKey,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Add Partner (Manual)
                StyledCard(
                  onTap: () => _showAddPartnerDialog(),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '파트너 추가',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_partnerKey != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '연결됨: ${_partnerNickname.isNotEmpty ? _partnerNickname : _partnerKey!.substring(0, 8)}...',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.income,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),

                // Clear Partner Button
                if (_partnerKey != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _clearPartner,
                    icon: const Icon(
                      Icons.link_off,
                      color: AppColors.expense,
                    ),
                    label: const Text(
                      '파트너 연결 해제',
                      style: TextStyle(color: AppColors.expense),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                
                // Calendar Integration Section
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
                
                // Notification Monitoring Section
                const Text(
                  '결제 알림 자동 등록',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                _buildNotificationMonitoringCard(),
                
                const SizedBox(height: 32),

                // Data Management
                const Text(
                  '데이터 관리',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                StyledCard(
                  onTap: () => _showResetDataDialog(),
                  child: const Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '거래 데이터 초기화',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '모든 거래 내역을 삭제합니다',
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

  void _showMyQrDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '내 QR 코드',
          style: TextStyle(color: Colors.black),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_myQrData.isNotEmpty && _myQrData != 'Error')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: _myQrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              )
            else
              const Text('QR 코드를 생성할 수 없습니다'),
            const SizedBox(height: 16),
            Text(
              '키: ${_myKey.length > 12 ? '${_myKey.substring(0, 12)}...' : _myKey}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '파트너에게 이 QR 코드를 보여주거나\n키를 공유하세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _copyKeyToClipboard,
            child: const Text('키 복사'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showAddPartnerDialog() {
    _partnerNicknameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('파트너 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '파트너의 공유 키와 닉네임을 입력하세요',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _partnerKeyController,
              decoration: InputDecoration(
                labelText: '파트너 키',
                hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _partnerNicknameController,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: '파트너 닉네임 (선택)',
                hintText: '예: 지수, 영희',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: _manualPairWithPartner,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('연결', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationMonitoringCard() {
    final isEnabled = ref.watch(notificationMonitorEnabledProvider);
    
    return StyledCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '알림 자동 감지',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEnabled 
                          ? '결제 알림 → 자동 가계부 등록' 
                          : '비활성화됨',
                      style: TextStyle(
                        fontSize: 12,
                        color: isEnabled ? AppColors.income : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (kIsWeb)
                const Text(
                  '모바일 전용',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              else
                Switch.adaptive(
                  value: isEnabled,
                  onChanged: (value) async {
                    if (value) {
                      await _enableNotificationMonitoring();
                    } else {
                      await _disableNotificationMonitoring();
                    }
                  },
                  activeTrackColor: AppColors.primary,
                ),
            ],
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              '지원 앱',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildAppChip('삼성페이'),
                _buildAppChip('카카오페이'),
                _buildAppChip('네이버페이'),
                _buildAppChip('토스'),
                _buildAppChip('카드사 앱'),
                _buildAppChip('은행 앱'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '📌 결제 알림에서 금액, 가게명을 자동 추출하여\n    가계부에 등록합니다.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _enableNotificationMonitoring() async {
    final repository = ref.read(transactionRepositoryProvider);
    final service = NotificationMonitorService(repository);
    
    // Check permission
    final hasPermission = await service.isPermissionGranted();
    
    if (!hasPermission) {
      // Request permission - opens Android settings
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림 접근 권한을 허용해주세요. 설정 화면으로 이동합니다...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      final granted = await service.requestPermission();
      
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('알림 접근 권한이 필요합니다'),
              backgroundColor: AppColors.expense,
            ),
          );
        }
        return;
      }
    }
    
    // Enable monitoring
    await service.setEnabled(true);
    ref.read(notificationMonitorEnabledProvider.notifier).state = true;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알림 모니터링이 활성화되었습니다'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  Future<void> _disableNotificationMonitoring() async {
    final repository = ref.read(transactionRepositoryProvider);
    final service = NotificationMonitorService(repository);
    
    await service.setEnabled(false);
    ref.read(notificationMonitorEnabledProvider.notifier).state = false;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 모니터링이 비활성화되었습니다')),
      );
    }
  }

  Future<void> _showResetDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('데이터 초기화'),
          ],
        ),
        content: const Text(
          '모든 거래 내역이 영구적으로 삭제됩니다.\n\n이 작업은 되돌릴 수 없습니다.\n정말 삭제하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final repository = ref.read(transactionRepositoryProvider);
      await repository.clearAllTransactions();
      
      // Refresh all data providers
      ref.invalidate(transactionsProvider);
      ref.invalidate(selectedDateTransactionsProvider);
      ref.invalidate(monthlyTransactionsProvider);
      ref.invalidate(monthlyStatsProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 거래 내역이 삭제되었습니다'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    }
  }
}

