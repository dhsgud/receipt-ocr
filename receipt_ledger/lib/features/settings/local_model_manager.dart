import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/services/local_ocr_service.dart';

// 모델 정보 상수 (SmolVLM-500M-Instruct - 작고 빠른 비전 모델, llama.cpp 공식 지원)
const String kModelUrl = "https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/SmolVLM-500M-Instruct-Q8_0.gguf";
const String kMmprojUrl = "https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf";

const String kModelFileName = "SmolVLM-500M-Instruct-Q8_0.gguf";
const String kMmprojFileName = "mmproj-SmolVLM-500M-Instruct-Q8_0.gguf";

// 상태 클래스
class ModelDownloadState {
  final bool isDownloading;
  final double progress; // 0.0 ~ 1.0 (average of all files)
  final String? error;
  final bool isModelReady;      // 모델 파일 존재 여부
  final bool isModelLoaded;     // 모델이 메모리에 로드됨
  final bool isModelLoading;    // 모델 로딩 중

  ModelDownloadState({
    this.isDownloading = false,
    this.progress = 0.0,
    this.error,
    this.isModelReady = false,
    this.isModelLoaded = false,
    this.isModelLoading = false,
  });

  ModelDownloadState copyWith({
    bool? isDownloading,
    double? progress,
    String? error,
    bool? isModelReady,
    bool? isModelLoaded,
    bool? isModelLoading,
  }) {
    return ModelDownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      error: error, // null로 초기화 가능
      isModelReady: isModelReady ?? this.isModelReady,
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
      isModelLoading: isModelLoading ?? this.isModelLoading,
    );
  }
}

// Provider
final localModelManagerProvider = StateNotifierProvider<LocalModelManager, ModelDownloadState>((ref) {
  return LocalModelManager();
});

class LocalModelManager extends StateNotifier<ModelDownloadState> {
  LocalModelManager() : super(ModelDownloadState()) {
    _checkModelExists();
  }

  // LocalOcrService 인스턴스
  final LocalOcrService _localOcrService = LocalOcrService();
  
  // LocalOcrService getter
  LocalOcrService get localOcrService => _localOcrService;

  Future<String> _getModelDir() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDocDir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  Future<void> _checkModelExists() async {
    final dirPath = await _getModelDir();
    final modelFile = File('$dirPath/$kModelFileName');
    final mmprojFile = File('$dirPath/$kMmprojFileName');

    if (await modelFile.exists() && await mmprojFile.exists()) {
      state = state.copyWith(isModelReady: true, progress: 1.0);
    } else {
      state = state.copyWith(isModelReady: false, progress: 0.0);
    }
  }

  /// 모델 파일 경로 반환 [modelPath, mmprojPath]
  Future<List<String>> getFilePaths() async {
    final dirPath = await _getModelDir();
    return [
      '$dirPath/$kModelFileName',
      '$dirPath/$kMmprojFileName',
    ];
  }

  /// 모델 다운로드
  Future<void> downloadModels() async {
    if (state.isDownloading) return;

    state = state.copyWith(isDownloading: true, error: null, progress: 0.0);
    final dio = Dio();
    final dirPath = await _getModelDir();

    try {
      // 1. Main Model Download
      await dio.download(
        kModelUrl,
        '$dirPath/$kModelFileName',
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Main model is approx 85% of total size usually 
            // but let's just do sequential progress for simplicity: 0~0.8 for main, 0.8~1.0 for mmproj
            final p = (received / total) * 0.8;
            state = state.copyWith(progress: p);
          }
        },
      );

      // 2. Mmproj Download
      await dio.download(
        kMmprojUrl,
        '$dirPath/$kMmprojFileName',
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final p = 0.8 + (received / total) * 0.2;
            state = state.copyWith(progress: p);
          }
        },
      );

      state = state.copyWith(isDownloading: false, isModelReady: true, progress: 1.0);
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        error: "Download failed: ${e.toString()}",
        isModelReady: false,
      );
    }
  }

  /// 모델을 메모리에 로드 (OCR 추론 준비)
  Future<void> loadModel() async {
    if (state.isModelLoading || state.isModelLoaded) return;
    if (!state.isModelReady) {
      throw Exception('Model not downloaded yet');
    }

    state = state.copyWith(isModelLoading: true, error: null);

    try {
      final paths = await getFilePaths();
      final modelPath = paths[0];
      final mmprojPath = paths[1];

      await _localOcrService.initialize(modelPath, mmprojPath);

      state = state.copyWith(isModelLoading: false, isModelLoaded: true);
    } catch (e) {
      state = state.copyWith(
        isModelLoading: false,
        isModelLoaded: false,
        error: "Model load failed: ${e.toString()}",
      );
      rethrow;
    }
  }

  /// 모델 언로드 (메모리 해제)
  void unloadModel() {
    _localOcrService.dispose();
    state = state.copyWith(isModelLoaded: false);
  }

  /// 모델 파일 삭제
  Future<void> deleteModels() async {
    // 먼저 메모리에서 언로드
    unloadModel();

    final dirPath = await _getModelDir();
    final modelFile = File('$dirPath/$kModelFileName');
    final mmprojFile = File('$dirPath/$kMmprojFileName');
    
    if (await modelFile.exists()) await modelFile.delete();
    if (await mmprojFile.exists()) await mmprojFile.delete();
    
    _checkModelExists();
  }

  @override
  void dispose() {
    _localOcrService.dispose();
    super.dispose();
  }
}
