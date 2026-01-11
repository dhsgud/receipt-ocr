import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Sync service for sharing data between partners via desktop server
class SyncService {
  static const String _myKeyField = 'my_key';
  static const String _partnerKeyField = 'partner_key';
  static const String _lastSyncTimeField = 'last_sync_time';

  final TransactionRepository _repository;
  final Dio _dio;
  SharedPreferences? _prefs;
  
  String? _myKey;
  String? _partnerKey;
  String? _lastSyncTime;
  bool _isSyncing = false;

  SyncService(this._repository) : _dio = Dio(BaseOptions(
    baseUrl: AppConstants.syncServerUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Initialize sync service and load stored keys
  Future<void> initialize() async {
    await _ensureInitialized();
    
    _myKey = _prefs!.getString(_myKeyField);
    _partnerKey = _prefs!.getString(_partnerKeyField);
    _lastSyncTime = _prefs!.getString(_lastSyncTimeField);

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

  /// Set partner's key
  Future<void> setPartnerKey(String key) async {
    await _ensureInitialized();
    _partnerKey = key;
    await _prefs!.setString(_partnerKeyField, key);
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

    _isSyncing = true;
    
    try {
      // Get unsynced local transactions
      final unsyncedTransactions = await _repository.getUnsyncedTransactions();
      
      // Prepare sync request
      final requestData = {
        'transactions': unsyncedTransactions.map((t) => t.toMap()).toList(),
        'lastSyncTime': _lastSyncTime,
      };

      debugPrint('Syncing ${unsyncedTransactions.length} transactions...');

      // Send sync request
      final response = await _dio.post('/api/sync', data: requestData);

      if (response.statusCode == 200) {
        final data = response.data;
        final serverTime = data['serverTime'] as String;
        final downloaded = data['downloaded'] as List;
        
        // Save downloaded transactions
        for (final json in downloaded) {
          final transaction = TransactionModel.fromMap(json as Map<String, dynamic>);
          await _repository.insertTransaction(transaction.copyWith(isSynced: true));
        }

        // Mark uploaded transactions as synced
        for (final t in unsyncedTransactions) {
          await _repository.markAsSynced(t.id);
        }

        // Update last sync time
        _lastSyncTime = serverTime;
        await _prefs!.setString(_lastSyncTimeField, serverTime);

        debugPrint('Sync complete: uploaded ${unsyncedTransactions.length}, downloaded ${downloaded.length}');
        
        return SyncResult(
          success: true,
          message: '동기화 완료',
          uploaded: unsyncedTransactions.length,
          downloaded: downloaded.length,
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

  /// Generate QR code data for pairing
  String generateQrData() {
    return jsonEncode({'key': _myKey});
  }

  /// Parse QR code data from partner
  Map<String, String>? parseQrData(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return {'key': json['key'] as String};
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
