import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/savings_goal.dart';

/// SharedPreferences 기반 목표 금액 저장소
class SavingsGoalRepository {
  static const String _storageKey = 'savings_goals';
  SharedPreferences? _prefs;

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 전체 목표 로드
  Future<List<SavingsGoal>> _loadGoals() async {
    await _ensureInitialized();
    final jsonString = _prefs!.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => SavingsGoal.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 전체 목표 저장
  Future<void> _saveGoals(List<SavingsGoal> goals) async {
    await _ensureInitialized();
    final jsonList = goals.map((g) => g.toMap()).toList();
    await _prefs!.setString(_storageKey, jsonEncode(jsonList));
  }

  /// 특정 월의 목표 조회
  Future<SavingsGoal?> getGoal(int year, int month) async {
    final goals = await _loadGoals();
    try {
      return goals.firstWhere(
        (g) => g.year == year && g.month == month,
      );
    } catch (_) {
      return null;
    }
  }

  /// 목표 저장/수정
  Future<void> saveGoal(SavingsGoal goal) async {
    final goals = await _loadGoals();
    final index = goals.indexWhere((g) => g.id == goal.id);
    if (index >= 0) {
      goals[index] = goal;
    } else {
      goals.add(goal);
    }
    await _saveGoals(goals);
  }

  /// 목표 삭제
  Future<void> deleteGoal(int year, int month) async {
    final goals = await _loadGoals();
    goals.removeWhere((g) => g.year == year && g.month == month);
    await _saveGoals(goals);
  }

  /// 전체 목표 조회
  Future<List<SavingsGoal>> getAllGoals() async {
    return await _loadGoals();
  }
}
