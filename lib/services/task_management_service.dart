import 'package:rxdart/rxdart.dart';

import '../models/user_models.dart';
import 'api_client.dart';

/// Task Management Service for WAIQ app
class TaskManagementService {
  final ApiClient apiClient;

  // Stream controllers for reactive updates
  final _tasksSubject = BehaviorSubject<List<UserTask>>();
  final _taskStatsSubject = BehaviorSubject<TaskStats>();
  final _taskFiltersSubject = BehaviorSubject<TaskFilters>();

  TaskManagementService({required this.apiClient});

  // Streams
  Stream<List<UserTask>> get tasksStream => _tasksSubject.stream;
  Stream<TaskStats> get statsStream => _taskStatsSubject.stream;
  Stream<TaskFilters> get filtersStream => _taskFiltersSubject.stream;

  /// Load all tasks with optional filters
  Future<List<UserTask>> loadTasks({
    String? status,
    String? category,
    DateTime? dueBefore,
    DateTime? dueAfter,
    bool sortByDueDate = true,
    bool sortByPriority = false,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (status != null) query['status'] = status;
      if (category != null) query['category'] = category;
      if (dueBefore != null) query['due_before'] = dueBefore.toIso8601String();
      if (dueAfter != null) query['due_after'] = dueAfter.toIso8601String();
      if (sortByDueDate) query['sort_by'] = 'due_date';
      if (sortByPriority) query['sort_by'] = 'priority';

      final response = await apiClient.getJson('/tasks', query: query);
      final tasks = parseTasks(response['tasks'] as List<dynamic>);

      _tasksSubject.add(tasks);
      await _calculateStats(tasks);

      return tasks;
    } catch (e) {
      print('Error loading tasks: $e');
      return [];
    }
  }

  /// Create a new task
  Future<UserTask?> createTask({
    required String title,
    required String category,
    String? description,
    DateTime? dueDate,
    int priority = 3,
    int? estimatedDurationMinutes,
    String? location,
    String? linkedGoalId,
    List<String> subtasks = const [],
    List<String> tags = const [],
  }) async {
    try {
      final response = await apiClient.postJson('/tasks', body: {
        'title': title,
        'category': category,
        'description': description,
        'due_date': dueDate?.toIso8601String(),
        'priority': priority,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'location': location,
        'linked_goal_id': linkedGoalId,
        'subtasks':
            subtasks.map((s) => {'title': s, 'completed': false}).toList(),
        'tags': tags,
      });

      final task = UserTask.fromJson(response);

      // Update local cache
      final currentTasks = _tasksSubject.valueOrNull ?? [];
      currentTasks.add(task);
      _tasksSubject.add(currentTasks);
      await _calculateStats(currentTasks);

      return task;
    } catch (e) {
      print('Error creating task: $e');
      return null;
    }
  }

  /// Update an existing task
  Future<UserTask?> updateTask(
    String taskId, {
    String? title,
    String? description,
    String? status,
    int? priority,
    DateTime? dueDate,
    int? estimatedDurationMinutes,
    String? location,
    List<String>? subtasks,
    List<String>? tags,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (status != null) body['status'] = status;
      if (priority != null) body['priority'] = priority;
      if (dueDate != null) body['due_date'] = dueDate.toIso8601String();
      if (estimatedDurationMinutes != null)
        body['estimated_duration_minutes'] = estimatedDurationMinutes;
      if (location != null) body['location'] = location;
      if (subtasks != null) body['subtasks'] = subtasks;
      if (tags != null) body['tags'] = tags;

      final response = await apiClient.putJson('/tasks/$taskId', body: body);
      final updatedTask = UserTask.fromJson(response);

      // Update local cache
      final currentTasks = _tasksSubject.valueOrNull ?? [];
      final index = currentTasks.indexWhere((t) => t.taskId == taskId);
      if (index != -1) {
        currentTasks[index] = updatedTask;
      }
      _tasksSubject.add(currentTasks);
      await _calculateStats(currentTasks);

      return updatedTask;
    } catch (e) {
      print('Error updating task: $e');
      return null;
    }
  }

