import 'package:flutter/material.dart';

/// Category model for transaction categorization
class Category {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final bool isDefault;

  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.isDefault = false,
  });

  /// Default expense categories
  static List<Category> get defaultCategories => [
    Category(
      id: 'food',
      name: '식비',
      emoji: '🍽️',
      color: const Color(0xFFFF6B6B),
      isDefault: true,
    ),
    Category(
      id: 'transport',
      name: '교통',
      emoji: '🚗',
      color: const Color(0xFF4ECDC4),
      isDefault: true,
    ),
    Category(
      id: 'shopping',
      name: '쇼핑',
      emoji: '🛒',
      color: const Color(0xFFFFE66D),
      isDefault: true,
    ),
    Category(
      id: 'medical',
      name: '의료',
      emoji: '🏥',
      color: const Color(0xFF95E1D3),
      isDefault: true,
    ),
    Category(
      id: 'leisure',
      name: '여가',
      emoji: '🎮',
      color: const Color(0xFFA8E6CF),
      isDefault: true,
    ),
    Category(
      id: 'utilities',
      name: '공과금',
      emoji: '📄',
      color: const Color(0xFFDDA0DD),
      isDefault: true,
    ),
    Category(
      id: 'cafe',
      name: '카페',
      emoji: '☕',
      color: const Color(0xFFD4A574),
      isDefault: true,
    ),
    Category(
      id: 'convenience',
      name: '편의점',
      emoji: '🏪',
      color: const Color(0xFF98D8C8),
      isDefault: true,
    ),
    Category(
      id: 'mart',
      name: '마트',
      emoji: '🛍️',
      color: const Color(0xFFF7DC6F),
      isDefault: true,
    ),
    Category(
      id: 'other',
      name: '기타',
      emoji: '📦',
      color: const Color(0xFFBDC3C7),
      isDefault: true,
    ),
    // ============ 수입 카테고리 ============
    Category(
      id: 'salary',
      name: '월급',
      emoji: '💵',
      color: const Color(0xFF22C55E),
      isDefault: true,
    ),
    Category(
      id: 'bonus',
      name: '상여금',
      emoji: '🎁',
      color: const Color(0xFF16A34A),
      isDefault: true,
    ),
    Category(
      id: 'investment',
      name: '투자수익',
      emoji: '📈',
      color: const Color(0xFF15803D),
      isDefault: true,
    ),
    Category(
      id: 'side_income',
      name: '부수입',
      emoji: '💼',
      color: const Color(0xFF059669),
      isDefault: true,
    ),
    Category(
      id: 'etc_income',
      name: '기타수입',
      emoji: '💰',
      color: const Color(0xFF10B981),
      isDefault: true,
    ),
  ];

  /// Find category by name
  static Category findByName(String name) {
    return defaultCategories.firstWhere(
      (c) => c.name == name,
      orElse: () => defaultCategories.last,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'color': color.value,
      'isDefault': isDefault ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      color: Color(map['color'] as int),
      isDefault: map['isDefault'] == 1,
    );
  }
}
