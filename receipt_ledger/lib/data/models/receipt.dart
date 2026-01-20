/// Receipt OCR result model
class ReceiptData {
  final String? storeName;
  final DateTime? date;
  final double? totalAmount;
  final List<ReceiptItem> items;
  final String? rawText;
  final String? category;  // 서버에서 자동 판단된 카테고리
  final bool isIncome;     // 수입 여부 (true: 수입, false: 지출)

  ReceiptData({
    this.storeName,
    this.date,
    this.totalAmount,
    this.items = const [],
    this.rawText,
    this.category,
    this.isIncome = false,
  });

  /// 수입 카테고리인지 확인
  static bool _isIncomeCategory(String? category) {
    const incomeCategories = ['월급', '상여금', '투자수익', '부수입', '기타수입'];
    return category != null && incomeCategories.contains(category);
  }

  factory ReceiptData.fromSllmResponse(Map<String, dynamic> json) {
    // Parse SLLM response - adjust based on actual SLLM API format
    final items = (json['items'] as List<dynamic>?)
        ?.map((item) => ReceiptItem.fromMap(item as Map<String, dynamic>))
        .toList() ?? [];

    DateTime? parsedDate;
    if (json['date'] != null) {
      try {
        final dateStr = json['date'] as String;
        // Try various date formats
        parsedDate = _parseDate(dateStr);
      } catch (_) {}
    }

    // 수입 여부 판단: is_income 필드 또는 카테고리로 판단
    final category = json['category'] as String?;
    final isIncome = json['is_income'] == true || 
                     json['isIncome'] == true ||
                     _isIncomeCategory(category);

    return ReceiptData(
      storeName: json['store_name'] as String? ?? json['storeName'] as String?,
      date: parsedDate,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 
                   (json['totalAmount'] as num?)?.toDouble() ??
                   (json['total'] as num?)?.toDouble(),
      items: items,
      rawText: json['raw_text'] as String? ?? json['rawText'] as String?,
      category: category,
      isIncome: isIncome,
    );
  }

  static DateTime? _parseDate(String dateStr) {
    // Common Korean receipt date formats
    final patterns = [
      RegExp(r'(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})'),
      RegExp(r'(\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(dateStr);
      if (match != null) {
        int year = int.parse(match.group(1)!);
        if (year < 100) year += 2000;
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  @override
  String toString() {
    return 'ReceiptData(storeName: $storeName, date: $date, totalAmount: $totalAmount, items: ${items.length})';
  }
}

/// Individual item on a receipt
class ReceiptItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  ReceiptItem({
    required this.name,
    this.quantity = 1,
    this.unitPrice = 0,
    required this.totalPrice,
  });

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      name: map['name'] as String? ?? map['item_name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 
                 (map['unitPrice'] as num?)?.toDouble() ?? 0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 
                  (map['totalPrice'] as num?)?.toDouble() ?? 
                  (map['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }
}
