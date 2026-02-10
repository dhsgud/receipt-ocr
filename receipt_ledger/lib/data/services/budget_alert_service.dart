import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../repositories/transaction_repository.dart';

/// 예산 초과 알림 서비스
/// 거래 등록 후 해당 카테고리의 예산 상태를 확인하고 알림을 표시합니다.
class BudgetAlertService {
  static const String _budgetStorageKey = 'budgets';
  static const String _alertEnabledKey = 'budget_alert_enabled';
  
  final TransactionRepository _transactionRepository;
  BuildContext? _context;
  
  BudgetAlertService(this._transactionRepository);
  
  /// BuildContext 설정 (SnackBar 표시용)
  void setContext(BuildContext context) {
    _context = context;
  }
  
  /// 알림 활성화 여부 확인
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alertEnabledKey) ?? true; // 기본값: 활성화
  }
  
  /// 알림 활성화/비활성화 설정
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertEnabledKey, enabled);
  }
  
  /// 현재 월 예산 가져오기
  Future<Budget?> _getCurrentBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_budgetStorageKey);
    if (jsonString == null) return null;
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final now = DateTime.now();
      
      for (final json in jsonList) {
        final budget = Budget.fromMap(json as Map<String, dynamic>);
        if (budget.year == now.year && budget.month == now.month) {
          return budget;
        }
      }
    } catch (e) {
      debugPrint('[BudgetAlertService] Error loading budget: $e');
    }
    
    return null;
  }
  
  /// 거래 후 예산 상태 확인 및 알림 표시
  /// [categoryId] 거래의 카테고리 ID
  /// [isIncome] 수입 여부 (수입은 예산 체크 제외)
  Future<void> checkBudgetAndNotify({
    required String categoryId,
    required bool isIncome,
  }) async {
    // 수입은 예산 체크 제외
    if (isIncome) return;
    
    // 알림 비활성화 시 스킵
    final enabled = await isEnabled();
    if (!enabled) return;
    
    // 현재 월 예산 가져오기
    final budget = await _getCurrentBudget();
    if (budget == null) return;
    
    // 카테고리 예산 확인
    final categoryBudget = budget.getCategoryBudget(categoryId);
    if (categoryBudget <= 0) return; // 예산 미설정
    
    // 현재 월 지출 합계 계산
    final now = DateTime.now();
    final categoryTotals = await _transactionRepository.getMonthlyCategoryTotals(
      now.year, 
      now.month,
    );
    final spent = categoryTotals[categoryId] ?? 0;
    
    // 예산 사용률 계산
    final usagePercent = (spent / categoryBudget * 100);
    
    // 카테고리 이름 가져오기
    final categoryName = _getCategoryName(categoryId);
    
    // 알림 표시
    if (usagePercent >= 100) {
      _showBudgetAlert(
        categoryName: categoryName,
        spent: spent,
        budget: categoryBudget,
        alertType: BudgetAlertType.exceeded,
      );
    } else if (usagePercent >= 80) {
      _showBudgetAlert(
        categoryName: categoryName,
        spent: spent,
        budget: categoryBudget,
        alertType: BudgetAlertType.warning,
      );
    }
  }
  
  /// 카테고리 ID로 이름 가져오기
  String _getCategoryName(String categoryId) {
    try {
      // 대분류 확인
      final parentCategory = Category.expenseParentCategories
          .firstWhere((c) => c.id == categoryId);
      return parentCategory.name;
    } catch (_) {
      // 소분류에서 확인
      for (final sub in Category.expenseSubcategories) {
        if (sub.id == categoryId) {
          return sub.name;
        }
      }
    }
    return categoryId;
  }
  
  /// 예산 알림 표시
  void _showBudgetAlert({
    required String categoryName,
    required double spent,
    required double budget,
    required BudgetAlertType alertType,
  }) {
    if (_context == null) return;
    
    final usagePercent = (spent / budget * 100).toInt();
    final remaining = budget - spent;
    
    String message;
    Color backgroundColor;
    IconData icon;
    
    switch (alertType) {
      case BudgetAlertType.warning:
        message = '⚠️ $categoryName 예산 $usagePercent% 사용 (${_formatCurrency(remaining)} 남음)';
        backgroundColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case BudgetAlertType.exceeded:
        message = '🚨 $categoryName 예산 초과! (${_formatCurrency(-remaining)} 초과)';
        backgroundColor = Colors.red;
        icon = Icons.error_outline;
        break;
    }
    
    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
  
  /// 금액 포맷팅
  String _formatCurrency(double amount) {
    final absAmount = amount.abs();
    if (absAmount >= 10000) {
      return '${(absAmount / 10000).toStringAsFixed(1)}만원';
    } else {
      return '${absAmount.toStringAsFixed(0)}원';
    }
  }
}

/// 예산 알림 타입
enum BudgetAlertType {
  warning,  // 80% 이상 사용
  exceeded, // 100% 초과
}
