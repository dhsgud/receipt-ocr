import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import 'local_model_manager.dart';

/// 관리자 전용 설정 화면
/// 
/// OCR 모델, 모드, 서버 URL 등 개발/테스트용 설정을 관리합니다.
/// 프로덕션 빌드에서는 [kAdminMode]를 false로 설정하여 숨깁니다.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _externalLlamaUrlController = TextEditingController();
  final _ocrServerUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 현재 URL 값으로 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _externalLlamaUrlController.text = ref.read(externalLlamaUrlProvider);
      _ocrServerUrlController.text = ref.read(ocrServerUrlProvider);
    });
  }

  @override
  void dispose() {
    _externalLlamaUrlController.dispose();
    _ocrServerUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ocrMode = ref.watch(ocrModeProvider);
    final modelState = ref.watch(localModelManagerProvider);
    final manager = ref.read(localModelManagerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('개발자 설정'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Warning Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ 개발자 전용 설정입니다.\n앱 출시 시 이 페이지는 숨겨집니다.',
                    style: TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // OCR Model Section
          const Text(
            'OCR 모델 (오프라인)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          _buildModelManagerCard(modelState, manager),
          const SizedBox(height: 24),

          // OCR Mode Section
          const Text(
            'OCR 모드',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          StyledCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOcrModeRadio(ocrMode, OcrMode.auto, '자동', Icons.auto_mode,
                    '로컬 > 외부 서버 > OCR 서버 순'),
                _buildOcrModeRadio(ocrMode, OcrMode.externalLlama, '외부 llama.cpp',
                    Icons.dns, '라즈베리파이 등 외부 서버'),
                _buildOcrModeRadio(ocrMode, OcrMode.server, 'OCR 서버',
                    Icons.cloud, 'Python FastAPI OCR'),
                if (!kIsWeb)
                  _buildOcrModeRadio(ocrMode, OcrMode.local, '로컬 디바이스',
                      Icons.phone_android, '오프라인 (모델 로드 필요)'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // OCR Provider (when server mode)
          if (ocrMode == OcrMode.server) ...[
            const Text(
              'OCR 엔진 (Python Server)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            StyledCard(
              child: Consumer(
                builder: (context, ref, _) {
                  final provider = ref.watch(ocrProviderProvider);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: provider,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'auto',
                              child: Text('🤖 Hybrid (Local + Gemini)')),
                          DropdownMenuItem(
                              value: 'gemini',
                              child: Text('✨ Gemini Only (Fast)')),
                          DropdownMenuItem(
                              value: 'gpt', child: Text('🧠 GPT-4o (OpenAI)')),
                          DropdownMenuItem(
                              value: 'claude',
                              child: Text('🎭 Claude 3.5 Sonnet')),
                          DropdownMenuItem(
                              value: 'grok', child: Text('🌌 Grok (xAI)')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(ocrProviderProvider.notifier).state = value;
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '* Hybrid: 로컬로 텍스트 추출 후 Gemini로 정리\n* 그 외: 클라우드 Vision API 직접 호출',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Server URLs
          const Text(
            '서버 URL 설정',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          StyledCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('외부 llama.cpp 서버 URL',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: _externalLlamaUrlController,
                  decoration: InputDecoration(
                    hintText: 'http://192.168.x.x:408',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save, size: 20),
                      onPressed: () {
                        ref.read(externalLlamaUrlProvider.notifier).state =
                            _externalLlamaUrlController.text.trim();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL 저장됨')),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('OCR 서버 URL',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: _ocrServerUrlController,
                  decoration: InputDecoration(
                    hintText: 'http://192.168.x.x:9999',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save, size: 20),
                      onPressed: () {
                        ref.read(ocrServerUrlProvider.notifier).state =
                            _ocrServerUrlController.text.trim();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL 저장됨')),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Current Status
          const Text(
            '현재 상태',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          StyledCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow('OCR 모드', ocrMode.name),
                const Divider(height: 16),
                _buildStatusRow(
                    'OCR 엔진', ref.watch(ocrProviderProvider)),
                const Divider(height: 16),
                _buildStatusRow(
                    '모델 상태',
                    modelState.isModelLoaded
                        ? '로드됨'
                        : modelState.isModelReady
                            ? '다운로드됨'
                            : '미설치'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelManagerCard(
      ModelDownloadState modelState, LocalModelManager manager) {
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
                      icon:
                          const Icon(Icons.play_circle, color: AppColors.income),
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
          if (modelState.isDownloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: modelState.progress,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              '다운로드 중... ${(modelState.progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (modelState.error != null) ...[
            const SizedBox(height: 12),
            Text(
              '오류: ${modelState.error}',
              style: const TextStyle(fontSize: 12, color: AppColors.expense),
            ),
          ],
        ],
      ),
    );
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

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _loadModel(LocalModelManager manager) async {
    try {
      await manager.loadModel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모델 로드 완료!'),
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
        content: const Text('다운로드한 모델 파일을 삭제하시겠습니까?'),
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
            child:
                const Text('삭제', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}
