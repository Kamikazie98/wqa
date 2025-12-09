import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/assistant_models.dart';
import 'api_client.dart';
import 'assistant_service.dart';
import 'notification_triage_service.dart';
import 'notification_service.dart';

class WorkmanagerService {
  WorkmanagerService._();

  static const reminderTask = 'waiq.reminder';
  static const followUpTask = 'waiq.follow_up';
  static const dailyBriefingTask = 'waiq.daily_briefing';
  static const nextActionTask = 'waiq.next_action';
  static const modeCheckTask = 'waiq.mode_check';
  static const notificationTriageTask = 'waiq.notification_triage';
  static const inboxIntelTask = 'waiq.inbox_intel';
  static const weeklyPlanTask = 'waiq.weekly_plan';
  static const usageIntelTask = 'waiq.usage_intel';
  static const hourlyReminderTask = 'waiq.hourly_reminder';
  static const selfCareReminderTask = 'waiq.selfcare_reminder';
  static const _pendingKey = 'workmanager.pending_jobs';
  static const _routineKey = 'automation.routines';

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    await _restorePendingTasks();
    await restoreRoutines();
  }

  static Future<void> scheduleReminder({
    required String title,
    required String body,
    required DateTime at,
    Map<String, dynamic>? payload,
  }) {
    final delay = at.difference(DateTime.now());
    final id = 'rem-${DateTime.now().millisecondsSinceEpoch}';
    _persistPendingTask(
      _PendingJob(
        id: id,
        task: reminderTask,
        at: at,
        title: title,
        body: body,
        payload: payload ?? <String, dynamic>{},
      ),
    );
    return Workmanager().registerOneOffTask(
      id,
      reminderTask,
      initialDelay: delay.isNegative ? Duration.zero : delay,
      inputData: {
        'id': id,
        'title': title,
        'body': body,
        'payload': jsonEncode(payload ?? <String, dynamic>{}),
      },
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
  }

  static Future<void> scheduleFollowUp({
    required String subject,
    required String task,
    required DateTime at,
    Map<String, dynamic>? payload,
  }) {
    final delay = at.difference(DateTime.now());
    final id = 'fu-${DateTime.now().millisecondsSinceEpoch}';
    _persistPendingTask(
      _PendingJob(
        id: id,
        task: followUpTask,
        at: at,
        title: 'پیگیری: $subject',
        body: task,
        payload: payload ?? <String, dynamic>{},
      ),
    );
    return Workmanager().registerOneOffTask(
      id,
      followUpTask,
      initialDelay: delay.isNegative ? Duration.zero : delay,
      inputData: {
        'id': id,
        'title': 'پیگیری: $subject',
        'body': task,
        'payload': jsonEncode(payload ?? <String, dynamic>{}),
      },
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
  }

  static Future<void> scheduleSelfCareReminders({
    required String profileName,
    required List<String> reminders,
    required int durationDays,
  }) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    if (durationDays <= 0) return;

    for (int day = 1; day <= durationDays; day++) {
      final reminderDate = now.add(Duration(days: day)).copyWith(
            hour: 9,
            minute: 0,
            second: 0,
            millisecond: 0,
            microsecond: 0,
          );

      final reminder = reminders.length > (day - 1)
          ? reminders[day - 1]
          : reminders.isNotEmpty
              ? reminders.last
              : 'خودمراقبتی یادآوری';

      final id =
          'sc-$profileName-day$day-${DateTime.now().millisecondsSinceEpoch}';
      _persistPendingTask(
        _PendingJob(
          id: id,
          task: selfCareReminderTask,
          at: reminderDate,
          title: 'خودمراقبتی: روز $day',
          body: reminder,
          payload: {
            'profile_name': profileName,
            'day': day,
            'total_days': durationDays,
          },
        ),
      );

      final delay = reminderDate.difference(now);
      await Workmanager().registerOneOffTask(
        id,
        selfCareReminderTask,
        initialDelay: delay.isNegative ? Duration.zero : delay,
        inputData: {
          'id': id,
          'title': 'خودمراقبتی: روز $day',
          'body': reminder,
          'profile_name': profileName,
          'day': day,
          'total_days': durationDays,
        },
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );
    }

    await prefs.setString(
      'selfcare.reminders.$profileName',
      jsonEncode({
        'profile_name': profileName,
        'reminders': reminders,
        'duration_days': durationDays,
        'started_at': now.toIso8601String(),
      }),
    );
  }

  static Future<void> scheduleDailyBriefing({DateTime? firstRun}) async {
    final now = DateTime.now();
    final target = firstRun ?? DateTime(now.year, now.month, now.day, 9);
    final next =
        target.isAfter(now) ? target : target.add(const Duration(days: 1));
    final delay = next.difference(now);

    await Workmanager().registerPeriodicTask(
      'daily-briefing',
      dailyBriefingTask,
      initialDelay: delay,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  static Future<void> scheduleNextAction({
    required int minutes,
    required String energy,
    required String mode,
  }) async {
    await Workmanager().registerPeriodicTask(
      'next-action',
      nextActionTask,
      initialDelay: const Duration(minutes: 5),
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      inputData: {
        'minutes': minutes,
        'energy': energy,
        'mode': mode,
      },
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  static Future<void> scheduleModeCheck({
    required String energy,
    required String mode,
    required String contextJson,
  }) async {
    await Workmanager().registerPeriodicTask(
      'mode-check',
      modeCheckTask,
      initialDelay: const Duration(minutes: 10),
      frequency: const Duration(hours: 2),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      inputData: {
        'energy': energy,
        'mode': mode,
        'context': contextJson,
      },
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 30),
    );
  }

  static Future<void> cancelNextAction() {
    return Workmanager().cancelByUniqueName('next-action');
  }

  static Future<void> cancelModeCheck() {
    return Workmanager().cancelByUniqueName('mode-check');
  }

  static Future<void> scheduleNotificationTriage() async {
    await Workmanager().registerPeriodicTask(
      'notif-triage',
      notificationTriageTask,
      initialDelay: const Duration(minutes: 15),
      frequency: const Duration(hours: 3),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 30),
    );
  }

  static Future<void> cancelNotificationTriage() {
    return Workmanager().cancelByUniqueName('notif-triage');
  }

  static Future<void> scheduleInboxIntel() async {
    await Workmanager().registerPeriodicTask(
      'inbox-intel',
      inboxIntelTask,
      initialDelay: const Duration(minutes: 20),
      frequency: const Duration(hours: 4),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 30),
    );
  }

  static Future<void> cancelInboxIntel() {
    return Workmanager().cancelByUniqueName('inbox-intel');
  }

  static Future<void> scheduleWeeklyPlan({
    required List<String> goals,
    required List<Map<String, dynamic>> hardEvents,
  }) async {
    await Workmanager().registerPeriodicTask(
      'weekly-plan',
      weeklyPlanTask,
      initialDelay: const Duration(hours: 1),
      frequency: const Duration(hours: 24), // اجرا روزانه
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      inputData: {
        'goals': jsonEncode(goals),
        'hardEvents': jsonEncode(hardEvents),
      },
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 30),
    );
  }

  static Future<void> cancelWeeklyPlan() {
    return Workmanager().cancelByUniqueName('weekly-plan');
  }

  /// Schedule reminders for a weekly plan list; keeps ids stable per start time.
  static Future<void> scheduleWeeklyPlanReminders(
    WeeklyScheduleResult result, {
    Duration leadTime = const Duration(minutes: 10),
    int maxItems = 20,
  }) async {
    final now = DateTime.now();
    final items = result.plan.take(maxItems);
    for (final item in items) {
      final start = _resolvePlanStart(item, now);
      if (start == null) continue;
      final reminderAt = start.subtract(leadTime);
      if (reminderAt.isBefore(DateTime.now())) continue;
      await scheduleReminder(
        title: 'یادآوری برنامه هفتگی',
        body: '${item.title} (${item.start}-${item.end})',
        at: reminderAt,
        payload: <String, dynamic>{
          'day': item.day,
          'start': item.start,
          'end': item.end,
          'title': item.title,
        },
      );
    }
  }

  static Future<void> scheduleUsageIntel({
    required String period, // daily or weekly
  }) async {
    final freq = period == 'weekly'
        ? const Duration(days: 7)
        : const Duration(hours: 24);
    await Workmanager().registerPeriodicTask(
      'usage-intel',
      usageIntelTask,
      initialDelay: const Duration(hours: 1),
      frequency: freq,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      inputData: {
        'period': period,
      },
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 30),
    );
  }

  static Future<void> cancelUsageIntel() {
    return Workmanager().cancelByUniqueName('usage-intel');
  }

  static Future<void> cancelReminder(String reminderId) {
    return Workmanager().cancelByUniqueName(reminderId);
  }

  static Future<void> scheduleHourlyReminder({
    required String uniqueName,
    required String title,
    required String body,
  }) async {
    await Workmanager().registerPeriodicTask(
      uniqueName,
      hourlyReminderTask,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      inputData: {
        'title': title,
        'body': body,
      },
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
  }

  static Future<void> scheduleRoutine({
    required String id,
    required String title,
    required String body,
    required DateTime at,
    Map<String, dynamic>? payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final routines = prefs.getStringList(_routineKey) ?? <String>[];
    final filtered = routines.where((item) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        return map['id']?.toString() != id;
      } catch (_) {
        return false;
      }
    }).toList();
    filtered.add(jsonEncode(<String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'at': at.toIso8601String(),
      'payload': payload ?? <String, dynamic>{},
    }));
    await prefs.setStringList(_routineKey, filtered);

    final delay = at.difference(DateTime.now());
    await Workmanager().registerOneOffTask(
      id,
      reminderTask,
      initialDelay: delay.isNegative ? Duration.zero : delay,
      inputData: {
        'id': id,
        'title': title,
        'body': body,
        'payload': jsonEncode(payload ?? <String, dynamic>{}),
      },
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
  }

  static Future<void> restoreRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final routines = prefs.getStringList(_routineKey) ?? <String>[];
    if (routines.isEmpty) return;
    for (final item in routines) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        final at = DateTime.tryParse(map['at']?.toString() ?? '');
        if (at == null || at.isBefore(DateTime.now())) continue;
        final delay = at.difference(DateTime.now());
        await Workmanager().registerOneOffTask(
          map['id']?.toString() ??
              'routine-${DateTime.now().millisecondsSinceEpoch}',
          reminderTask,
          initialDelay: delay.isNegative ? Duration.zero : delay,
          inputData: {
            'id': map['id']?.toString(),
            'title': map['title']?.toString() ?? 'روتین',
            'body': map['body']?.toString() ?? '',
            'payload': jsonEncode(map['payload'] ?? <String, dynamic>{}),
          },
          constraints: Constraints(
            networkType: NetworkType.notRequired,
          ),
        );
      } catch (_) {
        // ignore malformed
      }
    }
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    await NotificationService.initBackground();
    final notificationService = NotificationService();

    switch (taskName) {
      case WorkmanagerService.reminderTask:
      case WorkmanagerService.followUpTask:
      case WorkmanagerService.hourlyReminderTask:
        await _showFromInput(notificationService, inputData);
        return true;
      case WorkmanagerService.dailyBriefingTask:
        await _handleDailyBriefing(notificationService);
        return true;
      case WorkmanagerService.nextActionTask:
        await _handleNextAction(notificationService, inputData);
        return true;
      case WorkmanagerService.modeCheckTask:
        await _handleModeCheck(notificationService, inputData);
        return true;
      case WorkmanagerService.notificationTriageTask:
        await _handleNotificationTriage(notificationService);
        return true;
      case WorkmanagerService.inboxIntelTask:
        await _handleInboxIntel(notificationService);
        return true;
      case WorkmanagerService.weeklyPlanTask:
        await _handleWeeklyPlan(notificationService, inputData);
        return true;
      case WorkmanagerService.usageIntelTask:
        await _handleUsageIntel(notificationService, inputData);
        return true;
      default:
        await _showFromInput(notificationService, inputData);
        return true;
    }
  });
}

