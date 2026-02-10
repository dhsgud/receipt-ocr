import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

/// Local storage repository for transactions using SharedPreferences (web-compatible)
class TransactionRepository {
  static const String _storageKey = 'transactions';
  SharedPreferences? _prefs;

  /// Initialize shared preferences
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get all transactions from storage
  Future<List<TransactionModel>> _loadTransactions() async {
    await _ensureInitialized();
    final jsonString = _prefs!.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => TransactionModel.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      return [];
    }
  }

  /// Save all transactions to storage
  Future<void> _saveTransactions(List<TransactionModel> transactions) async {
    await _ensureInitialized();
    final jsonList = transactions.map((t) => t.toMap()).toList();
    await _prefs!.setString(_storageKey, jsonEncode(jsonList));
  }

  /// Insert a new transaction
  Future<void> insertTransaction(TransactionModel transaction) async {
    final transactions = await _loadTransactions();
    // Remove existing with same id if any
    transactions.removeWhere((t) => t.id == transaction.id);
    transactions.add(transaction);
    await _saveTransactions(transactions);
    debugPrint('Transaction saved: ${transaction.description}');
  }

  /// Update an existing transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    final transactions = await _loadTransactions();
    final index = transactions.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) {
      transactions[index] = transaction;
      await _saveTransactions(transactions);
    }
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String id) async {
    final transactions = await _loadTransactions();
    transactions.removeWhere((t) => t.id == id);
    await _saveTransactions(transactions);
  }

  /// Clear all transactions (for data reset)
  Future<void> clearAllTransactions() async {
    await _ensureInitialized();
    await _prefs!.remove(_storageKey);
    debugPrint('All transactions cleared');
  }

  /// Get all transactions
  Future<List<TransactionModel>> getAllTransactions() async {
    final transactions = await _loadTransactions();
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  /// Get transactions for a specific date
  Future<List<TransactionModel>> getTransactionsByDate(DateTime date) async {
    final transactions = await _loadTransactions();
    return transactions.where((t) {
      return t.date.year == date.year &&
             t.date.month == date.month &&
             t.date.day == date.day;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get transactions for a specific month
  Future<List<TransactionModel>> getTransactionsByMonth(int year, int month) async {
    final transactions = await _loadTransactions();
    return transactions.where((t) {
      return t.date.year == year && t.date.month == month;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get transactions for date range
  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final transactions = await _loadTransactions();
    return transactions.where((t) {
      return !t.date.isBefore(start) && !t.date.isAfter(end);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get unsynced transactions
  Future<List<TransactionModel>> getUnsyncedTransactions() async {
    final transactions = await _loadTransactions();
    return transactions.where((t) => !t.isSynced).toList();
  }

  /// Mark transaction as synced
  Future<void> markAsSynced(String id) async {
    final transactions = await _loadTransactions();
    final index = transactions.indexWhere((t) => t.id == id);
    if (index >= 0) {
      transactions[index] = transactions[index].copyWith(isSynced: true);
      await _saveTransactions(transactions);
    }
  }

  /// Get monthly statistics
  Future<Map<String, double>> getMonthlyCategoryTotals(
    int year,
    int month,
  ) async {
    final transactions = await getTransactionsByMonth(year, month);
    final totals = <String, double>{};

    for (final t in transactions) {
      if (!t.isIncome) {
        totals[t.category] = (totals[t.category] ?? 0) + t.amount;
      }
    }

    return totals;
  }

  /// Get total income for a month
  Future<double> getMonthlyIncome(int year, int month) async {
    final transactions = await getTransactionsByMonth(year, month);
    return transactions
        .where((t) => t.isIncome)
        .fold<double>(0.0, (double sum, t) => sum + t.amount);
  }

  /// Get total expense for a month
  Future<double> getMonthlyExpense(int year, int month) async {
    final transactions = await getTransactionsByMonth(year, month);
    return transactions
        .where((t) => !t.isIncome)
        .fold<double>(0.0, (double sum, t) => sum + t.amount);
  }

  /// Normalize store name for comparison
  /// Removes whitespace, special characters, and converts to lowercase
  String _normalizeStoreName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '') // Remove all whitespace
        .replaceAll(RegExp(r'[^\w가-힣]'), ''); // Keep only alphanumeric and Korean chars
  }

  /// Find duplicate transaction by store name, date, and amount
  /// Returns the duplicate transaction if found, null otherwise
  Future<TransactionModel?> findDuplicateTransaction({
    required String? storeName,
    required DateTime date,
    required double amount,
    String? excludeId,
  }) async {
    final transactions = await _loadTransactions();
    
    for (final t in transactions) {
      // Skip if this is the same transaction being edited
      if (excludeId != null && t.id == excludeId) continue;
      
      // Check for duplicate: same date, similar amount (within 1 won), and same store
      final sameDate = t.date.year == date.year &&
                       t.date.month == date.month &&
                       t.date.day == date.day;
      final sameAmount = (t.amount - amount).abs() < 1;
      
      // Compare normalized store names (ignoring whitespace and special chars)
      final sameStore = storeName != null && 
                        t.storeName != null &&
                        _normalizeStoreName(t.storeName!) == _normalizeStoreName(storeName);
      
      // If store name is not available, check by date and exact amount only
      if (storeName == null || t.storeName == null) {
        if (sameDate && sameAmount) {
          return t;
        }
      } else if (sameDate && sameAmount && sameStore) {
        return t;
      }
    }
    
    return null;
  }
}
