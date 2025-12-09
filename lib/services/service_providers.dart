import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_models.dart';
import 'api_client.dart';
import 'daily_program_optimizer_service.dart';
import 'goal_management_service.dart';
import 'habit_goal_link_service.dart';
import 'location_reminder_service.dart';
import 'notification_service.dart';
import 'notification_summarizer_service.dart';
import 'notification_summary_notifier.dart';
import 'task_management_service.dart';

// کانال نیتیو پیام‌ها (MessageReader در MainActivity)
const _messagesChannel = MethodChannel('native/messages');

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  // این در زمان init اپ override می‌شود
  throw UnimplementedError('apiClientProvider must be overridden');
});

// Notification Service Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('notificationServiceProvider must be overridden');
});

// Location Reminder Service Provider
final locationReminderServiceProvider =
    Provider<LocationReminderService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return LocationReminderService(
    apiClient: apiClient,
    notificationService: notificationService,
  );
});

// Habit-Goal Link Service Provider
final habitGoalLinkServiceProvider = Provider<HabitGoalLinkService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HabitGoalLinkService(apiClient: apiClient);
});

// Task Management Service Provider
final taskManagementServiceProvider = Provider<TaskManagementService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TaskManagementService(apiClient: apiClient);
});

// Goal Management Service Provider
final goalManagementServiceProvider = Provider<GoalManagementService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GoalManagementService(apiClient: apiClient);
});

// Daily Program Optimizer Service Provider
final dailyProgramOptimizerServiceProvider =
    Provider<DailyProgramOptimizerService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DailyProgramOptimizerService(apiClient: apiClient);
});

// Stream Providers

// Tasks Stream
final tasksStreamProvider =
    StreamProvider.autoDispose<List<UserTask>>((ref) async* {
  final taskService = ref.watch(taskManagementServiceProvider);

  // Load initial tasks
  await taskService.loadTasks();

  // Emit from stream
  yield* taskService.tasksStream;
});

// Goals Stream
final goalsStreamProvider =
    StreamProvider.autoDispose<List<UserGoal>>((ref) async* {
  final goalService = ref.watch(goalManagementServiceProvider);

  // Load initial goals
  await goalService.loadGoals();

  // Emit from stream
  yield* goalService.goalsStream;
});

// Task Stats Stream
final taskStatsStreamProvider =
    StreamProvider.autoDispose<TaskStats>((ref) async* {
  final taskService = ref.watch(taskManagementServiceProvider);
  yield* taskService.statsStream;
});

// Goal Progress Stream
final goalProgressStreamProvider =
    StreamProvider.autoDispose<Map<String, GoalProgress>>((ref) async* {
  final goalService = ref.watch(goalManagementServiceProvider);
  yield* goalService.goalProgressStream;
});

// Daily Program Stream
final dailyProgramStreamProvider =
    StreamProvider.autoDispose<DailyProgram?>((ref) async* {
  final programService = ref.watch(dailyProgramOptimizerServiceProvider);
  yield* programService.dailyProgramStream;
});

// Habit-Goal Links Stream
final habitGoalLinksStreamProvider =
    StreamProvider.autoDispose<List<HabitGoalLink>>((ref) async* {
  final linkService = ref.watch(habitGoalLinkServiceProvider);
  yield* linkService.habitGoalLinksStream;
});

// Location Reminders Stream (geofences)
final activeGeofencesStreamProvider =
    FutureProvider.autoDispose<List<GeoFence>>((ref) async {
  final locationService = ref.watch(locationReminderServiceProvider);
  return await locationService.getActiveGeofences();
});

// Overdue Tasks Provider
final overdueTasksProvider =
    FutureProvider.autoDispose<List<UserTask>>((ref) async {
  final taskService = ref.watch(taskManagementServiceProvider);
  return await taskService.getOverdueTasks();
});

// Today's Tasks Provider
final todayTasksProvider =
    FutureProvider.autoDispose<List<UserTask>>((ref) async {
  final taskService = ref.watch(taskManagementServiceProvider);
  return await taskService.getTasksDueToday();
});

// Active Goals Provider
final activeGoalsProvider =
    FutureProvider.autoDispose<List<UserGoal>>((ref) async {
  final goalService = ref.watch(goalManagementServiceProvider);
  return await goalService.getActiveGoals();
});

// Today's Program Provider
final todayProgramProvider =
    FutureProvider.autoDispose<DailyProgram?>((ref) async {
  final programService = ref.watch(dailyProgramOptimizerServiceProvider);
  return await programService.getTodayProgram();
});

// Goal Statistics Provider
final goalStatsProvider = FutureProvider.autoDispose<GoalStats?>((ref) async {
  final goalService = ref.watch(goalManagementServiceProvider);
  return await goalService.getGoalStats();
});

// Current Location Provider
final currentLocationProvider =
    FutureProvider.autoDispose<Position?>((ref) async {
  final locationService = ref.watch(locationReminderServiceProvider);
  return await locationService.getCurrentLocation();
});

// Nearby Geofences Provider
final nearbyGeofencesProvider =
    FutureProvider.autoDispose<List<GeoFence>>((ref) async {
  final locationService = ref.watch(locationReminderServiceProvider);
  return await locationService.getNearbyGeofences();
});

// State Notifier for managing task filters
final taskFiltersProvider = StateProvider<TaskFilters>((ref) {
  return TaskFilters.empty();
});