Future<void> _showFromInput(
  NotificationService notificationService,
  Map<String, dynamic>? input,
) async {
  final title = input?['title']?.toString() ?? 'یادآور';
  final body = input?['body']?.toString() ?? 'اقدام انجام شود';
  final id = input?['id']?.toString();
  if (id != null) {
    await _removePendingTask(id);
  }
  await notificationService.showLocalNow(
    title: title,
    body: body,
    payload: input?['payload']?.toString(),
  );
}

Future<void> _handleDailyBriefing(
  NotificationService notificationService,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken');
    if (token == null) {
      await notificationService.showLocalNow(
        title: 'خلاصه روز',
        body: 'لطفاً وارد حساب شوید',
      );
      return;
    }

    final apiClient = ApiClient(tokenProvider: () => token);
    final assistantService = AssistantService(apiClient: apiClient);
    final now = DateTime.now();

    final result = await assistantService.dailyBriefing(
      DailyBriefingRequest(
        timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
        now: now,
        context: <String, dynamic>{
          'week_start': 'saturday',
          'week_end': 'friday',
          'locale': 'fa-IR',
        },
      ),
    );
    // cache latest briefing for quick display
    await prefs.setString(
      'cache.daily_briefing',
      jsonEncode(result.payload.toJson()),
    );

    await notificationService.showLocalNow(
      title: 'خلاصه روز',
      body: result.payload.briefing.isEmpty
          ? 'گزارش امروز آماده شد'
          : result.payload.briefing,
      payload: result.rawText,
    );
  } catch (e) {
    await notificationService.showLocalNow(
      title: 'خلاصه روز',
      body: 'خطا در دریافت گزارش: $e',
    );
  }
}

