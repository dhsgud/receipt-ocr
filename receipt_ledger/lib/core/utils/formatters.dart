import 'package:intl/intl.dart';

/// Utility functions for formatting
class Formatters {
  /// Format currency with Korean Won symbol
  static String currency(double amount) {
    final formatter = NumberFormat('#,###');
    return '${formatter.format(amount.abs().round())}원';
  }

  /// Format currency in compact form (e.g. 1.2만)
  static String compactCurrency(double amount) {
    if (amount == 0) return '0';
    
    final absAmount = amount.abs();
    if (absAmount >= 100000000) {
      final result = absAmount / 100000000;
      return '${result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 1)}억';
    } else if (absAmount >= 10000) {
      final result = absAmount / 10000;
      return '${result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 1)}만';
    } else {
      return NumberFormat('#,###').format(absAmount.round());
    }
  }
  
  /// Format date as yyyy-MM-dd
  static String date(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// Format date as yyyy년 MM월 dd일
  static String dateKorean(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
  
  /// Format date as MM월 dd일 (요일)
  static String dateShort(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}월 ${date.day}일 ($weekday)';
  }
  
  /// Format time as HH:mm
  static String time(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  /// Format month as yyyy년 MM월
  static String month(DateTime date) {
    return '${date.year}년 ${date.month}월';
  }
}

/// Category icon mapping
class CategoryIcons {
  static const Map<String, String> icons = {
    '식비': '🍽️',
    '교통': '🚗',
    '쇼핑': '🛒',
    '의료': '🏥',
    '여가': '🎮',
    '공과금': '📄',
    '카페': '☕',
    '편의점': '🏪',
    '마트': '🛍️',
    '기타': '📦',
    '수입': '💰',
  };
  
  static String getIcon(String category) {
    return icons[category] ?? '📦';
  }
}
