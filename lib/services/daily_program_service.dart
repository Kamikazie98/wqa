import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/user_models.dart';
import '../models/daily_program_models.dart';
import 'api_client.dart';
import 'exceptions.dart';

/// Daily program service
class DailyProgramService extends ChangeNotifier {
  DailyProgramService({required this.apiClient});

  final ApiClient apiClient;

  DailyProgram? _todayProgram;
  Map<String, DailyProgram> _programCache = {};
  List<ProgramActivity> _completedActivities = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  DailyProgram? get todayProgram => _todayProgram;
  Map<String, DailyProgram> get programCache => _programCache;
  List<ProgramActivity> get completedActivities => _completedActivities;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasTodayProgram => _todayProgram != null;

  /// Generate daily program
  Future<DailyProgram> generateDailyProgram({
    required UserProfile profile,
    required List<UserGoal> goals,
    required List<Habit> habits,
    required double currentMood,
    required double currentEnergy,
    DateTime? date,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      date ??= DateTime.now();
      final dateKey = '${date.year}-${date.month}-${date.day}';

      // 1. Attempt to generate program via API
      try {
        final program = await apiClient.generateDailyProgram(
          profile: profile,
          goals: goals,
          habits: habits,
          currentMood: currentMood,
          currentEnergy: currentEnergy,
          date: date,
        );

        // Cache and set the program
        _programCache[dateKey] = program;
        if (date.year == DateTime.now().year &&
            date.month == DateTime.now().month &&
            date.day == DateTime.now().day) {
          _todayProgram = program;
        }

        _isLoading = false;
        notifyListeners();
        return program;
      } catch (e) {
        // If API fails, fallback to local generation
        print('API program generation failed: $e. Falling back to local.');
        return _generateLocalProgram(profile, goals, habits, currentMood, currentEnergy, date);
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Fallback to generate program locally
  Future<DailyProgram> _generateLocalProgram(
    UserProfile profile,
    List<UserGoal> goals,
    List<Habit> habits,
    double currentMood,
    double currentEnergy,
    DateTime date,
  ) {
    final program = DailyProgramGenerator.generateProgram(
      userId: profile.userId,
      profile: profile,
      goals: goals,
      habits: habits,
      currentMood: currentMood,
      currentEnergy: currentEnergy,
      date: date,
    );

    final dateKey = '${date.year}-${date.month}-${date.day}';
    _programCache[dateKey] = program;
    if (date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day) {
      _todayProgram = program;
    }

    return Future.value(program);
  }

  /// Get program for specific date
  Future<DailyProgram?> getProgramForDate(DateTime date) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final dateKey = '${date.year}-${date.month}-${date.day}';

      // Check cache first
      if (_programCache.containsKey(dateKey)) {
        _isLoading = false;
        notifyListeners();
        return _programCache[dateKey];
      }

      // Fetch from API
      final response = await apiClient.getJson(
        '/user/program/$dateKey',
        authRequired: true,
      );

      if (response.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final program = DailyProgram.fromJson(response);
      _programCache[dateKey] = program;

      _isLoading = false;
      notifyListeners();
      return program;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Edit activity in today's program
  Future<void> editActivity({
    required String activityId,
    required String title,
    String? description,
  }) async {
    try {
      await apiClient.put(
        '/user/program/activity/$activityId',
        body: {
          'title': title,
          'description': description,
        },
        authRequired: true,
      );

      // Update local activity
      final activity = _todayProgram?.activities.firstWhere(
        (a) => a.id == activityId,
        orElse: () => null as dynamic,
      );

      if (activity != null) {
        final index = _todayProgram!.activities.indexOf(activity);
        final updated = activity.copyWith(
          title: title,
          description: description,
        );
        _todayProgram!.activities[index] = updated;
        notifyListeners();
      }
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Get next upcoming activity
  ProgramActivity? getNextActivity() {
    if (_todayProgram == null) return null;

    final now = DateTime.now();
    final sorted = _todayProgram!.sortedActivities;

    for (final activity in sorted) {
      if (activity.endTime.isAfter(now)) {
        return activity;
      }
    }

    return null;
  }

  /// Get current activity
  ProgramActivity? getCurrentActivity() {
    if (_todayProgram == null) return null;

    final now = DateTime.now();

    for (final activity in _todayProgram!.activities) {
      if (activity.startTime.isBefore(now) && activity.endTime.isAfter(now)) {
        return activity;
      }
    }

    return null;
  }

  /// Log activity completion
  Future<void> completeActivity({
    required String activityId,
    required bool completed,
    String? notes,
    double? actualDuration,
  }) async {
    try {
      await apiClient.postJson(
        '/user/program/activity/$activityId/complete',
        body: {
          'completed': completed,
          'notes': notes,
          'actual_duration': actualDuration,
        },
        authRequired: true,
      );

      // Update local state
      final activity = _todayProgram?.activities
          .firstWhere((a) => a.id == activityId, orElse: () => null as dynamic);

      if (activity != null && completed) {
        _completedActivities.add(activity);
      }

      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Get program statistics for today
  Map<String, dynamic> getTodayStats() {
    if (_todayProgram == null) {
      return {
        'total_activities': 0,
        'completed_activities': 0,
        'total_focus_time': 0,
        'total_break_time': 0,
        'expected_productivity': 0,
        'completion_percentage': 0,
      };
    }

    final now = DateTime.now();
    final completedCount =
        _todayProgram!.activities.where((a) => a.endTime.isBefore(now)).length;

    return {
      'total_activities': _todayProgram!.activities.length,
      'completed_activities': completedCount,
      'total_focus_time': _todayProgram!.totalFocusTime.inMinutes,
      'total_break_time': _todayProgram!.totalBreakTime.inMinutes,
      'expected_productivity': _todayProgram!.expectedProductivity ?? 0,
      'expected_mood': _todayProgram!.expectedMood ?? 0,
      'focus_theme': _todayProgram!.focusTheme,
      'completion_percentage':
          (completedCount / _todayProgram!.activities.length * 100)
              .clamp(0, 100),
    };
  }

  /// Reschedule activity to different time
  Future<void> rescheduleActivity({
    required String activityId,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async {
    try {
      await apiClient.put(
        '/user/program/activity/$activityId/reschedule',
        body: {
          'new_start_time': newStartTime.toIso8601String(),
          'new_end_time': newEndTime.toIso8601String(),
        },
        authRequired: true,
      );

      // Update local activity
      final activity = _todayProgram?.activities.firstWhere(
        (a) => a.id == activityId,
        orElse: () => null as dynamic,
      );

      if (activity != null) {
        final index = _todayProgram!.activities.indexOf(activity);
        // Create new activity with updated time
        final updated = ProgramActivity(
          id: activity.id,
          title: activity.title,
          description: activity.description,
          startTime: newStartTime,
          endTime: newEndTime,
          category: activity.category,
          priority: activity.priority,
          relatedGoalId: activity.relatedGoalId,
          relatedHabitId: activity.relatedHabitId,
          energyRequired: activity.energyRequired,
          moodBenefits: activity.moodBenefits,
          isFlexible: activity.isFlexible,
          order: activity.order,
        );
        _todayProgram!.activities[index] = updated;
      }

      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Add custom activity to today's program
  Future<ProgramActivity> addCustomActivity({
    required String title,
    required String category,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String? priority,
  }) async {
    try {
      final activity = ProgramActivity(
        id: _generateId(),
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        category: category,
        priority: priority ?? 'medium',
        isFlexible: true,
      );

      // Save to backend
      await apiClient.postJson(
        '/user/program/activity/add',
        body: activity.toJson(),
        authRequired: true,
      );

      // Add to local program
      _todayProgram?.activities.add(activity);
      notifyListeners();

      return activity;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Remove activity from program
  Future<void> removeActivity(String activityId) async {
    try {
      await apiClient.delete(
        '/user/program/activity/$activityId',
        authRequired: true,
      );

      _todayProgram?.activities.removeWhere((a) => a.id == activityId);
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Get activities for specific category
  List<ProgramActivity> getActivitiesByCategory(String category) {
    if (_todayProgram == null) return [];
    return _todayProgram!.getActivitiesByCategory(category);
  }

  /// Get high priority tasks
  List<ProgramActivity> getHighPriorityTasks() {
    if (_todayProgram == null) return [];
    return _todayProgram!.highPriorityTasks;
  }

  /// Clear cache
  void clearCache() {
    _programCache.clear();
    _completedActivities.clear();
    _todayProgram = null;
    notifyListeners();
  }

  /// Export program to JSON
  String? exportProgramAsJson() {
    if (_todayProgram == null) return null;
    return _todayProgram!.toJson().toString();
  }

  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();
}

/// Timer for current activity
class ActivityTimer extends ChangeNotifier {
  final ProgramActivity activity;
  late Timer _timer;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  bool _isPaused = false;

  ActivityTimer({required this.activity});

  // Getters
  Duration get elapsed => _elapsed;
  Duration get remaining => activity.duration - _elapsed;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  double get progress => _elapsed.inSeconds / activity.duration.inSeconds;
  int get percentageComplete => (progress * 100).toInt();

  /// Start timer
  void start() {
    if (_isRunning) return;

    _isRunning = true;
    _isPaused = false;
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      _elapsed += Duration(seconds: 1);

      if (_elapsed >= activity.duration) {
        _timer.cancel();
        _isRunning = false;
      }
      notifyListeners();
    });
  }

  /// Pause timer
  void pause() {
    if (!_isRunning) return;
    _timer.cancel();
    _isRunning = false;
    _isPaused = true;
    notifyListeners();
  }

  /// Resume timer
  void resume() {
    if (_isRunning || !_isPaused) return;
    _isPaused = false;
    start();
  }

  /// Stop timer and reset
  void stop() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    _isRunning = false;
    _isPaused = false;
    _elapsed = Duration.zero;
    notifyListeners();
  }

  /// Add extra time
  void addExtra(Duration duration) {
    if (_isRunning) {
      _timer.cancel();
    }
    _elapsed = Duration.zero;
    _isRunning = false;
    _isPaused = false;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    super.dispose();
  }
}