Future<void> _handleNextAction(
  NotificationService notificationService,
  Map<String, dynamic>? input,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken');
    if (token == null) {
      return;
    }
    final minutes = input?['minutes'] as int? ?? 15;
    final energy = input?['energy']?.toString() ?? 'normal';
    final mode = input?['mode']?.toString() ?? 'default';
    final apiClient = ApiClient(tokenProvider: () => token);
    final assistantService = AssistantService(apiClient: apiClient);
    final result = await assistantService.nextAction(
      NextActionRequest(
        availableMinutes: minutes,
        energy: energy,
        mode: mode,
        tasks: const <dynamic>[],
      ),
    );
    final suggestion = result.suggested;
    await notificationService.showLocalNow(
      title: 'پیشنهاد سریع',
      body: suggestion.title.isEmpty
          ? 'کاری برای انجام پیشنهاد شد'
          : suggestion.title,
      payload: suggestion.reason,
    );
  } catch (e) {
    // Silent failure to avoid noisy background errors
  }
}

Future<void> _handleModeCheck(
  NotificationService notificationService,
  Map<String, dynamic>? input,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken');
    if (token == null) {
      return;
    }
    final energy = input?['energy']?.toString() ?? 'normal';
    final mode = input?['mode']?.toString() ?? 'default';
    final contextJson = input?['context']?.toString() ?? '{}';
    Map<String, dynamic> context = <String, dynamic>{};
    try {
      final decoded = jsonDecode(contextJson);
      if (decoded is Map<String, dynamic>) {
        context = decoded;
      }
    } catch (_) {
      context = <String, dynamic>{};
    }
    final now = DateTime.now();
    final apiClient = ApiClient(tokenProvider: () => token);
    final assistantService = AssistantService(apiClient: apiClient);
    final result = await assistantService.decideMode(
      ModeDecisionRequest(
        text: 'background_check',
        timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
        now: now,
        mode: mode,
        energy: energy,
        context: context,
      ),
    );
    await notificationService.showLocalNow(
      title: 'پیشنهاد مود',
      body: result.mode.isEmpty ? 'مود جدید پیشنهاد شد' : result.mode,
      payload: result.reason,
    );
  } catch (_) {
    // ignore
  }
}