  /// Mark task as completed
  Future<UserTask?> completeTask(String taskId) async {
    try {
      final response = await apiClient.postJson('/tasks/$taskId/complete');
      final completedTask = UserTask.fromJson(response);

      // Update local cache
      final currentTasks = _tasksSubject.valueOrNull ?? [];
      final index = currentTasks.indexWhere((t) => t.taskId == taskId);
      if (index != -1) {
        currentTasks[index] = completedTask;
      }
      _tasksSubject.add(currentTasks);
      await _calculateStats(currentTasks);

      return completedTask;
    } catch (e) {
      print('Error completing task: $e');
      return null;
    }
  }

  /// Delete a task
  Future<bool> deleteTask(String taskId) async {
    try {
      await apiClient.deleteJson('/tasks/$taskId');

      // Update local cache
      final currentTasks = _tasksSubject.valueOrNull ?? [];
      currentTasks.removeWhere((t) => t.taskId == taskId);
      _tasksSubject.add(currentTasks);
      await _calculateStats(currentTasks);

      return true;
    } catch (e) {
      print('Error deleting task: $e');
      return false;
    }
  }

  /// Get task by ID
  Future<UserTask?> getTask(String taskId) async {
    try {
      final response = await apiClient.getJson('/tasks/$taskId');
      return UserTask.fromJson(response);
    } catch (e) {
      print('Error getting task: $e');
      return null;
    }
  }

  /// Create a recurring task
  Future<Map<String, dynamic>?> createRecurringTask({
    required String title,
    required String category,
    required String pattern, // daily, weekly, monthly
    String? description,
    DateTime? dueDate,
    int priority = 3,
    int? frequency,
    List<int>? daysOfWeek, // For weekly: [1-7]
    DateTime? endDate,
  }) async {
    try {
      final response = await apiClient.postJson('/tasks/recurring', body: {
        'title': title,
        'category': category,
        'pattern': pattern,
        'description': description,
        'due_date': dueDate?.toIso8601String(),
        'priority': priority,
        'frequency': frequency,
        'days_of_week': daysOfWeek,
        'end_date': endDate?.toIso8601String(),
      });

      return response;
    } catch (e) {
      print('Error creating recurring task: $e');
      return null;
    }
  }

  /// Link a task to a goal
  Future<bool> linkTaskToGoal(String taskId, String goalId) async {
    try {
      await apiClient.putJson('/tasks/$taskId', body: {
        'linked_goal_id': goalId,
      });

      // Reload tasks to reflect changes
      await loadTasks();

      return true;
    } catch (e) {
      print('Error linking task to goal: $e');
      return false;
    }
  }

  /// Unlink a task from a goal
  Future<bool> unlinkTaskFromGoal(String taskId) async {
    try {
      await apiClient.putJson('/tasks/$taskId', body: {
        'linked_goal_id': null,
      });

      // Reload tasks
      await loadTasks();

      return true;
    } catch (e) {
      print('Error unlinking task from goal: $e');
      return false;
    }
  }

  /// Set a reminder for a task
  Future<bool> setTaskReminder(
    String taskId, {
    required int minutesBefore,
    String channel = 'push', // push, sms, email
  }) async {
    try {
      await apiClient.postJson('/tasks/$taskId/reminder', body: {
        'reminder_before_minutes': minutesBefore,
        'channel': channel,
      });
      return true;
    } catch (e) {
      print('Error setting task reminder: $e');
      return false;
    }
  }

  /// Get tasks for a specific goal
  Future<List<UserTask>> getTasksForGoal(String goalId) async {
    try {
      final response = await apiClient.getJson('/user/goals/$goalId/tasks');
      return parseTasks(response['tasks'] as List<dynamic>);
    } catch (e) {
      print('Error getting tasks for goal: $e');
      return [];
    }
  }

  /// Get overdue tasks
  Future<List<UserTask>> getOverdueTasks() async {
    try {
      final now = DateTime.now();
      return await loadTasks(dueBefore: now, status: 'pending');
    } catch (e) {
      print('Error getting overdue tasks: $e');
      return [];
    }
  }

