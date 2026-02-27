import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/payment_info.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Service to monitor notifications and auto-register payment transactions
class NotificationMonitorService {
  static const String _enabledKey = 'notification_monitor_enabled';
  
  final TransactionRepository _transactionRepository;
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  bool _isMonitoring = false;
  
  // Callback for when a new transaction is auto-registered
  VoidCallback? onTransactionRegistered;

  NotificationMonitorService(this._transactionRepository);

  /// Known payment app package names
  static const List<String> paymentApps = [
    // 페이 서비스
    'com.samsung.android.spay',           // 삼성페이
    'com.samsung.android.samsungpay.gear', // 삼성페이 기어
    'com.kakao.talk',                      // 카카오페이 (카카오톡)
    'com.kakaopay.app',                    // 카카오페이
    'com.nhn.android.search',              // 네이버페이
    'com.navercorp.android.npay',          // 네이버페이
    'viva.republica.toss',                 // 토스
    'com.lge.lgpay',                       // LG페이
    'kr.co.ssg.ssgpay',                    // SSG페이
    'com.lottemembers.android',            // L.pay
    
    // 카드사
    'com.samsungcard.smartpay',            // 삼성카드
    'com.hanaskcard.rocomo.potal',         // 하나카드
    'com.kbcard.cxh.appcard',              // KB국민카드
    'com.shinhancard.smartshinhan',        // 신한카드
    'com.wooricard.smartapp',              // 우리카드
    'com.lotte.lottemembers',              // 롯데카드
    'kr.co.hyundaicard.appcard',           // 현대카드
    'kr.co.citibank.citimobile',           // 씨티카드
    'com.bccard.bcpaybooc',                // BC카드
    'nh.smart.card',                       // NH농협카드
    
    // 은행
    'com.kakaobank.android',               // 카카오뱅크
    'com.kbankwith',                       // 케이뱅크
    'com.kbstar.kbbank',                   // KB국민은행
    'com.shinhan.sbanking',                // 신한은행
    'com.wooribank.smart.npib',            // 우리은행
    'com.hanabank.ebk.channel.android.hananbank', // 하나은행
    'nh.smart.banking',                    // NH농협은행
    'com.ibk.neobanking',                  // IBK기업은행
    'kr.co.kfcc.mobilebank',               // 새마을금고
    'com.epost.psf.sdsi',                  // 우체국예금
  ];

  /// Payment-related keywords
  static const List<String> paymentKeywords = [
    '승인', '결제', '사용', '출금', '이체', '결제완료',
    '체크카드', '신용카드', '정상', '취소', '해외결제',
  ];

  /// Category detection keywords
  static const Map<String, List<String>> categoryKeywords = {
    '식비': ['스타벅스', '투썸', '맥도날드', '버거킹', 'KFC', '롯데리아', 'BBQ', 
             'BHC', '교촌', '배달의민족', '요기요', '쿠팡이츠', 'GS25', 'CU', 
             '세븐일레븐', '이마트24', '미니스톱', '편의점', '마트', '식당'],
    '교통': ['택시', '카카오T', '우버', 'T머니', '지하철', '버스', '주유소', 
             'SK에너지', 'GS칼텍스', 'S-OIL', '현대오일뱅크', '주차'],
    '쇼핑': ['쿠팡', '11번가', 'G마켓', '옥션', '위메프', '티몬', '네이버쇼핑',
             '백화점', '아울렛', '다이소', '올리브영', '무신사'],
    '의료': ['병원', '약국', '의원', '치과', '안과', '피부과', '내과', '정형외과'],
    '생활': ['통신', 'SKT', 'KT', 'LG U+', '전기', '가스', '수도', '관리비', '보험'],
    '문화': ['CGV', '메가박스', '롯데시네마', '넷플릭스', '유튜브', '스포티파이', 
             '멜론', '도서', '교보문고', '게임'],
  };

  /// Check if notification permission is granted
  Future<bool> isPermissionGranted() async {
    return await NotificationListenerService.isPermissionGranted();
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    return await NotificationListenerService.requestPermission();
  }