Future<void> _handleNotificationTriage(
  NotificationService notificationService,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken');
    if (token == null) return;

    final apiClient = ApiClient(tokenProvider: () => token);
    final assistantService = AssistantService(apiClient: apiClient);
    final triageService = NotificationTriageService(
      prefs: prefs,
      notificationService: notificationService,
      assistantService: assistantService,
    );
    await triageService.run();
  } catch (_) {
    // silent
  }
}

Future<void> _handleInboxIntel(
  NotificationService notificationService,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken');
    if (token == null) return;

    final rawBuffer = prefs.getString('notif.buffer') ??
        prefs.getString('flutter.notif.buffer') ??
        '[]';
    List<dynamic> list = <dynamic>[];
    try {
      list = jsonDecode(rawBuffer) as List<dynamic>;
    } catch (_) {
      list = <dynamic>[];
    }
    if (list.isEmpty) return;
    await prefs.setString('notif.buffer', '[]');
    await prefs.setString('flutter.notif.buffer', '[]');

    final apiClient = ApiClient(tokenProvider: () => token);
    final assistantService = AssistantService(apiClient: apiClient);

    // فقط آخرین پیام را تحلیل می‌کنیم تا فراخوان کم باشد
    final latest = Map<String, dynamic>.from(list.last as Map);
    final message =
        latest['body']?.toString() ?? latest['title']?.toString() ?? '';
    if (message.isEmpty) return;

    final result = await assistantService.inboxIntel(
      InboxIntelRequest(
        message: message,
        channel: (latest['pkg']?.toString().isNotEmpty == true
            ? latest['pkg']!.toString()
            : 'notification'),
      ),
    );

    final action = result.actions.isNotEmpty ? result.actions.first : null;
    final body = action != null
        ? '${result.summary}\nپیشنهاد: ${action.type} - ${action.suggestedText}'
        : result.summary;
    await notificationService.showLocalNow(
      title: 'هوش پیام',
      body: body,
      payload: action?.suggestedText ?? result.rawText,
    );
  } catch (_) {
    // ignore
  }
}

