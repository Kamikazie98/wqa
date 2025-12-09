import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';

import 'api_client.dart';
import 'notification_service.dart';
import 'location_reminder_service.dart';
import 'habit_goal_link_service.dart';
import 'task_management_service.dart';
import 'goal_management_service.dart';
import 'daily_program_optimizer_service.dart';
import 'service_providers.dart';

/// Service Initialization Container
/// Manages all service initialization and lifecycle
class ServiceContainer {
  static late ApiClient _apiClient;
  static late NotificationService _notificationService;
  static late LocationReminderService _locationReminderService;
  static late HabitGoalLinkService _habitGoalLinkService;
  static late TaskManagementService _taskManagementService;
  static late GoalManagementService _goalManagementService;
  static late DailyProgramOptimizerService _dailyProgramOptimizerService;

  // Private constructor
  ServiceContainer._();

  /// Initialize all services
  /// Call this in main.dart before running the app
  static Future<void> initialize({
    required String Function() tokenProvider,
  }) async {
    debugPrint('🚀 Initializing WAIQ Services...');

    try {
      // Initialize API Client
      _apiClient = ApiClient(tokenProvider: tokenProvider);
      debugPrint('✓ API Client initialized');

      // Initialize Notification Service
      _notificationService = NotificationService();
      await _notificationService.init();
      debugPrint('✓ Notification Service initialized');

      // Initialize Location Reminder Service
      _locationReminderService = LocationReminderService(
        apiClient: _apiClient,
        notificationService: _notificationService,
      );
      debugPrint('✓ Location Reminder Service initialized');

      // Initialize Habit-Goal Link Service
      _habitGoalLinkService = HabitGoalLinkService(apiClient: _apiClient);
      debugPrint('✓ Habit-Goal Link Service initialized');

      // Initialize Task Management Service
      _taskManagementService = TaskManagementService(apiClient: _apiClient);
      await _taskManagementService.loadTasks();
      debugPrint('✓ Task Management Service initialized');

      // Initialize Goal Management Service
      _goalManagementService = GoalManagementService(apiClient: _apiClient);
      await _goalManagementService.loadGoals();
      debugPrint('✓ Goal Management Service initialized');

      // Initialize Daily Program Optimizer Service
      _dailyProgramOptimizerService =
          DailyProgramOptimizerService(apiClient: _apiClient);
      debugPrint('✓ Daily Program Optimizer Service initialized');

      debugPrint('✅ All WAIQ Services initialized successfully!');
    } catch (e) {
      debugPrint('❌ Error initializing services: $e');
      rethrow;
    }
  }

  /// Start background services
  static Future<void> startBackgroundServices() async {
    debugPrint('📍 Starting background services...');

    try {
      // Start location monitoring
      await _locationReminderService.startLocationMonitoring();
      debugPrint('✓ Location monitoring started');

      // Load habit-goal links
      await _habitGoalLinkService.loadHabitGoalLinks();
      debugPrint('✓ Habit-goal links loaded');

      debugPrint('✅ Background services started');
    } catch (e) {
      debugPrint('⚠️ Error starting background services: $e');
    }
  }

  /// Stop background services
  static Future<void> stopBackgroundServices() async {
    debugPrint('🛑 Stopping background services...');

    try {
      await _locationReminderService.stopLocationMonitoring();
      debugPrint('✓ Location monitoring stopped');
    } catch (e) {
      debugPrint('⚠️ Error stopping background services: $e');
    }
  }

  /// Dispose all services
  static Future<void> dispose() async {
    debugPrint('🧹 Disposing services...');

    try {
      await _locationReminderService.dispose();
      await _habitGoalLinkService.dispose();
      await _taskManagementService.dispose();
      await _goalManagementService.dispose();
      await _dailyProgramOptimizerService.dispose();
      debugPrint('✅ All services disposed');
    } catch (e) {
      debugPrint('⚠️ Error disposing services: $e');
    }
  }

  // Getters
  static ApiClient get apiClient => _apiClient;
  static NotificationService get notificationService => _notificationService;
  static LocationReminderService get locationReminderService =>
      _locationReminderService;
  static HabitGoalLinkService get habitGoalLinkService => _habitGoalLinkService;
  static TaskManagementService get taskManagementService =>
      _taskManagementService;
  static GoalManagementService get goalManagementService =>
      _goalManagementService;
  static DailyProgramOptimizerService get dailyProgramOptimizerService =>
      _dailyProgramOptimizerService;
}

/// Service Provider Override Helper
/// Used in ProviderContainer to override default providers with initialized instances
class ServiceProviderOverrides {
  static List<Override> getOverrides() {
    return [
      apiClientProvider.overrideWithValue(ServiceContainer.apiClient),
      notificationServiceProvider
          .overrideWithValue(ServiceContainer.notificationService),
      locationReminderServiceProvider
          .overrideWithValue(ServiceContainer.locationReminderService),
      habitGoalLinkServiceProvider
          .overrideWithValue(ServiceContainer.habitGoalLinkService),
      taskManagementServiceProvider
          .overrideWithValue(ServiceContainer.taskManagementService),
      goalManagementServiceProvider
          .overrideWithValue(ServiceContainer.goalManagementService),
      dailyProgramOptimizerServiceProvider
          .overrideWithValue(ServiceContainer.dailyProgramOptimizerService),
    ];
  }
}
