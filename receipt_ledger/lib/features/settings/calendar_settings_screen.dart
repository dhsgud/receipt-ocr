import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/calendar_sync_service.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

/// 캘린더 동기화 서비스 Provider
final calendarSyncServiceProvider = Provider<CalendarSyncService>((ref) {
  return CalendarSyncService();
});

/// 사용 가능한 캘린더 목록 Provider
final availableCalendarsProvider = FutureProvider<List<Calendar>>((ref) async {
  final service = ref.watch(calendarSyncServiceProvider);
  return await service.getAvailableCalendars();
});

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() => _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends ConsumerState<CalendarSettingsScreen> {
  bool _isSyncing = false;
  String? _syncMessage;
  CalendarEventFormat _eventFormat = CalendarEventFormat.categoryAmount;
  
  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(calendarSyncEnabledProvider);
    final selectedCalendarId = ref.watch(selectedCalendarIdProvider);
    final calendarsAsync = ref.watch(availableCalendarsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더 연동'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 캘린더 연동 활성화 토글
          StyledCard(
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: AppColors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '캘린더 동기화',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '거래 내역을 캘린더에 자동 추가',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // 권한 요청
                      final service = ref.read(calendarSyncServiceProvider);
                      final hasPermission = await service.requestPermission();
                      if (!hasPermission) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('캘린더 권한이 필요합니다'),
                              backgroundColor: AppColors.expense,
                            ),
                          );
                        }
                        return;
                      }
                      // 캘린더 목록 새로고침
                      ref.invalidate(availableCalendarsProvider);
                    }
                    ref.read(calendarSyncEnabledProvider.notifier).state = value;
                  },
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // 캘린더 선택 (활성화된 경우에만 표시)
          if (isEnabled) ...[
            const Text(
              '연동할 캘린더',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            calendarsAsync.when(
              data: (calendars) {
                if (calendars.isEmpty) {
                  return StyledCard(
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '사용 가능한 캘린더가 없습니다',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '기기에 캘린더 계정을 추가해주세요',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return StyledCard(
                  child: Column(
                    children: calendars.map((calendar) {
                      final isSelected = selectedCalendarId == calendar.id;
                      return RadioListTile<String>(
                        value: calendar.id!,
                        groupValue: selectedCalendarId,
                        onChanged: (value) {
                          ref.read(selectedCalendarIdProvider.notifier).state = value;
                          final service = ref.read(calendarSyncServiceProvider);
                          service.setSelectedCalendar(value);
                        },
                        title: Text(
                          calendar.name ?? '알 수 없는 캘린더',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          calendar.accountName ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        secondary: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Color(calendar.color ?? 0xFF4285F4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => StyledCard(
                child: Row(
                  children: [
                    const Icon(Icons.error, color: AppColors.expense),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '캘린더를 불러오는 중 오류가 발생했습니다: $error',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 이벤트 형식 설정
            const Text(
              '이벤트 제목 형식',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            StyledCard(
              child: Column(
                children: [
                  _buildFormatRadio(
                    CalendarEventFormat.categoryAmount,
                    _eventFormat,
                    '[카테고리] 금액',
                    '예: [식비] -15,000원',
                  ),
                  _buildFormatRadio(
                    CalendarEventFormat.storeAmount,
                    _eventFormat,
                    '상호명 금액',
                    '예: 스타벅스 -5,500원',
                  ),
                  _buildFormatRadio(
                    CalendarEventFormat.description,
                    _eventFormat,
                    '설명',
                    '예: 점심 식사 -15,000원',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 동기화 버튼
            const Text(
              '데이터 동기화',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: selectedCalendarId != null && !_isSyncing
                    ? () => _syncAllTransactions()
                    : null,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync, color: Colors.white),
                label: Text(
                  _isSyncing ? '동기화 중...' : '과거 내역 동기화',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_syncMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _syncMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: _syncMessage!.contains('실패') 
                      ? AppColors.expense 
                      : AppColors.income,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            
            // 안내 메시지
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '동기화 안내',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• 새로운 거래가 추가되면 자동으로 캘린더에 등록됩니다\n'
                          '• 거래 삭제 시 캘린더 이벤트도 함께 삭제됩니다\n'
                          '• 캘린더 앱에서 직접 이벤트를 수정해도 앱에는 반영되지 않습니다',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFormatRadio(
    CalendarEventFormat value,
    CalendarEventFormat groupValue,
    String title,
    String example,
  ) {
    return RadioListTile<CalendarEventFormat>(
      value: value,
      groupValue: groupValue,
      onChanged: (newValue) {
        if (newValue != null) {
          setState(() {
            _eventFormat = newValue;
          });
          final service = ref.read(calendarSyncServiceProvider);
          service.eventFormat = newValue;
        }
      },
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(example, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
  
  Future<void> _syncAllTransactions() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });
    
    try {
      final service = ref.read(calendarSyncServiceProvider);
      final selectedId = ref.read(selectedCalendarIdProvider);
      
      if (selectedId == null) {
        setState(() {
          _syncMessage = '캘린더를 선택해주세요';
        });
        return;
      }
      
      service.setSelectedCalendar(selectedId);
      
      // 거래 내역 가져오기
      final transactionsAsync = ref.read(transactionsProvider);
      final transactions = transactionsAsync.valueOrNull ?? [];
      
      if (transactions.isEmpty) {
        setState(() {
          _syncMessage = '동기화할 거래 내역이 없습니다';
        });
        return;
      }
      
      // 동기화 실행
      final result = await service.syncMonthlyTransactions(transactions);
      
      setState(() {
        if (result.success) {
          _syncMessage = '${result.synced}개 항목 동기화 완료!';
        } else {
          _syncMessage = '동기화 실패: ${result.message ?? "알 수 없는 오류"}';
        }
      });
    } catch (e) {
      setState(() {
        _syncMessage = '동기화 실패: $e';
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }
}
