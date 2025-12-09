import 'package:rxdart/rxdart.dart';

import '../models/user_models.dart';
import 'api_client.dart';

/// Goal Management Service for WAIQ app
class GoalManagementService {
  final ApiClient apiClient;

  // Stream controllers
  final _goalsSubject = BehaviorSubject<List<UserGoal>>();
  final _milestonesSubject =
      BehaviorSubject<Map<String, List<GoalMilestone>>>();
  final _goalProgressSubject = BehaviorSubject<Map<String, GoalProgress>>();

  GoalManagementService({required this.apiClient});

  // Streams
  Stream<List<UserGoal>> get goalsStream => _goalsSubject.stream;
  Stream<Map<String, List<GoalMilestone>>> get milestonesStream =>
      _milestonesSubject.stream;
  Stream<Map<String, GoalProgress>> get goalProgressStream =>
      _goalProgressSubject.stream;

  /// Load all user goals
  Future<List<UserGoal>> loadGoals() async {
    try {
      final response = await apiClient.getJson('/user/goals');
      final goals = parseGoals(response['goals'] as List<dynamic>);
      _goalsSubject.add(goals);

      // Load milestones for each goal
      for (final goal in goals) {
        await _loadMilestonesForGoal(goal.goalId);
        await _loadGoalProgress(goal.goalId);
      }

      return goals;
    } catch (e) {
      print('Error loading goals: $e');
      return [];
    }
  }

  /// Load milestones for a specific goal
  Future<List<GoalMilestone>> _loadMilestonesForGoal(String goalId) async {
    try {
      final response =
          await apiClient.getJson('/user/goals/$goalId/milestones');
      final milestones =
          parseMilestones(response['milestones'] as List<dynamic>);

      final currentMap = _milestonesSubject.valueOrNull ?? {};
      currentMap[goalId] = milestones;
      _milestonesSubject.add(currentMap);

      return milestones;
    } catch (e) {
      print('Error loading milestones: $e');
      return [];
    }
  }

  /// Load goal progress
  Future<void> _loadGoalProgress(String goalId) async {
    try {
      final response = await apiClient.getJson('/user/goals/$goalId/progress');

      final progress = GoalProgress(
        goalId: goalId,
        progressPercentage: (response['progress_percentage'] as num).toDouble(),
        fromTasks: (response['task_progress'] as num?)?.toDouble() ?? 0.0,
        fromHabits: (response['habit_progress'] as num?)?.toDouble() ?? 0.0,
        trend: response['trend'] ?? 'steady',
        onTrack: response['on_track'] ?? false,
        lastUpdated: response['last_updated'] != null
            ? DateTime.parse(response['last_updated'])
            : DateTime.now(),
      );

      final currentMap = _goalProgressSubject.valueOrNull ?? {};
      currentMap[goalId] = progress;
      _goalProgressSubject.add(currentMap);
    } catch (e) {
      print('Error loading goal progress: $e');
    }
  }