  /// Get tasks due today
  Future<List<UserTask>> getTasksDueToday() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      return await loadTasks(dueAfter: today, dueBefore: tomorrow);
    } catch (e) {
      print('Error getting tasks due today: $e');
      return [];
    }
  }

  /// Get tasks due this week
  Future<List<UserTask>> getTasksDueThisWeek() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nextWeek = today.add(const Duration(days: 7));

      return await loadTasks(dueAfter: today, dueBefore: nextWeek);
    } catch (e) {
      print('Error getting tasks this week: $e');
      return [];
    }
  }

  /// Get task statistics
  Future<void> _calculateStats(List<UserTask> tasks) async {
    try {
      final total = tasks.length;
      final completed = tasks.where((t) => t.status == 'completed').length;
      final inProgress = tasks.where((t) => t.status == 'in_progress').length;
      final pending = tasks.where((t) => t.status == 'pending').length;
      final overdue = tasks.where((t) {
        if (t.dueDate == null) return false;
        return t.dueDate!.isBefore(DateTime.now()) && t.status != 'completed';
      }).length;

      final completionRate =
          total > 0 ? (completed / total * 100).toStringAsFixed(1) : '0.0';

      final stats = TaskStats(
        total: total,
        completed: completed,
        inProgress: inProgress,
        pending: pending,
        overdue: overdue,
        completionRate: double.parse(completionRate),
      );

      _taskStatsSubject.add(stats);
    } catch (e) {
      print('Error calculating stats: $e');
    }
  }

  /// Get task suggestions based on goals and habits
  Future<List<Map<String, dynamic>>> getTaskSuggestions() async {
    try {
      final response = await apiClient.getJson('/user/tasks/suggestions');
      return List<Map<String, dynamic>>.from(
          response['suggestions'] as List<dynamic>);
    } catch (e) {
      print('Error getting task suggestions: $e');
      return [];
    }
  }

  /// Bulk update tasks
  Future<bool> bulkUpdateTasks(
    List<String> taskIds, {
    String? status,
    int? priority,
    String? category,
  }) async {
    try {
      final body = <String, dynamic>{
        'task_ids': taskIds,
      };
      if (status != null) body['status'] = status;
      if (priority != null) body['priority'] = priority;
      if (category != null) body['category'] = category;

      await apiClient.postJson('/tasks/bulk-update', body: body);

      // Reload tasks
      await loadTasks();

      return true;
    } catch (e) {
      print('Error bulk updating tasks: $e');
      return false;
    }
  }

  /// Export tasks to calendar format
  Future<String?> exportTasks({required String format}) async {
    try {
      final response = await apiClient.getJson('/user/tasks/export', query: {
        'format': format, // ics, csv, json
      });
      return response['export_data'];
    } catch (e) {
      print('Error exporting tasks: $e');
      return null;
    }
  }

  /// Get current cached data
  List<UserTask> get currentTasks => _tasksSubject.valueOrNull ?? [];
  TaskStats get currentStats =>
      _taskStatsSubject.valueOrNull ?? TaskStats.empty();

  /// Set filters
  void setFilters(TaskFilters filters) {
    _taskFiltersSubject.add(filters);
  }

  TaskFilters get currentFilters =>
      _taskFiltersSubject.valueOrNull ?? TaskFilters.empty();

  /// Dispose resources
  Future<void> dispose() async {
    await _tasksSubject.close();
    await _taskStatsSubject.close();
    await _taskFiltersSubject.close();
  }
}

/// Task statistics model
class TaskStats {
  final int total;
  final int completed;
  final int inProgress;
  final int pending;
  final int overdue;
  final double completionRate;

  TaskStats({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.pending,
    required this.overdue,
    required this.completionRate,
  });

  factory TaskStats.empty() {
    return TaskStats(
      total: 0,
      completed: 0,
      inProgress: 0,
      pending: 0,
      overdue: 0,
      completionRate: 0.0,
    );
  }
}

/// Task filter model
class TaskFilters {
  final String? status;
  final String? category;
  final DateTime? dueBefore;
  final DateTime? dueAfter;
  final bool sortByDueDate;
  final bool sortByPriority;

  TaskFilters({
    this.status,
    this.category,
    this.dueBefore,
    this.dueAfter,
    this.sortByDueDate = true,
    this.sortByPriority = false,
  });

  factory TaskFilters.empty() {
    return TaskFilters();
  }

  TaskFilters copyWith({
    String? status,
    String? category,
    DateTime? dueBefore,
    DateTime? dueAfter,
    bool? sortByDueDate,
    bool? sortByPriority,
  }) {
    return TaskFilters(
      status: status ?? this.status,
      category: category ?? this.category,
      dueBefore: dueBefore ?? this.dueBefore,
      dueAfter: dueAfter ?? this.dueAfter,
      sortByDueDate: sortByDueDate ?? this.sortByDueDate,
      sortByPriority: sortByPriority ?? this.sortByPriority,
    );
  }
}
