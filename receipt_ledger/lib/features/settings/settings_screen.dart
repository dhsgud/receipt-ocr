import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import 'local_model_manager.dart';
import 'calendar_settings_screen.dart';

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
      
      final qrData = syncService.generateQrData();
      final isConnected = await syncService.testConnection();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _myQrData = qrData;
          _myKey = syncService.myKey;
          _partnerKey = syncService.partnerKey;
          _isServerConnected = isConnected;
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
                        activeTrackColor: AppColors.primary,
                      ),
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

                // Sync Now Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isServerConnected && !_isSyncing ? _syncNow : null,
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
                      _isSyncing ? '동기화 중...' : '지금 동기화',
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
                // OCR Model Section
                const Text(
                  'OCR 모델 설정 (실험실)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                _buildModelManagerCard(),
                
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

  Widget _buildModelManagerCard() {
    final modelState = ref.watch(localModelManagerProvider);
    final manager = ref.read(localModelManagerProvider.notifier);
    final ocrMode = ref.watch(ocrModeProvider);

    // 상태 텍스트 결정
    String statusText;
    Color statusColor;
    if (modelState.isModelLoaded) {
      statusText = '로드됨 (사용 준비 완료)';
      statusColor = AppColors.income;
    } else if (modelState.isModelLoading) {
      statusText = '모델 로딩 중...';
      statusColor = AppColors.primary;
    } else if (modelState.isModelReady) {
      statusText = '다운로드됨 (로드 필요)';
      statusColor = Colors.orange;
    } else {
      statusText = '다운로드 필요';
      statusColor = Colors.grey;
    }

    return StyledCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 모델 상태 헤더
          Row(
            children: [
              const Icon(Icons.download_for_offline, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오프라인 OCR 모델 (2.5GB)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                  ],
                ),
              ),
              // 액션 버튼
              if (modelState.isDownloading || modelState.isModelLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (modelState.isModelLoaded)
                IconButton(
                  onPressed: manager.unloadModel,
                  icon: const Icon(Icons.stop_circle, color: Colors.orange),
                  tooltip: '모델 언로드',
                )
              else if (modelState.isModelReady)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _loadModel(manager),
                      icon: const Icon(Icons.play_circle, color: AppColors.income),
                      tooltip: '모델 로드',
                    ),
                    IconButton(
                      onPressed: () => _showDeleteModelDialog(manager),
                      icon: const Icon(Icons.delete, color: AppColors.expense),
                      tooltip: '모델 삭제',
                    ),
                  ],
                )
              else
                IconButton(
                  onPressed: manager.downloadModels,
                  icon: const Icon(Icons.download, color: AppColors.primary),
                  tooltip: '모델 다운로드',
                ),
            ],
          ),
          
          // 다운로드 진행률
          if (modelState.isDownloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: modelState.progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              '다운로드 중... ${(modelState.progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          
          // 오류 메시지
          if (modelState.error != null) ...[
            const SizedBox(height: 12),
            Text(
              '오류: ${modelState.error}',
              style: const TextStyle(fontSize: 12, color: AppColors.expense),
            ),
          ],
          
          // OCR 모드 선택 (항상 표시)
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'OCR 모드',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              _buildOcrModeRadio(
                ocrMode, 
                OcrMode.auto, 
                '자동', 
                Icons.auto_mode,
                '로컬 > 외부 서버 > OCR 서버 순',
              ),
              _buildOcrModeRadio(
                ocrMode, 
                OcrMode.externalLlama, 
                '외부 llama.cpp', 
                Icons.dns,
                '라즈베리파이 등 외부 서버',
              ),
              _buildOcrModeRadio(
                ocrMode, 
                OcrMode.server, 
                'OCR 서버', 
                Icons.cloud,
                'Python FastAPI OCR',
              ),
              if (!kIsWeb)
                _buildOcrModeRadio(
                  ocrMode, 
                  OcrMode.local, 
                  '로컬 디바이스', 
                  Icons.phone_android,
                  '오프라인 (모델 로드 필요)',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getOcrModeDescription(ocrMode, modelState.isModelLoaded),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _getOcrModeDescription(OcrMode mode, bool isModelLoaded) {
    switch (mode) {
      case OcrMode.auto:
        return isModelLoaded 
            ? '현재: 로컬 OCR 사용 중'
            : '현재: 외부 서버 또는 OCR 서버 사용';
      case OcrMode.externalLlama:
        final url = ref.read(externalLlamaUrlProvider);
        return '외부 llama.cpp 서버: $url';
      case OcrMode.server:
        final url = ref.read(ocrServerUrlProvider);
        return 'OCR 서버: $url';
      case OcrMode.local:
        return isModelLoaded 
            ? '로컬 OCR 사용 중 (오프라인 가능)'
            : '⚠️ 먼저 모델을 로드해주세요';
    }
  }

  Widget _buildOcrModeRadio(
    OcrMode currentMode,
    OcrMode value,
    String label,
    IconData icon,
    String description,
  ) {
    return RadioListTile<OcrMode>(
      value: value,
      groupValue: currentMode,
      onChanged: (OcrMode? newValue) {
        if (newValue != null) {
          ref.read(ocrModeProvider.notifier).state = newValue;
        }
      },
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
      subtitle: Text(
        description,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _loadModel(LocalModelManager manager) async {
    try {
      await manager.loadModel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모델 로드 완료! 로컬 OCR을 사용할 수 있습니다.'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('모델 로드 실패: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  void _showDeleteModelDialog(LocalModelManager manager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모델 삭제'),
        content: const Text('다운로드한 모델 파일을 삭제하시겠습니까?\n오프라인 OCR을 사용할 수 없게 됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              manager.deleteModels();
              Navigator.pop(context);
            },
            child: const Text('삭제', style: TextStyle(color: AppColors.expense)),
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
