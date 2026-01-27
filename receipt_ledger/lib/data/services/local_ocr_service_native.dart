import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/receipt.dart';

/// 네이티브 플랫폼용 로컬 OCR 서비스 (Stub)
/// 현재는 서버 OCR을 사용하므로, 로컬 LLM 의존성을 제거하여 iOS 빌드 오류를 방지함.
class LocalOcrServiceImpl {
  bool _isLoaded = false;
  bool _isLoading = false;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  Future<void> initialize(String modelPath, String mmprojPath) async {
    debugPrint('[LocalOCR] Native local OCR is disabled in this build.');
    // Do nothing intended.
  }

  Future<ReceiptData> parseReceiptFromBytes(Uint8List imageBytes) async {
    throw UnimplementedError('Local on-device OCR is currently disabled. Please use Server Sync.');
  }

  void dispose() {}
}
