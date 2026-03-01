import 'dart:convert';

/// 목표 유형
enum GoalType {
  saving,       // 저축 목표 (수입-지출 >= 목표)
  spendingLimit // 지출 한도 (지출 <= 목표)
}

/// 월별 목표 금액 모델
class SavingsGoal {
  final String id;
  final int year;
  final int month;
  final double goalAmount;
  final GoalType goalType;
  final String ownerKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavingsGoal({
    required this.id,
    required this.year,
    required this.month,
    required this.goalAmount,
    required this.goalType,
    required this.ownerKey,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 새 목표 생성
  factory SavingsGoal.create({
    required int year,
    required int month,
    required double goalAmount,
    required GoalType goalType,
    required String ownerKey,
  }) {
    final now = DateTime.now();
    return SavingsGoal(
      id: 'goal_${year}_${month}_$ownerKey',
      year: year,
      month: month,
      goalAmount: goalAmount,
      goalType: goalType,
      ownerKey: ownerKey,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 달성률 계산
  double getProgress({required double income, required double expense}) {
    if (goalAmount <= 0) return 0;
    switch (goalType) {
      case GoalType.saving:
        final saved = income - expense;
        return (saved / goalAmount * 100).clamp(0, 999);
      case GoalType.spendingLimit:
        // 지출 한도: 적게 쓸수록 달성률 높음
        if (expense <= 0) return 100;
        final remaining = goalAmount - expense;
        return (remaining / goalAmount * 100).clamp(-999, 100);
    }
  }

  /// 목표 달성 여부
  bool isAchieved({required double income, required double expense}) {
    switch (goalType) {
      case GoalType.saving:
        return (income - expense) >= goalAmount;
      case GoalType.spendingLimit:
        return expense <= goalAmount;
    }
  }

  SavingsGoal copyWith({
    String? id,
    int? year,
    int? month,
    double? goalAmount,
    GoalType? goalType,
    String? ownerKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      goalAmount: goalAmount ?? this.goalAmount,
      goalType: goalType ?? this.goalType,
      ownerKey: ownerKey ?? this.ownerKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'month': month,
      'goalAmount': goalAmount,
      'goalType': goalType.name,
      'ownerKey': ownerKey,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      goalAmount: (map['goalAmount'] as num).toDouble(),
      goalType: GoalType.values.firstWhere(
        (e) => e.name == map['goalType'],
        orElse: () => GoalType.saving,
      ),
      ownerKey: map['ownerKey'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory SavingsGoal.fromJson(String source) =>
      SavingsGoal.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'SavingsGoal(id: $id, year: $year, month: $month, goalAmount: $goalAmount, goalType: $goalType)';
  }
}