  /// Check if monitoring is enabled in settings
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Enable or disable monitoring in settings
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    
    if (enabled) {
      await startMonitoring();
    } else {
      stopMonitoring();
    }
  }

  /// Start monitoring notifications
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    
    final hasPermission = await isPermissionGranted();
    if (!hasPermission) {
      return;
    }
    
    _subscription = NotificationListenerService.notificationsStream.listen(
      _handleNotification,
      onError: (error) {
      },
    );
    
    _isMonitoring = true;
  }

  /// Stop monitoring notifications
  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
    _isMonitoring = false;
  }

  /// Handle incoming notification
  Future<void> _handleNotification(ServiceNotificationEvent event) async {
    // Skip removed notifications
    if (event.hasRemoved == true) return;
    
    final packageName = event.packageName ?? '';
    final title = event.title ?? '';
    final content = event.content ?? '';
    
    // Check if it's from a payment app
    if (!paymentApps.contains(packageName)) {
      return;
    }
    
    // Try to parse payment information
    final paymentInfo = parsePaymentNotification(
      title: title,
      content: content,
      packageName: packageName,
    );
    
    if (paymentInfo != null) {
      await _registerToLedger(paymentInfo);
    }
  }

  /// Parse payment notification to extract payment info
  PaymentInfo? parsePaymentNotification({
    required String title,
    required String content,
    required String packageName,
  }) {
    final fullText = '$title $content';
    
    // Check if it contains payment keywords
    final hasPaymentKeyword = paymentKeywords.any(
      (keyword) => fullText.contains(keyword),
    );
    
    if (!hasPaymentKeyword) {
      return null;
    }
    
    // Extract amount
    final amount = _extractAmount(fullText);
    if (amount == null || amount <= 0) {
      return null;
    }
    
    // Extract store name
    final storeName = _extractStoreName(fullText);
    
    // Extract card name
    final cardName = _extractCardName(fullText);
    
    // Detect category
    final category = _detectCategory(fullText);
    
    return PaymentInfo(
      storeName: storeName,
      amount: amount,
      dateTime: DateTime.now(),
      cardName: cardName,
      category: category,
      sourceApp: packageName,
      rawContent: fullText,
    );
  }

  /// Extract amount from notification text
  double? _extractAmount(String text) {
    // Pattern: number followed by 원
    // Handles comma-separated numbers like 45,000원
    final patterns = [
      RegExp(r'([\d,]+)\s*원'),
      RegExp(r'KRW\s*([\d,]+)'),
      RegExp(r'₩\s*([\d,]+)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        return double.tryParse(amountStr);
      }
    }
    
    return null;
  }

  /// Extract store name from notification text
  String? _extractStoreName(String text) {
    // Common patterns:
    // "삼성카드 승인 45,000원 스타벅스강남점 일시불"
    // "결제완료 15,500원 GS25강남점"
    // "네이버페이 결제 완료 7,200원 세븐일레븐"
    
    // Try to extract text after amount
    final amountPattern = RegExp(r'[\d,]+\s*원\s*([가-힣A-Za-z0-9]+)');
    var match = amountPattern.firstMatch(text);
    if (match != null) {
      final extracted = match.group(1);
      if (extracted != null && extracted.length > 1) {
        // Remove common suffixes
        return extracted
            .replaceAll(RegExp(r'(일시불|할부|정상|승인|결제)'), '')
            .trim();
      }
    }
    
    // Try pattern before amount
    final beforeAmountPattern = RegExp(r'([가-힣A-Za-z0-9]+)\s*[\d,]+\s*원');
    match = beforeAmountPattern.firstMatch(text);
    if (match != null) {
      final extracted = match.group(1);
      if (extracted != null && 
          extracted.length > 1 && 
          !paymentKeywords.contains(extracted)) {
        return extracted.trim();
      }
    }
    
    return null;
  }

  /// Extract card name from notification text
  String? _extractCardName(String text) {
    final cardPatterns = [
      RegExp(r'(삼성|신한|현대|국민|KB|롯데|하나|우리|BC|NH농협|씨티)(카드)?'),
      RegExp(r'(체크카드|신용카드)'),
    ];
    
    for (final pattern in cardPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    
    return null;
  }

  /// Detect category based on store name and keywords
  String _detectCategory(String text) {
    for (final entry in categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;
      
      for (final keyword in keywords) {
        if (text.contains(keyword)) {
          return category;
        }
      }
    }
    
    return '기타';
  }

  /// Get the user's sync key from SharedPreferences
  Future<String> _getOwnerKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('my_key') ?? 'local';
  }

  /// Register payment info to ledger
  Future<void> _registerToLedger(PaymentInfo info) async {
    // Check for duplicate
    final duplicate = await _transactionRepository.findDuplicateTransaction(
      storeName: info.storeName,
      date: info.dateTime,
      amount: info.amount,
    );
    
    if (duplicate != null) {
      return;
    }
    
    // Get the actual user key for proper sync matching
    final ownerKey = await _getOwnerKey();
    
    // Create transaction
    final transaction = TransactionModel(
      id: const Uuid().v4(),
      date: info.dateTime,
      category: info.category,
      amount: info.amount,
      description: info.cardName != null 
          ? '${info.cardName} 결제' 
          : '자동 등록',
      storeName: info.storeName,
      isIncome: false,
      ownerKey: ownerKey,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    
    await _transactionRepository.insertTransaction(transaction);
    
    // Notify listeners
    onTransactionRegistered?.call();
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
  }
}
