import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fixed_expense.dart';

/// Local storage repository for fixed expenses using SharedPreferences
class FixedExpenseRepository {
  static const String _storageKey = 'fixed_expenses';
  SharedPreferences? _prefs;

  /// Initialize shared preferences
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Load all fixed expenses from storage
  Future<List<FixedExpense>> _loadFixedExpenses() async {
    await _ensureInitialized();
    final jsonString = _prefs!.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => FixedExpense.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save all fixed expenses to storage
  Future<void> _saveFixedExpenses(List<FixedExpense> expenses) async {
    await _ensureInitialized();
    final jsonList = expenses.map((e) => e.toMap()).toList();
    await _prefs!.setString(_storageKey, jsonEncode(jsonList));
  }

  /// Get all fixed expenses
  Future<List<FixedExpense>> getAllFixedExpenses() async {
    return await _loadFixedExpenses();
  }

  /// Save or update a fixed expense
  Future<void> saveFixedExpense(FixedExpense expense) async {
    final expenses = await _loadFixedExpenses();
    final index = expenses.indexWhere((e) => e.id == expense.id);
    if (index >= 0) {
      expenses[index] = expense.copyWith(isSynced: false);
    } else {
      expenses.add(expense.copyWith(isSynced: false));
    }
    await _saveFixedExpenses(expenses);
  }

  /// Delete a fixed expense
  Future<void> deleteFixedExpense(String id) async {
    final expenses = await _loadFixedExpenses();
    expenses.removeWhere((e) => e.id == id);
    await _saveFixedExpenses(expenses);
  }

  /// Get unsynced fixed expenses
  Future<List<FixedExpense>> getUnsyncedFixedExpenses() async {
    final expenses = await _loadFixedExpenses();
    return expenses.where((e) => !e.isSynced).toList();
  }

  /// Mark fixed expense as synced
  Future<void> markAsSynced(String id) async {
    final expenses = await _loadFixedExpenses();
    final index = expenses.indexWhere((e) => e.id == id);
    if (index >= 0) {
      expenses[index] = expenses[index].copyWith(isSynced: true);
      await _saveFixedExpenses(expenses);
    }
  }

  /// Migrate ownerKey from UUID to email (one-time migration)
  Future<int> migrateOwnerKey(String oldKey, String newEmail) async {
    final expenses = await _loadFixedExpenses();
    int count = 0;
    final updated = expenses.map((e) {
      if (e.ownerKey == oldKey) {
        count++;
        return e.copyWith(ownerKey: newEmail);
      }
      return e;
    }).toList();
    if (count > 0) {
      await _saveFixedExpenses(updated);
    }
    return count;
  }

  /// Reset sync status for all fixed expenses (for re-sync with new partner)
  Future<void> resetAllSyncStatus() async {
    final expenses = await _loadFixedExpenses();
    final updated = expenses.map((e) => e.copyWith(isSynced: false)).toList();
    await _saveFixedExpenses(updated);
  }

  /// Insert a fixed expense (used by sync to save downloaded data)
  Future<void> insertFixedExpense(FixedExpense expense) async {
    final expenses = await _loadFixedExpenses();
    expenses.removeWhere((e) => e.id == expense.id);
    expenses.add(expense);
    await _saveFixedExpenses(expenses);
  }
}