Future<void> _handleWeeklyPlan(
  NotificationService notificationService,
  Map<String, dynamic>? input,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken');
    if (token == null) return;
    final goalsJson = input?['goals']?.toString() ?? '[]';
    final eventsJson = input?['hardEvents']?.toString() ?? '[]';
    final goals = List<String>.from(jsonDecode(goalsJson) as List<dynamic>);
    final hardEvents = (jsonDecode(eventsJson) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (goals.isEmpty && hardEvents.isEmpty) return;
    final apiClient = ApiClient(tokenProvider: () => token);
    final assistantService = AssistantService(apiClient: apiClient);
    final now = DateTime.now();
    final result = await assistantService.weeklySchedule(
      WeeklyScheduleRequest(
        goals: goals,
        hardEvents: hardEvents,
        timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
        now: now,
        context: <String, dynamic>{
          'week_start': 'saturday',
          'week_end': 'friday',
          'locale': 'fa-IR',
        },
      ),
    );
    await prefs.setString('cache.weekly_plan', jsonEncode(result.toJson()));
    await prefs.setString(
      'cache.weekly_plan_updated_at',
      DateTime.now().toIso8601String(),
    );

    await WorkmanagerService.scheduleWeeklyPlanReminders(result);

    final title = 'برنامه هفتگی جدید';
    final body = result.plan.isNotEmpty
        ? '${result.plan.length} آیتم زمان‌بندی شد'
        : 'برنامه ساخته شد';
    await notificationService.showLocalNow(
      title: title,
      body: body,
      payload: result.rawText,
    );
  } catch (_) {
    // silent
  }
}

Future<void> _handleUsageIntel(
  NotificationService notificationService,
  Map<String, dynamic>? input,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.accessToken');
    if (token == null) return;
    final apiClient = ApiClient(tokenProvider: () => token);
    final assistantService = AssistantService(apiClient: apiClient);

    // usage stats are collected on Android only, stored by NativeBridge usage call
    final raw = prefs.getString('flutter.usage.buffer') ?? '[]';
    List<dynamic> list = <dynamic>[];
    try {
      list = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      list = <dynamic>[];
    }
    if (list.isEmpty) return;
    await prefs.setString('flutter.usage.buffer', '[]');

    final message = list
        .take(10)
        .map((e) => '${e['package']}: ${e['minutes']} دقیقه')
        .join(' | ');
    final result = await assistantService.inboxIntel(
      InboxIntelRequest(
        message: 'مصرف اپ‌ها: $message',
        channel: input?['period']?.toString() ?? 'usage',
      ),
    );
    final action = result.actions.isNotEmpty ? result.actions.first : null;
    final body = action != null
        ? '${result.summary}\nپیشنهاد: ${action.type} - ${action.suggestedText}'
        : result.summary;
    await notificationService.showLocalNow(
      title: 'گزارش مصرف اپ',
      body: body,
      payload: action?.suggestedText ?? result.rawText,
    );
  } catch (_) {
    // ignore
  }
}

