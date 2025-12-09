import 'package:rxdart/rxdart.dart';

import '../models/user_models.dart';
import 'api_client.dart';

/// Service for linking habits to goals and tracking their contribution
class HabitGoalLinkService {
  final ApiClient apiClient;

  // Stream controllers for reactive updates
  final _habitGoalLinksSubject = BehaviorSubject<List<HabitGoalLink>>();
  final _goalProgressSubject = BehaviorSubject<Map<String, double>>();
  final _linkedHabitsSubject = BehaviorSubject<Map<String, List<Habit>>>();

  HabitGoalLinkService({required this.apiClient});

  // Streams
  Stream<List<HabitGoalLink>> get habitGoalLinksStream =>
      _habitGoalLinksSubject.stream;
  Stream<Map<String, double>> get goalProgressStream =>
      _goalProgressSubject.stream;
  Stream<Map<String, List<Habit>>> get linkedHabitsStream =>
      _linkedHabitsSubject.stream;

  /// Load all habit-goal links for current user
  Future<List<HabitGoalLink>> loadHabitGoalLinks() async {
    try {
      final response = await apiClient.getJson('/user/habits-goals/links');
      final links = parseHabitGoalLinks(response['links'] as List<dynamic>);
      _habitGoalLinksSubject.add(links);
      return links;
    } catch (e) {
      print('Error loading habit-goal links: $e');
      return [];
    }
  }

  /// Create a link between a habit and a goal
  Future<HabitGoalLink?> linkHabitToGoal({
    required String habitId,
    required String goalId,
    required double contributionWeight,
  }) async {
    try {
      final response = await apiClient
          .postJson('/user/habits/$habitId/goals/$goalId/link', body: {
        'contribution_weight': contributionWeight,
      });

      final link = HabitGoalLink.fromJson(response);

      // Reload links
      await loadHabitGoalLinks();

      return link;
    } catch (e) {
      print('Error linking habit to goal: $e');
      return null;
    }
  }

  /// Remove link between habit and goal
  Future<bool> unlinkHabitFromGoal({
    required String habitId,
    required String goalId,
  }) async {
    try {
      await apiClient.deleteJson('/user/habits/$habitId/goals/$goalId/link');

      // Reload links
      await loadHabitGoalLinks();

      return true;
    } catch (e) {
      print('Error unlinking habit from goal: $e');
      return false;
    }
  }

  /// Get habits linked to a specific goal
  Future<List<Habit>> getHabitsForGoal(String goalId) async {
    try {
      final response =
          await apiClient.getJson('/user/goals/$goalId/linked-habits');
      final habits = parseHabits(response['habits'] as List<dynamic>);

      // Update linked habits map
      final currentMap = _linkedHabitsSubject.valueOrNull ?? {};
      currentMap[goalId] = habits;
      _linkedHabitsSubject.add(currentMap);

      return habits;
    } catch (e) {
      print('Error getting habits for goal: $e');
      return [];
    }
  }

  /// Get goals linked to a specific habit
  Future<List<UserGoal>> getGoalsForHabit(String habitId) async {
    try {
      final response =
          await apiClient.getJson('/user/habits/$habitId/linked-goals');
      return parseGoals(response['goals'] as List<dynamic>);
    } catch (e) {
      print('Error getting goals for habit: $e');
      return [];
    }
  }

  /// Update contribution weight of a link
  Future<HabitGoalLink?> updateLinkContribution({
    required String habitId,
    required String goalId,
    required double newWeight,
  }) async {
    try {
      final response = await apiClient.putJson(
        '/user/habits/$habitId/goals/$goalId/link',
        body: {'contribution_weight': newWeight},
      );

      final link = HabitGoalLink.fromJson(response);

      // Reload links
      await loadHabitGoalLinks();

      return link;
    } catch (e) {
      print('Error updating link contribution: $e');
      return null;
    }
  }

  /// Calculate how much a habit completion contributes to its linked goals
  Future<Map<String, double>> calculateHabitContribution(String habitId) async {
    try {
      final response = await apiClient.postJson(
        '/user/habits/$habitId/calculate-goal-contribution',
      );

      final contributions = Map<String, double>.from(
        response['goal_contributions'] as Map<String, dynamic>,
      );

      return contributions;
    } catch (e) {
      print('Error calculating habit contribution: $e');
      return {};
    }
  }

