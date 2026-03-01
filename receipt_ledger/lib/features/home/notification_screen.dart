import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

// ============================================================================
// Notification Model
// ============================================================================

enum NotificationType {
  budgetWarning,
  budgetExceeded,
  autoTransaction,
  syncComplete,
  system,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'title': title,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.values[json['type'] as int],
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

// ============================================================================
// Notification State Notifier
// ============================================================================

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  static const String _storageKey = 'app_notifications';

  NotificationNotifier() : super([]) {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        state = jsonList
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (_) {
        state = [];
      }
    }
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  Future<void> addNotification(AppNotification notification) async {
    state = [notification, ...state];
    await _saveNotifications();
  }

  Future<void> markAsRead(String id) async {
    state = state.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    await _saveNotifications();
  }

  Future<void> markAllAsRead() async {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    await _saveNotifications();
  }

  Future<void> deleteNotification(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _saveNotifications();
  }

  Future<void> clearAll() async {
    state = [];
    await _saveNotifications();
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

// ============================================================================
// Providers
// ============================================================================

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>((ref) {
  return NotificationNotifier();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationProvider);
  return notifications.where((n) => !n.isRead).length;
});

// ============================================================================
// Notification Screen
// ============================================================================

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, ref, isDark, notifications),
            // Content
            Expanded(
              child: notifications.isEmpty
                  ? _buildEmptyState(isDark)
                  : _buildNotificationList(context, ref, notifications, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isDark,
      List<AppNotification> notifications) {
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '알림',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              letterSpacing: -0.3,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.expense,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (notifications.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'read_all') {
                  ref
                      .read(notificationProvider.notifier)
                      .markAllAsRead();
                } else if (value == 'clear_all') {
                  _showClearAllDialog(context, ref);
                }
              },
              icon: Icon(
                Icons.more_horiz_rounded,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('모두 읽음 처리'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded,
                          size: 18, color: AppColors.expense),
                      SizedBox(width: 8),
                      Text('전체 삭제',
                          style: TextStyle(color: AppColors.expense)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '알림이 없습니다',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '예산 알림, 결제 자동 등록 등의\n알림이 여기에 표시됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildNotificationList(BuildContext context, WidgetRef ref,
      List<AppNotification> notifications, bool isDark) {
    // Group by date
    final Map<String, List<AppNotification>> grouped = {};
    for (final notification in notifications) {
      final key = _dateGroupKey(notification.createdAt);
      grouped.putIfAbsent(key, () => []).add(notification);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4, index == 0 ? 0 : 20, 4, 10),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
            ...entry.value.map((n) => _buildNotificationItem(
                context, ref, n, isDark)),
          ],
        );
      },
    );
  }

  Widget _buildNotificationItem(BuildContext context, WidgetRef ref,
      AppNotification notification, bool isDark) {
    final iconData = _getIconForType(notification.type);
    final iconColor = _getColorForType(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: AppColors.expense,
        ),
      ),
      onDismissed: (_) {
        ref
            .read(notificationProvider.notifier)
            .deleteNotification(notification.id);
      },
      child: GestureDetector(
        onTap: () {
          if (!notification.isRead) {
            ref
                .read(notificationProvider.notifier)
                .markAsRead(notification.id);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? (isDark ? AppColors.cardDark : AppColors.cardLight)
                : (isDark
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? (isDark
                      ? AppColors.borderDark.withValues(alpha: 0.5)
                      : AppColors.borderLight.withValues(alpha: 0.5))
                  : AppColors.primary.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.budgetWarning:
        return Icons.warning_amber_rounded;
      case NotificationType.budgetExceeded:
        return Icons.error_outline_rounded;
      case NotificationType.autoTransaction:
        return Icons.receipt_long_rounded;
      case NotificationType.syncComplete:
        return Icons.sync_rounded;
      case NotificationType.system:
        return Icons.info_outline_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.budgetWarning:
        return AppColors.warning;
      case NotificationType.budgetExceeded:
        return AppColors.expense;
      case NotificationType.autoTransaction:
        return AppColors.income;
      case NotificationType.syncComplete:
        return AppColors.accent;
      case NotificationType.system:
        return AppColors.primary;
    }
  }

  String _dateGroupKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateOnly).inDays;

    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    if (diff < 7) return '$diff일 전';
    return '${date.month}월 ${date.day}일';
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전체 삭제'),
        content: const Text('모든 알림을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(notificationProvider.notifier).clearAll();
              Navigator.pop(context);
            },
            child: const Text('삭제',
                style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}
