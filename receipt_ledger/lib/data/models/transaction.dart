import 'dart:convert';

/// TransactionModel representing a single expense or income entry
class TransactionModel {
  final String id;
  final DateTime date;
  final String category;
  final double amount;
  final String description;
  final String? receiptImagePath;
  final String? storeName;
  final bool isIncome;
  final String ownerKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  TransactionModel({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    required this.description,
    this.receiptImagePath,
    this.storeName,
    this.isIncome = false,
    required this.ownerKey,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  /// Create a copy with modified fields
  TransactionModel copyWith({
    String? id,
    DateTime? date,
    String? category,
    double? amount,
    String? description,
    String? receiptImagePath,
    String? storeName,
    bool? isIncome,
    String? ownerKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      storeName: storeName ?? this.storeName,
      isIncome: isIncome ?? this.isIncome,
      ownerKey: ownerKey ?? this.ownerKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'category': category,
      'amount': amount,
      'description': description,
      'receiptImagePath': receiptImagePath,
      'storeName': storeName,
      'isIncome': isIncome ? 1 : 0,
      'ownerKey': ownerKey,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  /// Create from Map (database row)
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      receiptImagePath: map['receiptImagePath'] as String?,
      storeName: map['storeName'] as String?,
      isIncome: map['isIncome'] == 1,
      ownerKey: map['ownerKey'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isSynced: map['isSynced'] == 1,
    );
  }

  /// Convert to JSON string for sync
  String toJson() => jsonEncode(toMap());

  /// Create from JSON string
  factory TransactionModel.fromJson(String source) =>
      TransactionModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'TransactionModel(id: $id, date: $date, category: $category, amount: $amount, description: $description)';
  }
}
