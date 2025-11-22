import 'dart:math' as math;

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:marib/data/repositories/notifications_repository_repository.dart';
import 'package:marib/ui/screens/chat/chat_badge_controller.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/hive_keys.dart';
import 'package:marib/utils/hive_utils.dart';

class UnreadNotificationsCubit extends Cubit<int> {
  UnreadNotificationsCubit(this._repository) : super(0);

  static const int _badgeNotificationId = 900001;
  static const Duration _reminderInterval = Duration(hours: 12);
  static const String _reminderKey =
      '_unread_notifications_last_reminder_at';
  final NotificationsRepository _repository;

  Future<void> refresh({bool silent = false}) async {
    if (!HiveUtils.isUserAuthenticated()) {
      emit(0);
      _syncAppBadge(0);
      return;
    }
    if (!silent) {
      emit(state);
    }
    try {
      final int count = await _repository.fetchUnreadCount();
      final int normalized = math.max(0, count);
      emit(normalized);
      _syncAppBadge(normalized);
    } catch (_) {}
  }

  void setCount(int value) {
    final int normalized = math.max(0, value);
    emit(normalized);
    _syncAppBadge(normalized);
  }

  void decrement(int amount) {
    final int normalized = math.max(0, state - amount);
    emit(normalized);
    _syncAppBadge(normalized);
  }

  void clear() {
    emit(0);
    _syncAppBadge(0);
  }

  void _syncAppBadge(int count) {
    ChatBadgeController.updateNotificationBadge(count);
    _syncPersistentNotification(count);
  }

  void _syncPersistentNotification(int count) {
    try {
      if (count <= 0) {
        AwesomeNotifications().cancel(_badgeNotificationId);
        _clearReminderTimestamp();
        return;
      }
      if (!_shouldTriggerReminder()) {
        return;
      }
      AwesomeNotifications().cancel(_badgeNotificationId);
      _saveReminderTimestamp();
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _badgeNotificationId,
          channelKey: Constant.notificationChannel,
          title: count == 1
              ? 'لديك إشعار لم تتم قراءته'
              : 'لديك $count إشعارات لم تتم قراءتها',
          body: 'إذا فاتك شيء، افتح صندوق الإشعارات للاطلاع عليه.',
          autoDismissible: true,
          locked: false,
          wakeUpScreen: false,
          badge: count.clamp(1, 9999),
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          groupKey: 'inbox_badge_summary',
        ),
      );
    } catch (_) {}
  }

  bool _shouldTriggerReminder() {
    final DateTime? lastReminder = _loadReminderTimestamp();
    if (lastReminder == null) {
      return true;
    }
    final Duration sinceLast = DateTime.now().toUtc().difference(lastReminder);
    return sinceLast >= _reminderInterval;
  }

  DateTime? _loadReminderTimestamp() {
    try {
      final box = Hive.box(HiveKeys.userDetailsBox);
      final dynamic raw = box.get(_reminderKey);
      if (raw is String) {
        return DateTime.tryParse(raw);
      }
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveReminderTimestamp() async {
    try {
      final box = Hive.box(HiveKeys.userDetailsBox);
      await box.put(_reminderKey, DateTime.now().toUtc().toIso8601String());
    } catch (_) {}
  }

  Future<void> _clearReminderTimestamp() async {
    try {
      final box = Hive.box(HiveKeys.userDetailsBox);
      await box.delete(_reminderKey);
    } catch (_) {}
  }
}
