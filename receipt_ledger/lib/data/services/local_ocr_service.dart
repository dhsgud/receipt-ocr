import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/receipt.dart';

// 웹에서는 llama_cpp_dart 사용 불가 - 조건부 import
// ignore: uri_does_not_exist
import 'local_ocr_service_stub.dart'
    if (dart.library.io) 'local_ocr_service_native.dart' as platform;

/// 로컬 OCR 서비스 (플랫폼별 분기)
class LocalOcrService {
  final platform.LocalOcrServiceImpl _impl = platform.LocalOcrServiceImpl();

  bool get isLoaded => _impl.isLoaded;
  bool get isLoading => _impl.isLoading;

  Future<void> initialize(String modelPath, String mmprojPath) =>
      _impl.initialize(modelPath, mmprojPath);

  Future<ReceiptData> parseReceiptFromBytes(Uint8List imageBytes) =>
      _impl.parseReceiptFromBytes(imageBytes);

  void dispose() => _impl.dispose();
}
