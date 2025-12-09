import 'package:flutter/foundation.dart';
import '../models/user_models.dart';
import 'api_client.dart';
import 'exceptions.dart';

class UserProfileService extends ChangeNotifier {
  UserProfileService({required this.apiClient});

  final ApiClient apiClient;

  UserProfile? _profile;
  List<UserGoal> _goals = [];
  List<Habit> _habits = [];
  List<MoodSnapshot> _moodHistory = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  UserProfile? get profile => _profile;
  List<UserGoal> get goals => _goals;
  List<Habit> get habits => _habits;
  List<MoodSnapshot> get moodHistory => _moodHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _profile != null;

  /// Tries to load the existing profile without throwing an error if it's not found.
  Future<void> loadProfileIfExists() async {
    await getProfile();
  }

  // ═══════════════════════════════════════════════════════════════════
  // PROFILE METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// Setup user profile during onboarding
  Future<UserProfile> setupProfile({
    required String name,
    required String role,
    required String timezone,
    required List<String> interests,
    String? wakeUpTime,
    String? sleepTime,
    String? focusHours,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await apiClient.postJson(
        '/user/profile/setup',
        body: {
          'name': name,
          'role': role,
          'timezone': timezone,
          'interests': interests,
          'wake_up_time': int.tryParse(wakeUpTime ?? '6') ?? 6,
          'sleep_time': int.tryParse(sleepTime ?? '23') ?? 23,
          'focus_hours': int.tryParse(focusHours ?? '4') ?? 4,
        },
        authRequired: true,
      );

      _profile = UserProfile.fromJson(response);
      _isLoading = false;
      notifyListeners();
      return _profile!;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get current user profile
  Future<UserProfile?> getProfile() async {
    if (_isLoading) return _profile; // Prevent concurrent calls
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await apiClient.getJson(
        '/user/profile',
        authRequired: true,
      );

      print('[UserProfileService] Raw profile response: $response');

      _profile = UserProfile.fromJson(response);
      _isLoading = false;
      notifyListeners();
      return _profile!;
    } on ApiException catch (e) {
      _isLoading = false;
      _profile = null; // Ensure profile is null on error
      if (e.statusCode == 404) {
        // This is expected if the user has no profile yet.
        _error = null;
        print('[UserProfileService] No profile found for user (404).');
      } else {
        _error = e.message;
        print('[UserProfileService] Error loading profile: ${e.message}');
      }
      notifyListeners();
      // Don't rethrow - return null instead
      return null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _profile = null; // Ensure profile is null on error
      notifyListeners();
      print('[UserProfileService] Unexpected error: $e');
      return null;
    }
  }

  /// Update user profile
  Future<UserProfile> updateProfile({
    String? name,
    String? timezone,
    List<String>? interests,
    int? preferredBreakDuration,
    bool? enableMotivation,
    String? communicationStyle,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (timezone != null) body['timezone'] = timezone;
      if (interests != null) body['interests'] = interests;
      if (preferredBreakDuration != null) {
        body['preferred_break_duration'] = preferredBreakDuration;
      }
      if (enableMotivation != null)
        body['enable_motivation'] = enableMotivation;
      if (communicationStyle != null)
        body['communication_style'] = communicationStyle;

      final response = await apiClient.put(
        '/user/profile/update',
        body: body,
        authRequired: true,
      );

      _profile = UserProfile.fromJson(response);
      _isLoading = false;
      notifyListeners();
      return _profile!;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // GOALS METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// Create a new goal
  Future<UserGoal> createGoal({
    required String title,
    required String category,
    String? description,
    required DateTime deadline,
    required String priority,
    List<String>? milestones,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await apiClient.postJson(
        '/user/goals',
        body: {
          'title': title,
          'category': category,
          'description': description,
          'deadline': deadline.toIso8601String(),
          'priority': priority,
          'milestones': milestones,
        },
        authRequired: true,
      );

      final goal = UserGoal.fromJson(response);
      _goals.add(goal);
      _isLoading = false;
      notifyListeners();
      return goal;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get all user goals
  Future<List<UserGoal>> getGoals() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await apiClient.getJson(
        '/user/goals',
        authRequired: true,
      );

      final goalsList = response['goals'] as List<dynamic>? ?? [];
      _goals = goalsList
          .map((goal) => UserGoal.fromJson(goal as Map<String, dynamic>))
          .toList();
      _isLoading = false;
      notifyListeners();
      return _goals;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update goal progress
  Future<UserGoal> updateGoal(
    String goalId, {
    double? progressPercentage,
    String? status,
    List<String>? milestones,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (progressPercentage != null)
        body['progress_percentage'] = progressPercentage;
      if (status != null) body['status'] = status;
      if (milestones != null) body['milestones'] = milestones;

      final response = await apiClient.put(
        '/user/goals/$goalId',
        body: body,
        authRequired: true,
      );

      final updatedGoal = UserGoal.fromJson(response);
      final index = _goals.indexWhere((g) => g.goalId == goalId);
      if (index != -1) {
        _goals[index] = updatedGoal;
      }
      notifyListeners();
      return updatedGoal;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Mark goal as completed
  Future<void> completeGoal(String goalId) async {
    try {
      await apiClient.postJson(
        '/user/goals/$goalId/complete',
        authRequired: true,
      );

      final index = _goals.indexWhere((g) => g.goalId == goalId);
      if (index != -1) {
        _goals[index] = _goals[index].copyWith(
          status: GoalStatus.completed,
          progressPercentage: 100.0,
          completedAt: DateTime.now(),
        );
      }
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Delete/archive goal
  Future<void> deleteGoal(String goalId) async {
    try {
      await apiClient.delete(
        '/user/goals/$goalId',
        authRequired: true,
      );

      _goals.removeWhere((g) => g.goalId == goalId);
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MOOD METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// Record mood snapshot
  Future<MoodSnapshot> recordMood({
    required double energy,
    required double mood,
    String? context,
    String? activity,
    String? notes,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await apiClient.postJson(
        '/user/mood/snapshot',
        body: {
          'energy': energy,
          'mood': mood,
          'context': context,
          'activity': activity,
          'notes': notes,
        },
        authRequired: true,
      );

      final snapshot = MoodSnapshot.fromJson(response);
      _moodHistory.insert(0, snapshot);

      // Update profile averages if profile exists
      if (_profile != null) {
        _profile = _profile!.copyWith(
          avgEnergy: energy,
          avgMood: mood,
        );
      }

      _isLoading = false;
      notifyListeners();
      return snapshot;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get mood history
  Future<List<MoodSnapshot>> getMoodHistory({int last = 30}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await apiClient.getJson(
        '/user/mood/history',
        query: {'last': last},
        authRequired: true,
      );

      final snapshotsList = response['snapshots'] as List<dynamic>? ?? [];
      _moodHistory = snapshotsList
          .map((snap) => MoodSnapshot.fromJson(snap as Map<String, dynamic>))
          .toList();
      _isLoading = false;
      notifyListeners();
      return _moodHistory;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HABIT METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// Create a new habit
  Future<Habit> createHabit({
    required String name,
    required String category,
    String? description,
    required String frequency,
    required int targetCount,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await apiClient.postJson(
        '/habits',
        body: {
          'name': name,
          'category': category,
          'description': description,
          'frequency': frequency,
          'target_count': targetCount,
        },
        authRequired: true,
      );

      final habit = Habit.fromJson(response);
      _habits.add(habit);
      _isLoading = false;
      notifyListeners();
      return habit;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get all habits
  Future<List<Habit>> getHabits() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await apiClient.getJson(
        '/habits',
        authRequired: true,
      );

      final habitsList = response['habits'] as List<dynamic>? ?? [];
      _habits = habitsList
          .map((habit) => Habit.fromJson(habit as Map<String, dynamic>))
          .toList();
      _isLoading = false;
      notifyListeners();
      return _habits;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get specific habit
  Future<Habit> getHabit(String habitId) async {
    try {
      final response = await apiClient.getJson(
        '/habits/$habitId',
        authRequired: true,
      );

      return Habit.fromJson(response);
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Log habit completion
  Future<void> logHabitCompletion({
    required String habitId,
    required DateTime date,
    required bool completed,
    String? notes,
  }) async {
    try {
      await apiClient.postJson(
        '/habits/$habitId/log',
        body: {
          'date': date.toIso8601String(),
          'completed': completed,
          'notes': notes,
        },
        authRequired: true,
      );

      // Update local habit if found
      final index = _habits.indexWhere((h) => h.habitId == habitId);
      if (index != -1) {
        final habit = _habits[index];
        if (completed) {
          _habits[index] = habit.copyWith(
            totalCompletions: habit.totalCompletions + 1,
            currentStreak: habit.currentStreak + 1,
          );
        } else {
          _habits[index] = habit.copyWith(currentStreak: 0);
        }
      }

      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Update habit
  Future<Habit> updateHabit(
    String habitId, {
    String? name,
    String? description,
    bool? isActive,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (isActive != null) body['is_active'] = isActive;

      final response = await apiClient.put(
        '/habits/$habitId',
        body: body,
        authRequired: true,
      );

      final updatedHabit = Habit.fromJson(response);
      final index = _habits.indexWhere((h) => h.habitId == habitId);
      if (index != -1) {
        _habits[index] = updatedHabit;
      }
      notifyListeners();
      return updatedHabit;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Delete/archive habit
  Future<void> deleteHabit(String habitId) async {
    try {
      await apiClient.delete(
        '/habits/$habitId',
        authRequired: true,
      );

      _habits.removeWhere((h) => h.habitId == habitId);
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// Clear all cached data
  void clearAll() {
    _profile = null;
    _goals = [];
    _habits = [];
    _moodHistory = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Get goals by category
  List<UserGoal> getGoalsByCategory(String category) {
    return _goals.where((g) => g.category == category).toList();
  }

  /// Get active goals
  List<UserGoal> getActiveGoals() {
    return _goals.where((g) => g.isActive).toList();
  }

  /// Get overdue goals
  List<UserGoal> getOverdueGoals() {
    return _goals.where((g) => g.isOverdue).toList();
  }

  /// Get active habits
  List<Habit> getActiveHabits() {
    return _habits.where((h) => h.isActive).toList();
  }

  /// Calculate overall mood trend (1-10)
  double getMoodAverage() {
    if (_moodHistory.isEmpty) return 5.0;
    final sum = _moodHistory.fold<double>(0, (sum, snap) => sum + snap.mood);
    return sum / _moodHistory.length;
  }

  /// Calculate overall energy trend (1-10)
  double getEnergyAverage() {
    if (_moodHistory.isEmpty) return 5.0;
    final sum = _moodHistory.fold<double>(0, (sum, snap) => sum + snap.energy);
    return sum / _moodHistory.length;
  }
}