  /// Create a new goal
  Future<UserGoal?> createGoal({
    required String title,
    required String category,
    required DateTime deadline,
    String? description,
    String priority = 'medium',
    List<Map<String, dynamic>>? milestones,
    List<String>? linkedTaskIds,
    List<String>? linkedHabitIds,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'category': category,
        'deadline': deadline.toIso8601String(),
        'priority': priority,
      };
      if (description != null) body['description'] = description;
      if (milestones != null) body['milestones'] = milestones;
      if (linkedTaskIds != null) body['linked_task_ids'] = linkedTaskIds;
      if (linkedHabitIds != null) body['linked_habit_ids'] = linkedHabitIds;

      final response = await apiClient.postJson('/user/goals', body: body);
      final goal = UserGoal.fromJson(response);

      // Update local cache
      final currentGoals = _goalsSubject.valueOrNull ?? [];
      currentGoals.add(goal);
      _goalsSubject.add(currentGoals);

      // Load progress for new goal
      await _loadGoalProgress(goal.goalId);

      return goal;
    } catch (e) {
      print('Error creating goal: $e');
      return null;
    }
  }

  /// Update a goal
  Future<UserGoal?> updateGoal(
    String goalId, {
    String? title,
    String? description,
    DateTime? deadline,
    String? priority,
    String? status,
    double? progressPercentage,
    List<Map<String, dynamic>>? milestones,
    List<String>? linkedTaskIds,
    List<String>? linkedHabitIds,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (deadline != null) body['deadline'] = deadline.toIso8601String();
      if (priority != null) body['priority'] = priority;
      if (status != null) body['status'] = status;
      if (progressPercentage != null)
        body['progress_percentage'] = progressPercentage;
      if (milestones != null) body['milestones'] = milestones;
      if (linkedTaskIds != null) body['linked_task_ids'] = linkedTaskIds;
      if (linkedHabitIds != null) body['linked_habit_ids'] = linkedHabitIds;

      final response =
          await apiClient.putJson('/user/goals/$goalId', body: body);
      final updatedGoal = UserGoal.fromJson(response);

      // Update local cache
      final currentGoals = _goalsSubject.valueOrNull ?? [];
      final index = currentGoals.indexWhere((g) => g.goalId == goalId);
      if (index != -1) {
        currentGoals[index] = updatedGoal;
      }
      _goalsSubject.add(currentGoals);

      // Reload progress
      await _loadGoalProgress(goalId);

      return updatedGoal;
    } catch (e) {
      print('Error updating goal: $e');
      return null;
    }
  }

  /// Delete (archive) a goal
  Future<bool> deleteGoal(String goalId) async {
    try {
      await apiClient.deleteJson('/user/goals/$goalId');

      // Update local cache
      final currentGoals = _goalsSubject.valueOrNull ?? [];
      currentGoals.removeWhere((g) => g.goalId == goalId);
      _goalsSubject.add(currentGoals);

      return true;
    } catch (e) {
      print('Error deleting goal: $e');
      return false;
    }
  }

  /// Get goal by ID
  Future<UserGoal?> getGoal(String goalId) async {
    try {
      final response = await apiClient.getJson('/user/goals/$goalId');
      return UserGoal.fromJson(response);
    } catch (e) {
      print('Error getting goal: $e');
      return null;
    }
  }

  /// Link a task to a goal
  Future<bool> linkTaskToGoal(String goalId, String taskId) async {
    try {
      await apiClient.postJson('/user/goals/$goalId/link-task', body: {
        'task_id': taskId,
      });

      // Reload progress
      await _loadGoalProgress(goalId);

      return true;
    } catch (e) {
      print('Error linking task to goal: $e');
      return false;
    }
  }

  /// Unlink a task from a goal
  Future<bool> unlinkTaskFromGoal(String goalId, String taskId) async {
    try {
      await apiClient.postJson('/user/goals/$goalId/unlink-task', body: {
        'task_id': taskId,
      });

      // Reload progress
      await _loadGoalProgress(goalId);

      return true;
    } catch (e) {
      print('Error unlinking task from goal: $e');
      return false;
    }
  }

  /// Add a milestone to a goal
  Future<GoalMilestone?> addMilestone(
    String goalId, {
    required String title,
    String? description,
    required DateTime targetDate,
    double progressContribution = 0.0,
  }) async {
    try {
      final response =
          await apiClient.postJson('/user/goals/$goalId/milestones', body: {
        'title': title,
        'description': description,
        'target_date': targetDate.toIso8601String(),
        'progress_contribution': progressContribution,
      });

      final milestone = GoalMilestone.fromJson(response);

      // Update local cache
      final currentMap = _milestonesSubject.valueOrNull ?? {};
      if (!currentMap.containsKey(goalId)) {
        currentMap[goalId] = [];
      }
      currentMap[goalId]!.add(milestone);
      _milestonesSubject.add(currentMap);

      // Reload goal progress
      await _loadGoalProgress(goalId);

      return milestone;
    } catch (e) {
      print('Error adding milestone: $e');
      return null;
    }
  }

  /// Update a milestone
  Future<GoalMilestone?> updateMilestone(
    String goalId,
    String milestoneId, {
    String? title,
    String? description,
    DateTime? targetDate,
    String? status,
    double? progressContribution,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (targetDate != null)
        body['target_date'] = targetDate.toIso8601String();
      if (status != null) body['status'] = status;
      if (progressContribution != null)
        body['progress_contribution'] = progressContribution;

      final response = await apiClient.putJson(
        '/user/goals/$goalId/milestones/$milestoneId',
        body: body,
      );

      final milestone = GoalMilestone.fromJson(response);

      // Update local cache
      final currentMap = _milestonesSubject.valueOrNull ?? {};
      if (currentMap.containsKey(goalId)) {
        final index =
            currentMap[goalId]!.indexWhere((m) => m.milestoneId == milestoneId);
        if (index != -1) {
          currentMap[goalId]![index] = milestone;
        }
      }
      _milestonesSubject.add(currentMap);

      // Reload goal progress
      await _loadGoalProgress(goalId);

      return milestone;
    } catch (e) {
      print('Error updating milestone: $e');
      return null;
    }
  }

  /// Get milestones for a goal
  Future<List<GoalMilestone>> getMilestones(String goalId) async {
    try {
      return (await _loadMilestonesForGoal(goalId));
    } catch (e) {
      print('Error getting milestones: $e');
      return [];
    }
  }

  /// Get goals grouped by status
  Future<Map<String, List<UserGoal>>> getGoalsByStatus() async {
    try {
      final goals = _goalsSubject.valueOrNull ?? [];

      return {
        'active': goals.where((g) => g.status == GoalStatus.active).toList(),
        'completed':
            goals.where((g) => g.status == GoalStatus.completed).toList(),
        'paused': goals.where((g) => g.status == GoalStatus.paused).toList(),
        'archived':
            goals.where((g) => g.status == GoalStatus.archived).toList(),
      };
    } catch (e) {
      print('Error getting goals by status: $e');
      return {};
    }
  }

  /// Get active goals
  Future<List<UserGoal>> getActiveGoals() async {
    try {
      final goals = _goalsSubject.valueOrNull ?? [];
      return goals.where((g) => g.status == GoalStatus.active).toList();
    } catch (e) {
      print('Error getting active goals: $e');
      return [];
    }
  }

  /// Get goals due soon (within days)
  Future<List<UserGoal>> getGoalsDueSoon({int days = 30}) async {
    try {
      final goals = _goalsSubject.valueOrNull ?? [];
      final deadline = DateTime.now().add(Duration(days: days));

      return goals
          .where((g) =>
              g.status == GoalStatus.active && g.deadline.isBefore(deadline))
          .toList();
    } catch (e) {
      print('Error getting goals due soon: $e');
      return [];
    }
  }

  /// Get goal progress trend history
  Future<List<Map<String, dynamic>>> getProgressHistory(String goalId,
      {int limit = 50}) async {
    try {
      final response = await apiClient.getJson(
        '/user/goals/$goalId/progress-history',
        query: {'limit': limit},
      );

      return List<Map<String, dynamic>>.from(
          response['history'] as List<dynamic>);
    } catch (e) {
      print('Error getting progress history: $e');
      return [];
    }
  }

  /// Get goal statistics
  Future<GoalStats?> getGoalStats() async {
    try {
      final response = await apiClient.getJson('/user/stats/goals');

      return GoalStats(
        totalGoals: response['total_goals'] ?? 0,
        activeGoals: response['active_goals'] ?? 0,
        completedGoals: response['completed_goals'] ?? 0,
        averageProgress:
            (response['average_progress'] as num?)?.toDouble() ?? 0.0,
        onTrackGoals: response['on_track_goals'] ?? 0,
        atRiskGoals: response['at_risk_goals'] ?? 0,
      );
    } catch (e) {
      print('Error getting goal stats: $e');
      return null;
    }
  }

  /// Suggest goals based on user profile
  Future<List<Map<String, dynamic>>> getSuggestedGoals() async {
    try {
      final response = await apiClient.getJson('/user/goals/suggestions');
      return List<Map<String, dynamic>>.from(
          response['suggestions'] as List<dynamic>);
    } catch (e) {
      print('Error getting goal suggestions: $e');
      return [];
    }
  }

  /// Get current cached data
  List<UserGoal> get currentGoals => _goalsSubject.valueOrNull ?? [];
  Map<String, List<GoalMilestone>> get currentMilestones =>
      _milestonesSubject.valueOrNull ?? {};
  Map<String, GoalProgress> get currentProgress =>
      _goalProgressSubject.valueOrNull ?? {};

  /// Dispose resources
  Future<void> dispose() async {
    await _goalsSubject.close();
    await _milestonesSubject.close();
    await _goalProgressSubject.close();
  }
}

/// Goal progress tracking model
class GoalProgress {
  final String goalId;
  final double progressPercentage;
  final double fromTasks;
  final double fromHabits;
  final String trend; // increasing, steady, decreasing
  final bool onTrack;
  final DateTime lastUpdated;

  GoalProgress({
    required this.goalId,
    required this.progressPercentage,
    required this.fromTasks,
    required this.fromHabits,
    required this.trend,
    required this.onTrack,
    required this.lastUpdated,
  });
}

/// Goal statistics model
class GoalStats {
  final int totalGoals;
  final int activeGoals;
  final int completedGoals;
  final double averageProgress;
  final int onTrackGoals;
  final int atRiskGoals;

  GoalStats({
    required this.totalGoals,
    required this.activeGoals,
    required this.completedGoals,
    required this.averageProgress,
    required this.onTrackGoals,
    required this.atRiskGoals,
  });
}
