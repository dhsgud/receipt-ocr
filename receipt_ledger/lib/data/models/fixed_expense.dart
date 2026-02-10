import 'dart:convert';

/// Fixed expense frequency options
enum FixedExpenseFrequency {
  monthly,    // 매월
  weekly,     // 매주
  biweekly,   // 격주
  quarterly,  // 분기
  yearly,     // 매년
}

extension FixedExpenseFrequencyExtension on FixedExpenseFrequency {
  String get displayName {
    switch (this) {
      case FixedExpenseFrequency.monthly:
        return '매월';
      case FixedExpenseFrequency.weekly:
        return '매주';
      case FixedExpenseFrequency.biweekly:
        return '격주';
      case FixedExpenseFrequency.quarterly:
        return '분기';
      case FixedExpenseFrequency.yearly:
        return '매년';
    }
  }
}

/// Fixed expense model for recurring expenses
class FixedExpense {
  final String id;
  final String name;
  final double amount;
  final String categoryId;
  final int paymentDay; // 결제일 (1-31, 주급의 경우 요일 0-6)
  final FixedExpenseFrequency frequency;
  final bool isActive;
  final bool autoRecord; // 자동 기록 여부
  final String? memo;
  final String ownerKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastRecordedDate; // 마지막 기록 날짜
  final bool isSynced;

  const FixedExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.paymentDay,
    this.frequency = FixedExpenseFrequency.monthly,
    this.isActive = true,
    this.autoRecord = false,
    this.memo,
    required this.ownerKey,
    required this.createdAt,
    required this.updatedAt,
    this.lastRecordedDate,
    this.isSynced = false,
  });

  /// Create a new fixed expense
  factory FixedExpense.create({
    required String name,
    required double amount,
    required String categoryId,
    required int paymentDay,
    FixedExpenseFrequency frequency = FixedExpenseFrequency.monthly,
    bool autoRecord = false,
    String? memo,
    required String ownerKey,
  }) {
    final now = DateTime.now();
    return FixedExpense(
      id: '${now.millisecondsSinceEpoch}_${name.hashCode}',
      name: name,
      amount: amount,
      categoryId: categoryId,
      paymentDay: paymentDay,
      frequency: frequency,
      isActive: true,
      autoRecord: autoRecord,
      memo: memo,
      ownerKey: ownerKey,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
    );
  }

  /// Get next payment date from a given date
  DateTime getNextPaymentDate(DateTime from) {
    switch (frequency) {
      case FixedExpenseFrequency.monthly:
        var next = DateTime(from.year, from.month, paymentDay);
        if (next.isBefore(from) || next.isAtSameMomentAs(from)) {
          next = DateTime(from.year, from.month + 1, paymentDay);
        }
        return next;
      case FixedExpenseFrequency.weekly:
        final daysUntilNext = (paymentDay - from.weekday + 7) % 7;
        return from.add(Duration(days: daysUntilNext == 0 ? 7 : daysUntilNext));
      case FixedExpenseFrequency.biweekly:
        final daysUntilNext = (paymentDay - from.weekday + 7) % 7;
        return from.add(Duration(days: daysUntilNext == 0 ? 14 : daysUntilNext));
      case FixedExpenseFrequency.quarterly:
        var next = DateTime(from.year, ((from.month - 1) ~/ 3 + 1) * 3, paymentDay);
        if (next.isBefore(from) || next.isAtSameMomentAs(from)) {
          next = DateTime(from.year, ((from.month - 1) ~/ 3 + 1) * 3 + 3, paymentDay);
        }
        return next;
      case FixedExpenseFrequency.yearly:
        var next = DateTime(from.year, 1, paymentDay);
        if (next.isBefore(from) || next.isAtSameMomentAs(from)) {
          next = DateTime(from.year + 1, 1, paymentDay);
        }
        return next;
    }
  }

  /// Check if payment is due today
  bool isDueToday() {
    final now = DateTime.now();
    final nextPayment = getNextPaymentDate(now.subtract(const Duration(days: 1)));
    return nextPayment.year == now.year && 
           nextPayment.month == now.month && 
           nextPayment.day == now.day;
  }

  /// Days until next payment
  int daysUntilPayment() {
    final now = DateTime.now();
    final nextPayment = getNextPaymentDate(now);
    return nextPayment.difference(now).inDays;
  }

  /// Copy with modified fields
  FixedExpense copyWith({
    String? id,
    String? name,
    double? amount,
    String? categoryId,
    int? paymentDay,
    FixedExpenseFrequency? frequency,
    bool? isActive,
    bool? autoRecord,
    String? memo,
    String? ownerKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRecordedDate,
    bool? isSynced,
  }) {
    return FixedExpense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      paymentDay: paymentDay ?? this.paymentDay,
      frequency: frequency ?? this.frequency,
      isActive: isActive ?? this.isActive,
      autoRecord: autoRecord ?? this.autoRecord,
      memo: memo ?? this.memo,
      ownerKey: ownerKey ?? this.ownerKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRecordedDate: lastRecordedDate ?? this.lastRecordedDate,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'categoryId': categoryId,
      'paymentDay': paymentDay,
      'frequency': frequency.index,
      'isActive': isActive ? 1 : 0,
      'autoRecord': autoRecord ? 1 : 0,
      'memo': memo,
      'ownerKey': ownerKey,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastRecordedDate': lastRecordedDate?.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  /// Create from Map (database row)
  factory FixedExpense.fromMap(Map<String, dynamic> map) {
    return FixedExpense(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      paymentDay: map['paymentDay'] as int,
      frequency: FixedExpenseFrequency.values[map['frequency'] as int],
      isActive: map['isActive'] == 1,
      autoRecord: map['autoRecord'] == 1,
      memo: map['memo'] as String?,
      ownerKey: map['ownerKey'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      lastRecordedDate: map['lastRecordedDate'] != null 
          ? DateTime.parse(map['lastRecordedDate'] as String) 
          : null,
      isSynced: map['isSynced'] == 1,
    );
  }

  /// Convert to JSON string
  String toJson() => jsonEncode(toMap());

  /// Create from JSON string
  factory FixedExpense.fromJson(String source) =>
      FixedExpense.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'FixedExpense(id: $id, name: $name, amount: $amount, paymentDay: $paymentDay)';
  }
}
