import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant_models.dart';
import 'assistant_service.dart';
import 'notification_service.dart';
import 'workmanager_service.dart';

class NotificationTriageOutcome {
  const NotificationTriageOutcome({
    required this.total,
    required this.critical,
    this.summary,
  });

  final int total;
  final int critical;
  final String? summary;

  static const empty = NotificationTriageOutcome(total: 0, critical: 0);
}

/// Pulls buffered notifications from native listener, asks backend to classify
/// them, surfaces the summary locally, and schedules reminders for critical
/// items.
class NotificationTriageService {
  NotificationTriageService({
    required this.prefs,
    required this.notificationService,
    required this.assistantService,
  });

  final SharedPreferences prefs;
  final NotificationService notificationService;
  final AssistantService assistantService;

  Future<NotificationTriageOutcome> run({
    String mode = 'default',
    bool showSummaryNotification = true,
    bool scheduleCriticalReminders = true,
  }) async {
    final rawBuffer = prefs.getString('notif.buffer') ??
        prefs.getString('flutter.notif.buffer');
    if (rawBuffer == null || rawBuffer.isEmpty) {
      return NotificationTriageOutcome.empty;
    }

    List<dynamic> list = <dynamic>[];
    try {
      list = jsonDecode(rawBuffer) as List<dynamic>;
    } catch (_) {
      list = <dynamic>[];
    }
    if (list.isEmpty) {
      return NotificationTriageOutcome.empty;
    }

    final notifications =
        list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    try {
      final now = DateTime.now();
      final result = await assistantService.classifyNotifications(
        NotificationTriageRequest(
          notifications: notifications,
          mode: mode,
          timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
        ),
      );

      // Clear buffer only after successful classification to avoid data loss.
      await prefs.setString('notif.buffer', '[]');
      await prefs.setString('flutter.notif.buffer', '[]');

      final critical = result.classified
          .where(
            (c) =>
                c.category.toLowerCase() == 'critical' ||
                c.category.toLowerCase() == 'important',
          )
          .toList();

      if (showSummaryNotification) {
        final title = critical.isEmpty
            ? 'هیچ اعلان فوری پیدا نشد'
            : '${critical.length} اعلان مهم/فوری';
        final body = result.summary ??
            (critical.isNotEmpty
                ? critical.first.title
                : 'چیزی برای نمایش نیست');
        await notificationService.showLocalNow(
          title: title,
          body: body,
          payload: result.summary ?? result.rawText,
        );
      }

      if (scheduleCriticalReminders && critical.isNotEmpty) {
        for (final item in critical.take(5)) {
          final uniqueName =
              'hourly-reminder-${item.title.hashCode ^ DateTime.now().minute}';
          await WorkmanagerService.scheduleHourlyReminder(
            uniqueName: uniqueName,
            title: 'یادآوری اعلان مهم',
            body: item.title,
          );
        }
      }

      return NotificationTriageOutcome(
        total: notifications.length,
        critical: critical.length,
        summary: result.summary,
      );
    } catch (_) {
      // Leave buffer intact so it can be retried on next cycle.
      return NotificationTriageOutcome(
          total: notifications.length, critical: 0);
    }
  }
}
