import 'dart:convert';

/// Budget model for monthly budget management
class Budget {
  final String id;
  final int year;
  final int month;
  final double totalBudget; // 총 월 예산
  final Map<String, double> categoryBudgets; // 카테고리별 예산 {'food': 300000, ...}
  final String ownerKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.year,
    required this.month,
    required this.totalBudget,
    required this.categoryBudgets,
    required this.ownerKey,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new budget for a month
  factory Budget.create({
    required int year,
    required int month,
    required double totalBudget,
    Map<String, double>? categoryBudgets,
    required String ownerKey,
  }) {
    final now = DateTime.now();
    return Budget(
      id: '${year}_${month}_$ownerKey',
      year: year,
      month: month,
      totalBudget: totalBudget,
      categoryBudgets: categoryBudgets ?? {},
      ownerKey: ownerKey,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get spent amount for a category
  double getCategoryBudget(String categoryId) {
    return categoryBudgets[categoryId] ?? 0;
  }

  /// Calculate remaining budget
  double get remainingBudget {
    final allocated = categoryBudgets.values.fold(0.0, (sum, val) => sum + val);
    return totalBudget - allocated;
  }

  /// Check if all budget is allocated
  bool get isFullyAllocated => remainingBudget <= 0;

  /// Get budget usage percentage for a category
  double getCategoryUsagePercentage(String categoryId, double spent) {
    final budget = categoryBudgets[categoryId] ?? 0;
    if (budget <= 0) return 0;
    return (spent / budget * 100).clamp(0, 999);
  }

  /// Check if category is over budget
  bool isCategoryOverBudget(String categoryId, double spent) {
    final budget = categoryBudgets[categoryId] ?? 0;
    return spent > budget;
  }

  /// Copy with modified fields
  Budget copyWith({
    String? id,
    int? year,
    int? month,
    double? totalBudget,
    Map<String, double>? categoryBudgets,
    String? ownerKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      totalBudget: totalBudget ?? this.totalBudget,
      categoryBudgets: categoryBudgets ?? Map.from(this.categoryBudgets),
      ownerKey: ownerKey ?? this.ownerKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Update a single category budget
  Budget updateCategoryBudget(String categoryId, double amount) {
    final updated = Map<String, double>.from(categoryBudgets);
    if (amount > 0) {
      updated[categoryId] = amount;
    } else {
      updated.remove(categoryId);
    }
    return copyWith(
      categoryBudgets: updated,
      updatedAt: DateTime.now(),
    );
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'month': month,
      'totalBudget': totalBudget,
      'categoryBudgets': jsonEncode(categoryBudgets),
      'ownerKey': ownerKey,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from Map (database row)
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      totalBudget: (map['totalBudget'] as num).toDouble(),
      categoryBudgets: Map<String, double>.from(
        jsonDecode(map['categoryBudgets'] as String? ?? '{}') as Map,
      ).map((key, value) => MapEntry(key, (value as num).toDouble())),
      ownerKey: map['ownerKey'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Convert to JSON string
  String toJson() => jsonEncode(toMap());

  /// Create from JSON string
  factory Budget.fromJson(String source) =>
      Budget.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Budget(id: $id, year: $year, month: $month, totalBudget: $totalBudget)';
  }
}