  /// Get goal progress considering linked habits
  Future<Map<String, dynamic>> getGoalProgressWithHabits(String goalId) async {
    try {
      final response = await apiClient.getJson('/user/goals/$goalId/progress');

      return {
        'goal_id': goalId,
        'progress_percentage': response['progress_percentage'] ?? 0.0,
        'from_tasks': response['task_progress'] ?? 0.0,
        'from_habits': response['habit_progress'] ?? 0.0,
        'trend': response['trend'] ?? 'steady',
        'on_track': response['on_track'] ?? false,
        'last_updated': response['last_updated'],
      };
    } catch (e) {
      print('Error getting goal progress: $e');
      return {};
    }
  }

  /// Sync all goals' progress considering their linked habits
  Future<void> syncAllGoalsProgress(List<String> goalIds) async {
    try {
      final progressMap = <String, double>{};

      for (final goalId in goalIds) {
        final progress = await getGoalProgressWithHabits(goalId);
        progressMap[goalId] =
            (progress['progress_percentage'] as num?)?.toDouble() ?? 0.0;
      }

      _goalProgressSubject.add(progressMap);
    } catch (e) {
      print('Error syncing goal progress: $e');
    }
  }

  /// Suggest habit-goal links based on category matching
  Future<List<Map<String, dynamic>>> suggestLinkings({
    required String habitId,
    required List<String> goalIds,
  }) async {
    try {
      final response = await apiClient.postJson(
        '/user/suggest-habit-goal-links',
        body: {
          'habit_id': habitId,
          'goal_ids': goalIds,
        },
      );

      final suggestions = List<Map<String, dynamic>>.from(
        response['suggestions'] as List<dynamic>,
      );

      return suggestions;
    } catch (e) {
      print('Error getting link suggestions: $e');
      return [];
    }
  }

  /// Get habit completion history for a goal
  Future<List<Map<String, dynamic>>> getHabitCompletionHistoryForGoal(
    String goalId, {
    int limit = 50,
  }) async {
    try {
      final response = await apiClient.getJson(
        '/user/goals/$goalId/habit-completions',
        query: {'limit': limit},
      );

      return List<Map<String, dynamic>>.from(
          response['completions'] as List<dynamic>);
    } catch (e) {
      print('Error getting habit completion history: $e');
      return [];
    }
  }

  /// Bulk link multiple habits to a goal
  Future<List<HabitGoalLink>> bulkLinkHabitsToGoal({
    required String goalId,
    required List<Map<String, dynamic>> habitLinks, // [{habitId, weight}]
  }) async {
    try {
      final response = await apiClient.postJson(
        '/user/goals/$goalId/bulk-link-habits',
        body: {'habit_links': habitLinks},
      );

      final links = parseHabitGoalLinks(response['links'] as List<dynamic>);

      // Reload links
      await loadHabitGoalLinks();

      return links;
    } catch (e) {
      print('Error bulk linking habits: $e');
      return [];
    }
  }

  /// Get analytics on habit-goal relationships
  Future<Map<String, dynamic>> getHabitGoalAnalytics() async {
    try {
      final response = await apiClient.getJson('/user/analytics/habits-goals');

      return {
        'total_links': response['total_links'] ?? 0,
        'habits_per_goal': response['habits_per_goal'] ?? {},
        'goals_per_habit': response['goals_per_habit'] ?? {},
        'total_habit_contribution': response['total_habit_contribution'] ?? 0.0,
        'average_link_effectiveness':
            response['average_link_effectiveness'] ?? 0.0,
      };
    } catch (e) {
      print('Error getting habit-goal analytics: $e');
      return {};
    }
  }

  /// Get current cached data
  List<HabitGoalLink> get currentLinks =>
      _habitGoalLinksSubject.valueOrNull ?? [];
  Map<String, double> get currentProgress =>
      _goalProgressSubject.valueOrNull ?? {};
  Map<String, List<Habit>> get currentLinkedHabits =>
      _linkedHabitsSubject.valueOrNull ?? {};

  /// Dispose resources
  Future<void> dispose() async {
    await _habitGoalLinksSubject.close();
    await _goalProgressSubject.close();
    await _linkedHabitsSubject.close();
  }
}
