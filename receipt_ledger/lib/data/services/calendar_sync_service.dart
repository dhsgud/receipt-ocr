import 'package:device_calendar/device_calendar.dart';
import '../models/transaction.dart';
import '../../core/utils/formatters.dart';

/// 캘린더 동기화 결과
class CalendarSyncResult {
  final bool success;
  final int synced;
  final int failed;
  final String? message;

  CalendarSyncResult({
    required this.success,
    this.synced = 0,
    this.failed = 0,
    this.message,
  });
}

/// 이벤트 제목 형식
enum CalendarEventFormat {
  categoryAmount,  // [카테고리] 금액
  storeAmount,     // 상호명 금액
  description,     // 설명
}

/// 캘린더 동기화 서비스
/// 로컬 캘린더(Apple, Samsung, Google 등)에 거래 내역을 동기화합니다.
class CalendarSyncService {
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  
  String? _selectedCalendarId;
  CalendarEventFormat _eventFormat = CalendarEventFormat.categoryAmount;
  
  /// 현재 선택된 캘린더 ID
  String? get selectedCalendarId => _selectedCalendarId;
  
  /// 이벤트 형식 설정
  CalendarEventFormat get eventFormat => _eventFormat;
  set eventFormat(CalendarEventFormat format) => _eventFormat = format;
  
  /// 캘린더 ID 설정
  void setSelectedCalendar(String? calendarId) {
    _selectedCalendarId = calendarId;
  }
  
