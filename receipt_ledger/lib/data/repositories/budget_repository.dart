import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';

/// Local storage repository for budgets using SharedPreferences
class BudgetRepository {
  static const String _storageKey = 'budgets';
  SharedPreferences? _prefs;

  /// Initialize shared preferences
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Load all budgets from storage
  Future<List<Budget>> _loadBudgets() async {
    await _ensureInitialized();
    final jsonString = _prefs!.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => Budget.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading budgets: $e');
      return [];
    }
  }

  /// Save all budgets to storage
  Future<void> _saveBudgets(List<Budget> budgets) async {
    await _ensureInitialized();
    final jsonList = budgets.map((b) => b.toMap()).toList();
    await _prefs!.setString(_storageKey, jsonEncode(jsonList));
  }

  /// Get budget for a specific month
  Future<Budget?> getBudget(int year, int month) async {
    final budgets = await _loadBudgets();
    try {
      return budgets.firstWhere(
        (b) => b.year == year && b.month == month,
      );
    } catch (_) {
      return null;
    }
  }

  /// Save or update a budget
  Future<void> saveBudget(Budget budget) async {
    final budgets = await _loadBudgets();
    final index = budgets.indexWhere((b) => b.id == budget.id);
    if (index >= 0) {
      budgets[index] = budget.copyWith(isSynced: false);
    } else {
      budgets.add(budget.copyWith(isSynced: false));
    }
    await _saveBudgets(budgets);
    debugPrint('Budget saved: ${budget.year}/${budget.month}');
  }

  /// Get all budgets
  Future<List<Budget>> getAllBudgets() async {
    return await _loadBudgets();
  }

  /// Get unsynced budgets
  Future<List<Budget>> getUnsyncedBudgets() async {
    final budgets = await _loadBudgets();
    return budgets.where((b) => !b.isSynced).toList();
  }

  /// Mark budget as synced
  Future<void> markAsSynced(String id) async {
    final budgets = await _loadBudgets();
    final index = budgets.indexWhere((b) => b.id == id);
    if (index >= 0) {
      budgets[index] = budgets[index].copyWith(isSynced: true);
      await _saveBudgets(budgets);
    }
  }

  /// Insert a budget (used by sync to save downloaded data)
  Future<void> insertBudget(Budget budget) async {
    final budgets = await _loadBudgets();
    budgets.removeWhere((b) => b.id == budget.id);
    budgets.add(budget);
    await _saveBudgets(budgets);
  }
}