// State Notifier for managing goal filters
final goalFiltersProvider =
    StateNotifierProvider<GoalFilterNotifier, Map<String, dynamic>>((ref) {
  return GoalFilterNotifier();
});

class GoalFilterNotifier extends StateNotifier<Map<String, dynamic>> {
  GoalFilterNotifier()
      : super({
          'status': null,
          'daysUntilDeadline': null,
          'sortBy': 'deadline',
        });

  void setStatus(String? status) {
    state = {...state, 'status': status};
  }

  void setDaysFilter(int? days) {
    state = {...state, 'daysUntilDeadline': days};
  }

  void setSortBy(String sortBy) {
    state = {...state, 'sortBy': sortBy};
  }

  void reset() {
    state = {
      'status': null,
      'daysUntilDeadline': null,
      'sortBy': 'deadline',
    };
  }
}

// Notification Summarizer Service Provider - with safe fallback
final notificationSummarizerServiceProvider =
    Provider<NotificationSummarizerService>((ref) {
  try {
    final apiClient = ref.watch(apiClientProvider);
    return NotificationSummarizerService(apiClient: apiClient);
  } catch (e) {
    // Fallback: Return a dummy service if apiClient is not available
    print(
        'Warning: apiClientProvider not initialized, using fallback NotificationSummarizerService');
    return NotificationSummarizerService(
      apiClient: ApiClient(tokenProvider: () => ''),
    );
  }
});

// Notification Summary Stream
final notificationSummaryStreamProvider =
    StreamProvider.autoDispose<NotificationSummary?>((ref) async* {
  final summarizerService = ref.watch(notificationSummarizerServiceProvider);
  yield* summarizerService.summaryStream;
});

// Important Messages Stream
final importantMessagesStreamProvider =
    StreamProvider.autoDispose<List<ImportantMessage>>((ref) async* {
  final summarizerService = ref.watch(notificationSummarizerServiceProvider);
  yield* summarizerService.importantMessagesStream;
});

// Critical Alerts Stream
final criticalAlertsStreamProvider =
    StreamProvider.autoDispose<List<CriticalAlert>>((ref) async* {
  final summarizerService = ref.watch(notificationSummarizerServiceProvider);
  yield* summarizerService.criticalAlertsStream;
});

// Notification Stats Stream
final notificationStatsStreamProvider =
    StreamProvider.autoDispose<SummaryStats?>((ref) async* {
  final summarizerService = ref.watch(notificationSummarizerServiceProvider);
  yield* summarizerService.statsStream;
});

/// ✅ TODAY SUMMARY از نوتیف‌های لوکال (notif.buffer) + پیام‌ها (native/messages)
/// خروجی را به /notifications/summarize می‌فرستد و NotificationSummary برمی‌گرداند
final todaySummaryProvider =
    FutureProvider.autoDispose<NotificationSummary?>((ref) async {
  try {
    final summarizerService = ref.watch(notificationSummarizerServiceProvider);

    // ۱) نوتیف‌ها از SharedPreferences (notif.buffer)
    final prefs = await SharedPreferences.getInstance();
    final rawNotif = prefs.getString('notif.buffer') ?? '[]';

    List<Map<String, dynamic>> notifications = [];
    try {
      final decoded = jsonDecode(rawNotif);
      if (decoded is List) {
        notifications = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      print('[todaySummaryProvider] Error parsing notif.buffer: $e');
      notifications = [];
    }

    // ۲) پیام‌ها از نیتیو (MessageReader) – اگر نخواهی، می‌توانی خالی بذاری
    final messages = await _loadMessagesFromNative(limit: 100);

    // اگر هیچ دیتایی نداریم، خلاصه‌ی خالی برگردون
    if (notifications.isEmpty && messages.isEmpty) {
      return NotificationSummary(
        summaryId: 'empty-${DateTime.now().toIso8601String()}',
        totalNotifications: 0,
        readCount: 0,
        unreadCount: 0,
        importantMessages: [],
        criticalAlerts: [],
        actionItems: [],
        aiGeneratedSummary: null,
        sentimentScore: 0.0,
        dominantTopic: '',
        keyPeople: [],
        generatedAt: DateTime.now(),
      );
    }

    // ۳) ارسال به /notifications/summarize
    final summary = await summarizerService.generateSummary(
      notifications: notifications,
      messages: messages,
      hoursBack: 24,
    );

    return summary;
  } catch (e, stackTrace) {
    print('Error getting today summary (local): $e\n$stackTrace');
    return null;
  }
});

// Notification Trends Provider
final notificationTrendsProvider =
    FutureProvider.autoDispose<NotificationTrends?>((ref) async {
  final summarizerService = ref.watch(notificationSummarizerServiceProvider);
  return await summarizerService.getNotificationTrends();
});

/// Ai Summary → Local Notification Pusher
final aiSummaryNotificationPusherProvider =
    Provider<AiSummaryNotificationPusher>((ref) {
  final summarizer = ref.watch(notificationSummarizerServiceProvider);
  final notifService = ref.watch(notificationServiceProvider);

  return AiSummaryNotificationPusher(
    summarizer: summarizer,
    notificationService: notifService,
  );
});

/// helper برای خواندن پیام‌ها از native/messages
Future<List<Map<String, dynamic>>> _loadMessagesFromNative(
    {int limit = 100}) async {
  try {
    final dynamic result =
        await _messagesChannel.invokeMethod('getAllMessages', limit);

    if (result is List) {
      return result
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  } catch (e) {
    print('[todaySummaryProvider] Error loading messages from native: $e');
    return [];
  }
}
