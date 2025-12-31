import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Simplified Sync service for sharing data between two users
class SyncService {
  static const String _keyBoxName = 'sync_data';
  static const String _myKeyField = 'my_key';
  static const String _partnerKeyField = 'partner_key';
  static const String _partnerIpField = 'partner_ip';

  final TransactionRepository _repository;
  SharedPreferences? _prefs;
  
  String? _myKey;
  String? _partnerKey;
  String? _partnerIp;
  bool _isServerRunning = false;

  SyncService(this._repository);

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Initialize sync service and load stored keys
  Future<void> initialize() async {
    await _ensureInitialized();
    
    _myKey = _prefs!.getString(_myKeyField);
    _partnerKey = _prefs!.getString(_partnerKeyField);
    _partnerIp = _prefs!.getString(_partnerIpField);

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
  bool get isPaired => _partnerKey != null && _partnerIp != null;

  /// Set partner's key and IP address
  Future<void> setPartner(String key, String ip) async {
    await _ensureInitialized();
    _partnerKey = key;
    _partnerIp = ip;
    await _prefs!.setString(_partnerKeyField, key);
    await _prefs!.setString(_partnerIpField, ip);
  }

  /// Clear partner information
  Future<void> clearPartner() async {
    await _ensureInitialized();
    _partnerKey = null;
    _partnerIp = null;
    await _prefs!.remove(_partnerKeyField);
    await _prefs!.remove(_partnerIpField);
  }

  /// Start sync server (simplified for web - just marks as running)
  Future<void> startServer() async {
    // On web, we can't run a real HTTP server
    // This is a placeholder for future implementation with WebSocket or cloud sync
    _isServerRunning = true;
    debugPrint('Sync server marked as running (placeholder on web)');
  }

  /// Stop sync server
  Future<void> stopServer() async {
    _isServerRunning = false;
    debugPrint('Sync server stopped');
  }

  /// Send transactions to partner (placeholder for future implementation)
  Future<bool> syncWithPartner() async {
    if (!isPaired) {
      debugPrint('Cannot sync: not paired with partner');
      return false;
    }

    // Placeholder: In a real implementation, this would sync via 
    // WebSocket, Firebase, or another cloud service
    debugPrint('Sync with partner requested (placeholder)');
    
    // Mark unsynced transactions as synced for demo purposes
    final unsyncedTransactions = await _repository.getUnsyncedTransactions();
    for (final t in unsyncedTransactions) {
      await _repository.markAsSynced(t.id);
    }
    
    return true;
  }

  /// Ping partner to check connection (placeholder)
  Future<bool> pingPartner() async {
    if (_partnerIp == null) return false;
    // Placeholder: real implementation would check connection
    return true;
  }

  /// Get local IP address for QR code (returns placeholder on web)
  Future<String?> getLocalIp() async {
    // On web, we can't get local network IP
    // Return a placeholder or empty string
    return kIsWeb ? 'web-device' : 'local-device';
  }

  /// Generate QR code data
  Future<String> generateQrData() async {
    final ip = await getLocalIp();
    return jsonEncode({
      'key': _myKey,
      'ip': ip,
    });
  }

  /// Parse QR code data from partner
  Map<String, String>? parseQrData(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return {
        'key': json['key'] as String,
        'ip': json['ip'] as String,
      };
    } catch (e) {
      debugPrint('Error parsing QR data: $e');
      return null;
    }
  }

  bool get isServerRunning => _isServerRunning;
}
