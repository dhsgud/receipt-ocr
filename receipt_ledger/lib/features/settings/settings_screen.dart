import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

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
  bool _isServerRunning = false;
  final _partnerKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeSync();
  }

  @override
  void dispose() {
    _partnerKeyController.dispose();
    super.dispose();
  }

  Future<void> _initializeSync() async {
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.initialize();
      
      final qrData = await syncService.generateQrData();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _myQrData = qrData;
          _myKey = syncService.myKey;
          _partnerKey = syncService.partnerKey;
          _isServerRunning = syncService.isServerRunning;
        });
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

  Future<void> _toggleServer() async {
    final syncService = ref.read(syncServiceProvider);
    
    if (_isServerRunning) {
      await syncService.stopServer();
    } else {
      await syncService.startServer();
    }
    
    setState(() {
      _isServerRunning = syncService.isServerRunning;
    });
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
    await syncService.setPartner(key, 'manual');
    
    setState(() {
      _partnerKey = key;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('파트너 연결 완료!'),
          backgroundColor: AppColors.income,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _syncNow() async {
    final syncService = ref.read(syncServiceProvider);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('동기화 중...')),
    );

    final success = await syncService.syncWithPartner();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '동기화 완료!' : '동기화 실패'),
          backgroundColor: success ? AppColors.income : AppColors.expense,
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
              padding: const EdgeInsets.all(20),
              children: [
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
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Sync Section
                const Text(
                  '공유 설정',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
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
                                '연결됨: ${_partnerKey!.substring(0, 8)}...',
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
                const SizedBox(height: 12),

                // Sync Server
                StyledCard(
                  child: Row(
                    children: [
                      Icon(
                        _isServerRunning ? Icons.sync : Icons.sync_disabled,
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
                              _isServerRunning ? '실행 중' : '중지됨',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isServerRunning
                                    ? AppColors.income
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _isServerRunning,
                        onChanged: (_) => _toggleServer(),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Sync Now Button
                if (_partnerKey != null)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _syncNow,
                      icon: const Icon(Icons.sync, color: Colors.white),
                      label: const Text(
                        '지금 동기화',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
                      _buildInfoRow('버전', '1.0.0'),
                      const Divider(height: 24),
                      _buildInfoRow('개발자', 'Receipt Ledger Team'),
                      const Divider(height: 24),
                      _buildInfoRow('플랫폼', kIsWeb ? 'Web' : 'Mobile'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('파트너 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '파트너의 공유 키를 입력하세요',
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
}
