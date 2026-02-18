import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/fixed_expense.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/fixed_expense_repository.dart';
import 'image_cache_service.dart';

/// Sync service for sharing data between partners via desktop server
class SyncService {
  static const String _myKeyField = 'my_key';
  static const String _partnerKeyField = 'partner_key';
  static const String _lastSyncTimeField = 'last_sync_time';
  static const String _myNicknameField = 'my_nickname';
  static const String _partnerNicknameField = 'partner_nickname';

  final TransactionRepository _repository;
  final BudgetRepository _budgetRepository;
  final FixedExpenseRepository _fixedExpenseRepository;
  final Dio _dio;
  final ImageCacheService _imageCacheService;
  SharedPreferences? _prefs;
  
  String? _myKey;
  String? _partnerKey;
  String? _lastSyncTime;
  String _myNickname = '';
  String _partnerNickname = '';
  bool _isSyncing = false;

  SyncService(this._repository, this._budgetRepository, this._fixedExpenseRepository) : 
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.syncServerUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    )),
    _imageCacheService = ImageCacheService();

  /// 이미지 캐시 서비스 접근자
  ImageCacheService get imageCacheService => _imageCacheService;

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Initialize sync service and load stored keys
  Future<void> initialize() async {
    await _ensureInitialized();
    
    _myKey = _prefs!.getString(_myKeyField);
    _partnerKey = _prefs!.getString(_partnerKeyField);
    _lastSyncTime = _prefs!.getString(_lastSyncTimeField);
    _myNickname = _prefs!.getString(_myNicknameField) ?? '';
    _partnerNickname = _prefs!.getString(_partnerNicknameField) ?? '';

    // Generate key if not exists
    if (_myKey == null) {
      _myKey = const Uuid().v4();
      await _prefs!.setString(_myKeyField, _myKey!);
    }
    
    debugPrint('SyncService initialized with key: $_myKey');
  }

  /// Get my unique key
  String get myKey => _myKey ?? '';

  /// Get partner's key
  String? get partnerKey => _partnerKey;

  /// Check if paired with partner
  bool get isPaired => _partnerKey != null;
  
  /// Is currently syncing
  bool get isSyncing => _isSyncing;

  /// Get my nickname
  String get myNickname => _myNickname;

  /// Get partner's nickname
  String get partnerNickname => _partnerNickname;

  /// Set my nickname
  Future<void> setMyNickname(String nickname) async {
    await _ensureInitialized();
    _myNickname = nickname.trim();
    await _prefs!.setString(_myNicknameField, _myNickname);
  }

  /// Set partner's nickname
  Future<void> setPartnerNickname(String nickname) async {
    await _ensureInitialized();
    _partnerNickname = nickname.trim();
    await _prefs!.setString(_partnerNicknameField, _partnerNickname);
  }

  /// Get display name for a given ownerKey
  /// Returns nickname if available, otherwise truncated key
  String getOwnerName(String ownerKey) {
    if (ownerKey == _myKey) {
      return _myNickname.isNotEmpty ? _myNickname : '나';
    } else if (ownerKey == _partnerKey) {
      return _partnerNickname.isNotEmpty ? _partnerNickname : '파트너';
    }
    return '알 수 없음';
  }

  /// Check if a transaction belongs to me
  bool isMyTransaction(String ownerKey) => ownerKey == _myKey;

  /// Set partner's key
  Future<void> setPartnerKey(String key) async {
    await _ensureInitialized();
    _partnerKey = key;
    await _prefs!.setString(_partnerKeyField, key);
    // Clear last sync time to download ALL partner data on next sync
    _lastSyncTime = null;
    await _prefs!.remove(_lastSyncTimeField);
  }

  /// Clear partner information
  Future<void> clearPartner() async {
    await _ensureInitialized();
    _partnerKey = null;
    await _prefs!.remove(_partnerKeyField);
  }

  /// Test connection to sync server
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Sync server connection failed: $e');
      return false;
    }
  }

  /// Sync with server: upload local changes and download remote changes
  Future<SyncResult> syncWithServer() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: '이미 동기화 중입니다');
    }

    // Partner connection required for sync
    if (!isPaired) {
      return SyncResult(
        success: false,
        message: '파트너 연결이 필요합니다. 설정에서 파트너를 추가해주세요.',
      );
    }

    _isSyncing = true;
    
    try {
      // Get unsynced local transactions
      final unsyncedTransactions = await _repository.getUnsyncedTransactions();
      final unsyncedBudgets = await _budgetRepository.getUnsyncedBudgets();
      final unsyncedFixedExpenses = await _fixedExpenseRepository.getUnsyncedFixedExpenses();
      
      // Prepare sync request
      final requestData = {
        'transactions': unsyncedTransactions.map((t) => t.toMap()).toList(),
        'budgets': unsyncedBudgets.map((b) => b.toMap()).toList(),
        'fixedExpenses': unsyncedFixedExpenses.map((e) => e.toMap()).toList(),
        'lastSyncTime': _lastSyncTime,
      };

      debugPrint('Syncing ${unsyncedTransactions.length} transactions, '
          '${unsyncedBudgets.length} budgets, '
          '${unsyncedFixedExpenses.length} fixed expenses...');

      // Note: Images are stored locally only, not synced to server

      // Send sync request with owner and partner keys
      final response = await _dio.post(
        '/api/sync', 
        data: requestData,
        options: Options(
          headers: {
            'X-Owner-Key': _myKey ?? '',
            'X-Partner-Key': _partnerKey ?? '',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final serverTime = data['serverTime'] as String;
        final downloaded = data['downloaded'] as List? ?? [];
        final downloadedBudgets = data['downloadedBudgets'] as List? ?? [];
        final downloadedFixedExpenses = data['downloadedFixedExpenses'] as List? ?? [];
        
        // Save downloaded transactions
        for (final json in downloaded) {
          final transaction = TransactionModel.fromMap(json as Map<String, dynamic>);
          await _repository.insertTransaction(transaction.copyWith(
            isSynced: true,
          ));
        }

        // Save downloaded budgets
        for (final json in downloadedBudgets) {
          final budget = Budget.fromMap(json as Map<String, dynamic>);
          await _budgetRepository.insertBudget(budget.copyWith(
            isSynced: true,
          ));
        }

        // Save downloaded fixed expenses
        for (final json in downloadedFixedExpenses) {
          final expense = FixedExpense.fromMap(json as Map<String, dynamic>);
          await _fixedExpenseRepository.insertFixedExpense(expense.copyWith(
            isSynced: true,
          ));
        }

        // Mark uploaded items as synced
        for (final t in unsyncedTransactions) {
          await _repository.markAsSynced(t.id);
        }
        for (final b in unsyncedBudgets) {
          await _budgetRepository.markAsSynced(b.id);
        }
        for (final e in unsyncedFixedExpenses) {
          await _fixedExpenseRepository.markAsSynced(e.id);
        }

        // Update last sync time
        _lastSyncTime = serverTime;
        await _prefs!.setString(_lastSyncTimeField, serverTime);

        final totalUploaded = unsyncedTransactions.length + unsyncedBudgets.length + unsyncedFixedExpenses.length;
        final totalDownloaded = downloaded.length + downloadedBudgets.length + downloadedFixedExpenses.length;
        debugPrint('Sync complete: uploaded $totalUploaded, downloaded $totalDownloaded');
        
        return SyncResult(
          success: true,
          message: '동기화 완료',
          uploaded: totalUploaded,
          downloaded: totalDownloaded,
        );
      } else {
        return SyncResult(
          success: false,
          message: '서버 응답 오류: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final message = _getDioErrorMessage(e);
      debugPrint('Sync failed: $message');
      return SyncResult(success: false, message: message);
    } catch (e) {
      debugPrint('Sync error: $e');
      return SyncResult(success: false, message: '동기화 실패: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Reset sync status of all local data and perform full sync
  /// Used when pairing with a new partner to share all existing data
  Future<SyncResult> fullSync() async {
    // Reset all local data to unsynced
    await _repository.resetAllSyncStatus();
    await _budgetRepository.resetAllSyncStatus();
    await _fixedExpenseRepository.resetAllSyncStatus();

    // Clear last sync time to download ALL data from server
    await _ensureInitialized();
    _lastSyncTime = null;
    await _prefs!.remove(_lastSyncTimeField);

    debugPrint('Full sync: reset all sync status and cleared last sync time');

    // Run normal sync (all data will be uploaded + all partner data downloaded)
    return syncWithServer();
  }

  /// Pull all transactions from server (full refresh)
  Future<SyncResult> pullFromServer() async {
    try {
      final response = await _dio.get('/api/transactions');

      if (response.statusCode == 200) {
        final transactions = response.data as List;
        
        for (final json in transactions) {
          final transaction = TransactionModel.fromMap(json as Map<String, dynamic>);
          await _repository.insertTransaction(transaction.copyWith(isSynced: true));
        }

        return SyncResult(
          success: true,
          message: '${transactions.length}개 트랜잭션 다운로드 완료',
          downloaded: transactions.length,
        );
      } else {
        return SyncResult(success: false, message: '다운로드 실패');
      }
    } on DioException catch (e) {
      return SyncResult(success: false, message: _getDioErrorMessage(e));
    } catch (e) {
      return SyncResult(success: false, message: '다운로드 오류: $e');
    }
  }

  /// Generate QR code data for pairing (includes nickname)
  String generateQrData() {
    return jsonEncode({
      'key': _myKey,
      'nickname': _myNickname,
    });
  }

  /// Parse QR code data from partner (includes nickname)
  Map<String, String>? parseQrData(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return {
        'key': json['key'] as String,
        'nickname': (json['nickname'] as String?) ?? '',
      };
    } catch (e) {
      debugPrint('Error parsing QR data: $e');
      return null;
    }
  }

  String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '서버 연결 시간 초과';
      case DioExceptionType.connectionError:
        return '서버에 연결할 수 없습니다. 네트워크를 확인해주세요.';
      case DioExceptionType.badResponse:
        return '서버 오류: ${e.response?.statusCode}';
      default:
        return '네트워크 오류: ${e.message}';
    }
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;
  final int uploaded;
  final int downloaded;

  SyncResult({
    required this.success,
    required this.message,
    this.uploaded = 0,
    this.downloaded = 0,
  });
}