  /// 캘린더 권한 요청
  Future<bool> requestPermission() async {
    try {
      var permissionsGranted = await _calendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && (permissionsGranted.data ?? false)) {
        return true;
      }
      
      permissionsGranted = await _calendarPlugin.requestPermissions();
      return permissionsGranted.isSuccess && (permissionsGranted.data ?? false);
    } catch (e) {
      return false;
    }
  }
  
  /// 권한 확인
  Future<bool> hasPermission() async {
    try {
      final result = await _calendarPlugin.hasPermissions();
      return result.isSuccess && (result.data ?? false);
    } catch (e) {
      return false;
    }
  }
  
  /// 사용 가능한 캘린더 목록 조회
  Future<List<Calendar>> getAvailableCalendars() async {
    try {
      final hasPerms = await requestPermission();
      if (!hasPerms) {
        return [];
      }
      
      final calendarsResult = await _calendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        // 쓰기 가능한 캘린더만 필터링
        return calendarsResult.data!
            .where((cal) => !(cal.isReadOnly ?? true))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// Receipt Ledger 전용 캘린더 찾기 또는 생성
  Future<String?> findOrCreateDedicatedCalendar() async {
    try {
      final calendars = await getAvailableCalendars();
      
      // 기존 Receipt Ledger 캘린더 찾기
      for (final cal in calendars) {
        if (cal.name == 'Receipt Ledger' || cal.name == '가계부') {
          return cal.id;
        }
      }
      
      // 새 캘린더 생성 시도 (일부 기기에서만 지원)
      // 대부분의 경우 기본 캘린더 사용 권장
      if (calendars.isNotEmpty) {
        return calendars.first.id;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// 거래 내역을 캘린더 이벤트로 변환
  Event _transactionToEvent(TransactionModel transaction, String calendarId) {
    final event = Event(calendarId);
    
    // 이벤트 제목 설정
    event.title = _formatEventTitle(transaction);
    
    // 종일 이벤트로 설정
    event.allDay = true;
    event.start = TZDateTime.from(
      DateTime(transaction.date.year, transaction.date.month, transaction.date.day),
      local,
    );
    event.end = TZDateTime.from(
      DateTime(transaction.date.year, transaction.date.month, transaction.date.day, 23, 59),
      local,
    );
    
    // 설명 추가
    final descriptionParts = <String>[];
    if (transaction.storeName != null && transaction.storeName!.isNotEmpty) {
      descriptionParts.add('상호: ${transaction.storeName}');
    }
    descriptionParts.add('카테고리: ${transaction.category}');
    descriptionParts.add('금액: ${Formatters.currency(transaction.amount)}');
    if (transaction.description.isNotEmpty) {
      descriptionParts.add('메모: ${transaction.description}');
    }
    event.description = descriptionParts.join('\n');
    
    // 상호명을 위치로 설정
    if (transaction.storeName != null && transaction.storeName!.isNotEmpty) {
      event.location = transaction.storeName;
    }
    
    return event;
  }
  
  /// 이벤트 제목 형식화
  String _formatEventTitle(TransactionModel transaction) {
    final amountStr = transaction.isIncome 
        ? '+${Formatters.currency(transaction.amount)}'
        : '-${Formatters.currency(transaction.amount)}';
    
    switch (_eventFormat) {
      case CalendarEventFormat.categoryAmount:
        return '[${transaction.category}] $amountStr';
      case CalendarEventFormat.storeAmount:
        final store = transaction.storeName ?? transaction.category;
        return '$store $amountStr';
      case CalendarEventFormat.description:
        final desc = transaction.description.isNotEmpty 
            ? transaction.description 
            : transaction.category;
        return '$desc $amountStr';
    }
  }
  
  /// 단일 거래 동기화
  /// 반환: 생성된 이벤트 ID (실패 시 null)
  Future<String?> syncTransaction(TransactionModel transaction) async {
    if (_selectedCalendarId == null) {
      return null;
    }
    
    try {
      final event = _transactionToEvent(transaction, _selectedCalendarId!);
      final result = await _calendarPlugin.createOrUpdateEvent(event);
      
      if (result?.isSuccess ?? false) {
        return result?.data;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
  
  /// 이벤트 업데이트
  Future<bool> updateEvent(String eventId, TransactionModel transaction) async {
    if (_selectedCalendarId == null) {
      return false;
    }
    
    try {
      final event = _transactionToEvent(transaction, _selectedCalendarId!);
      event.eventId = eventId;
      
      final result = await _calendarPlugin.createOrUpdateEvent(event);
      return result?.isSuccess ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// 이벤트 삭제
  Future<bool> deleteEvent(String eventId) async {
    if (_selectedCalendarId == null) {
      return false;
    }
    
    try {
      final result = await _calendarPlugin.deleteEvent(
        _selectedCalendarId!,
        eventId,
      );
      return result?.isSuccess ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// 월별 거래 일괄 동기화
  Future<CalendarSyncResult> syncMonthlyTransactions(
    List<TransactionModel> transactions,
  ) async {
    if (_selectedCalendarId == null) {
      return CalendarSyncResult(
        success: false,
        message: '캘린더가 선택되지 않았습니다',
      );
    }
    
    int synced = 0;
    int failed = 0;
    
    for (final transaction in transactions) {
      // 이미 동기화된 거래는 건너뛰기
      if (transaction.calendarEventId != null) {
        continue;
      }
      
      final eventId = await syncTransaction(transaction);
      if (eventId != null) {
        synced++;
      } else {
        failed++;
      }
      
      // 너무 빠른 API 호출 방지
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return CalendarSyncResult(
      success: failed == 0,
      synced: synced,
      failed: failed,
      message: synced > 0 ? '$synced개 항목 동기화 완료' : null,
    );
  }
  
  /// 모든 거래 일괄 동기화 (기간 지정)
  Future<CalendarSyncResult> syncAllTransactions(
    List<TransactionModel> transactions, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var filteredTransactions = transactions;
    
    if (startDate != null) {
      filteredTransactions = filteredTransactions
          .where((t) => t.date.isAfter(startDate) || t.date.isAtSameMomentAs(startDate))
          .toList();
    }
    
    if (endDate != null) {
      filteredTransactions = filteredTransactions
          .where((t) => t.date.isBefore(endDate) || t.date.isAtSameMomentAs(endDate))
          .toList();
    }
    
    return syncMonthlyTransactions(filteredTransactions);
  }
}
