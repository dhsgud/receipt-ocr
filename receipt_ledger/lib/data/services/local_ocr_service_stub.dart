import 'dart:typed_data';
import '../models/receipt.dart';

/// 웹용 Stub - 로컬 OCR은 웹에서 지원되지 않음
class LocalOcrServiceImpl {
  bool get isLoaded => false;
  bool get isLoading => false;

  Future<void> initialize(String modelPath, String mmprojPath) async {
    throw UnsupportedError('Local OCR is not supported on web. Use server OCR instead.');
  }

  Future<ReceiptData> parseReceiptFromBytes(Uint8List imageBytes) async {
    throw UnsupportedError('Local OCR is not supported on web. Use server OCR instead.');
  }

  void dispose() {}
}
