import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/category.dart';
import '../../../data/models/receipt.dart';

/// 일괄 처리용 영수증 아이템
class BatchReceiptItem {
  final XFile file;
  final Uint8List bytes;
  bool isProcessing;
  bool isProcessed;
  ReceiptData? receiptData;
  String? errorMessage;
  
  // 폼 데이터 (수정 가능)
  String description;
  String amount;
  DateTime date;
  String category;
  bool isIncome;
  bool isSelected; // 저장 대상 여부

  BatchReceiptItem({
    required this.file,
    required this.bytes,
    this.isProcessing = false,
    this.isProcessed = false,
    this.receiptData,
    this.errorMessage,
    this.description = '',
    this.amount = '',
    DateTime? date,
    this.category = '기타',
    this.isIncome = false,
    this.isSelected = true,
  }) : date = date ?? DateTime.now();

  /// OCR 결과로 폼 데이터 업데이트
  void updateFromReceiptData(ReceiptData data, String Function(String) guessCategory) {
    receiptData = data;
    if (data.storeName != null) {
      description = data.storeName!;
    }
    if (data.totalAmount != null) {
      amount = data.totalAmount!.toStringAsFixed(0);
    }
    if (data.date != null) {
      date = data.date!;
    }
    if (data.category != null && data.category!.isNotEmpty) {
      category = Category.matchOcrCategory(
        data.category!,
        isIncome: data.isIncome,
      );
    } else {
      category = guessCategory(data.storeName ?? '');
    }
    // 수입 여부 자동 설정
    isIncome = data.isIncome;
  }
}