extension on DailyBriefingPayload {
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'briefing': briefing,
      'highlights': highlights,
      'next_actions': nextActions,
      'reminders': reminders,
      'tone': tone,
    };
  }
}

Future<void> _restorePendingTasks() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(WorkmanagerService._pendingKey) ?? <String>[];
  if (raw.isEmpty) return;
  for (final item in raw) {
    try {
      final map = jsonDecode(item) as Map<String, dynamic>;
      final job = _PendingJob.fromJson(map);
      if (job.at.isBefore(DateTime.now())) {
        continue;
      }
      final delay = job.at.difference(DateTime.now());
      await Workmanager().registerOneOffTask(
        job.id,
        job.task,
        initialDelay: delay.isNegative ? Duration.zero : delay,
        inputData: {
          'id': job.id,
          'title': job.title,
          'body': job.body,
          'payload': jsonEncode(job.payload),
        },
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );
    } catch (_) {
      // ignore malformed entries
    }
  }
}

DateTime? _resolvePlanStart(WeeklyPlanItem item, DateTime now) {
  // Map day names to DateTime.weekday (Monday=1 ... Sunday=7). Saturday=6.
  const dayMap = <String, int>{
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'شنبه': DateTime.saturday,
    'یکشنبه': DateTime.sunday,
    'دوشنبه': DateTime.monday,
    'سه\u200cشنبه': DateTime.tuesday,
    'چهارشنبه': DateTime.wednesday,
    'پنجشنبه': DateTime.thursday,
    'جمعه': DateTime.friday,
  };
  final dayKey = item.day.toLowerCase();
  final targetWeekday = dayMap[dayKey];
  if (targetWeekday == null) return null;

  final timeParts = item.start.split(':');
  if (timeParts.length < 2) return null;
  final hour = int.tryParse(timeParts[0]) ?? 0;
  final minute = int.tryParse(timeParts[1]) ?? 0;

  // Find next occurrence of target weekday (including today).
  var candidate = DateTime(now.year, now.month, now.day, hour, minute);
  while (candidate.weekday != targetWeekday || candidate.isBefore(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

Future<void> _persistPendingTask(_PendingJob job) async {
  final prefs = await SharedPreferences.getInstance();
  final existing =
      prefs.getStringList(WorkmanagerService._pendingKey) ?? <String>[];
  final filtered = existing.where((item) {
    try {
      final map = jsonDecode(item) as Map<String, dynamic>;
      return map['id']?.toString() != job.id;
    } catch (_) {
      return false;
    }
  }).toList();
  filtered.add(jsonEncode(job.toJson()));
  await prefs.setStringList(WorkmanagerService._pendingKey, filtered);
}

Future<void> _removePendingTask(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final existing =
      prefs.getStringList(WorkmanagerService._pendingKey) ?? <String>[];
  final filtered = existing.where((item) {
    try {
      final map = jsonDecode(item) as Map<String, dynamic>;
      return map['id']?.toString() != id;
    } catch (_) {
      return true;
    }
  }).toList();
  await prefs.setStringList(WorkmanagerService._pendingKey, filtered);
}

class _PendingJob {
  _PendingJob({
    required this.id,
    required this.task,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final String id;
  final String task;
  final DateTime at;
  final String title;
  final String body;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'task': task,
      'at': at.toIso8601String(),
      'title': title,
      'body': body,
      'payload': payload,
    };
  }

  factory _PendingJob.fromJson(Map<String, dynamic> json) {
    return _PendingJob(
      id: json['id']?.toString() ?? '',
      task: json['task']?.toString() ?? WorkmanagerService.reminderTask,
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      payload: Map<String, dynamic>.from(
          json['payload'] as Map? ?? <String, dynamic>{}),
    );
  }
}
