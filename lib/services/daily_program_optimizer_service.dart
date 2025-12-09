import 'package:rxdart/rxdart.dart';

import 'api_client.dart';

/// Daily Program AI Optimizer Service
/// Uses AI to generate optimal daily schedules based on tasks, goals, habits, and mood
class DailyProgramOptimizerService {
  final ApiClient apiClient;

  // Stream controllers
  final _dailyProgramSubject = BehaviorSubject<DailyProgram?>();
  final _suggestionsSubject = BehaviorSubject<List<ScheduleSuggestion>>();
  final _optimizationStatusSubject = BehaviorSubject<OptimizationStatus>();

  DailyProgramOptimizerService({required this.apiClient});

  // Streams
  Stream<DailyProgram?> get dailyProgramStream => _dailyProgramSubject.stream;
  Stream<List<ScheduleSuggestion>> get suggestionsStream =>
      _suggestionsSubject.stream;
  Stream<OptimizationStatus> get optimizationStatusStream =>
      _optimizationStatusSubject.stream;

  /// Generate optimized daily program
  Future<DailyProgram?> generateDailyProgram({
    required DateTime date,
    String? moodLevel,
    String? energyLevel,
    List<String>? priorityGoals,
    String? focusArea, // work, health, personal, learning
  }) async {
    try {
      _updateOptimizationStatus('generating', 0);

      final body = <String, dynamic>{
        'date': date.toIso8601String(),
      };
      if (moodLevel != null) body['mood_level'] = moodLevel;
      if (energyLevel != null) body['energy_level'] = energyLevel;
      if (priorityGoals != null) body['priority_goals'] = priorityGoals;
      if (focusArea != null) body['focus_area'] = focusArea;

      final response =
          await apiClient.postJson('/user/daily-program/generate', body: body);

      _updateOptimizationStatus('processing', 50);

      final program = DailyProgram.fromJson(response);
      _dailyProgramSubject.add(program);

      _updateOptimizationStatus('completed', 100);

      return program;
    } catch (e) {
      print('Error generating daily program: $e');
      _updateOptimizationStatus('error', 0);
      return null;
    }
  }

  /// Get today's recommended program
  Future<DailyProgram?> getTodayProgram() async {
    try {
      final response = await apiClient.getJson('/user/daily-program/today');

      if (response['program'] != null) {
        final program = DailyProgram.fromJson(response['program']);
        _dailyProgramSubject.add(program);
        return program;
      }

      return null;
    } catch (e) {
      print('Error getting today program: $e');
      return null;
    }
  }

  /// Optimize existing program based on feedback
  Future<DailyProgram?> optimizeProgram(
    String programId, {
    required String feedback, // too_easy, too_hard, overwhelming, boring
    List<String>? adjustments,
  }) async {
    try {
      _updateOptimizationStatus('optimizing', 25);

      final body = <String, dynamic>{
        'feedback': feedback,
      };
      if (adjustments != null) body['adjustments'] = adjustments;

      final response = await apiClient.postJson(
        '/user/daily-program/$programId/optimize',
        body: body,
      );

      _updateOptimizationStatus('processing', 75);

      final program = DailyProgram.fromJson(response);
      _dailyProgramSubject.add(program);

      _updateOptimizationStatus('completed', 100);

      return program;
    } catch (e) {
      print('Error optimizing program: $e');
      _updateOptimizationStatus('error', 0);
      return null;
    }
  }

  /// Get AI suggestions for current time
  Future<List<ScheduleSuggestion>> getCurrentSuggestions() async {
    try {
      final response =
          await apiClient.getJson('/user/daily-program/suggestions');

      final suggestions = (response['suggestions'] as List<dynamic>)
          .map((s) => ScheduleSuggestion.fromJson(s as Map<String, dynamic>))
          .toList();

      _suggestionsSubject.add(suggestions);
      return suggestions;
    } catch (e) {
      print('Error getting suggestions: $e');
      return [];
    }
  }

  /// Get next recommended action
  Future<ScheduleSuggestion?> getNextAction() async {
    try {
      final response =
          await apiClient.getJson('/user/daily-program/next-action');

      if (response['suggestion'] != null) {
        return ScheduleSuggestion.fromJson(response['suggestion']);
      }

      return null;
    } catch (e) {
      print('Error getting next action: $e');
      return null;
    }
  }

  /// Adjust program time blocks
  Future<bool> adjustTimeBlock(
    String programId,
    String blockId, {
    required Duration newDuration,
    DateTime? newStartTime,
    String? reason,
  }) async {
    try {
      await apiClient.putJson(
        '/user/daily-program/$programId/blocks/$blockId',
        body: {
          'duration_minutes': newDuration.inMinutes,
          'new_start_time': newStartTime?.toIso8601String(),
          'reason': reason,
        },
      );

      // Reload program
      await getTodayProgram();

      return true;
    } catch (e) {
      print('Error adjusting time block: $e');
      return false;
    }
  }

  /// Skip a time block and get alternative
  Future<ScheduleSuggestion?> skipBlock(
      String programId, String blockId) async {
    try {
      final response = await apiClient.postJson(
        '/user/daily-program/$programId/blocks/$blockId/skip',
      );

      if (response['suggestion'] != null) {
        return ScheduleSuggestion.fromJson(response['suggestion']);
      }

      return null;
    } catch (e) {
      print('Error skipping block: $e');
      return null;
    }
  }

  /// Complete a time block
  Future<bool> completeBlock(
    String programId,
    String blockId, {
    int? actualDurationMinutes,
    String? feedback,
  }) async {
    try {
      await apiClient.postJson(
        '/user/daily-program/$programId/blocks/$blockId/complete',
        body: {
          'actual_duration_minutes': actualDurationMinutes,
          'feedback': feedback,
        },
      );

      // Reload program
      await getTodayProgram();

      return true;
    } catch (e) {
      print('Error completing block: $e');
      return false;
    }
  }

  /// Get program effectiveness score
  Future<double> getProgramEffectiveness(String programId) async {
    try {
      final response = await apiClient.getJson(
        '/user/daily-program/$programId/effectiveness',
      );

      return (response['effectiveness_score'] as num).toDouble();
    } catch (e) {
      print('Error getting program effectiveness: $e');
      return 0.0;
    }
  }

  /// Get program history for analysis
  Future<List<DailyProgramSummary>> getProgramHistory({int days = 30}) async {
    try {
      final response = await apiClient.getJson(
        '/user/daily-program/history',
        query: {'days': days},
      );

      return (response['history'] as List<dynamic>)
          .map((h) => DailyProgramSummary.fromJson(h as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting program history: $e');
      return [];
    }
  }

  /// Get program recommendations based on mood
  Future<List<String>> getMoodBasedRecommendations(String moodLevel) async {
    try {
      final response = await apiClient.getJson(
        '/user/daily-program/mood-recommendations',
        query: {'mood': moodLevel},
      );

      return List<String>.from(response['recommendations'] as List<dynamic>);
    } catch (e) {
      print('Error getting mood recommendations: $e');
      return [];
    }
  }

  /// Get AI-generated motivational message for day
  Future<String?> getDailyMotivation() async {
    try {
      final response =
          await apiClient.getJson('/user/daily-program/motivation');
      return response['message'];
    } catch (e) {
      print('Error getting daily motivation: $e');
      return null;
    }
  }

  /// Update program helper method
  void _updateOptimizationStatus(String status, int progress) {
    _optimizationStatusSubject.add(OptimizationStatus(
      status: status,
      progress: progress,
      timestamp: DateTime.now(),
    ));
  }

  /// Get current cached data
  DailyProgram? get currentProgram => _dailyProgramSubject.valueOrNull;
  List<ScheduleSuggestion> get currentSuggestions =>
      _suggestionsSubject.valueOrNull ?? [];

  /// Dispose resources
  Future<void> dispose() async {
    await _dailyProgramSubject.close();
    await _suggestionsSubject.close();
    await _optimizationStatusSubject.close();
  }
}

/// Daily Program model
class DailyProgram {
  final String programId;
  final DateTime date;
  final List<TimeBlock> timeBlocks;
  final String focusArea;
  final int estimatedCompletionMinutes;
  final String optimizationTips;
  final DateTime createdAt;
  final DateTime? completedAt;

  DailyProgram({
    required this.programId,
    required this.date,
    required this.timeBlocks,
    required this.focusArea,
    required this.estimatedCompletionMinutes,
    required this.optimizationTips,
    required this.createdAt,
    this.completedAt,
  });

  factory DailyProgram.fromJson(Map<String, dynamic> json) {
    return DailyProgram(
      programId: json['program_id'] ?? '',
      date: DateTime.parse(json['date']),
      timeBlocks: (json['time_blocks'] as List<dynamic>?)
              ?.map((b) => TimeBlock.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      focusArea: json['focus_area'] ?? '',
      estimatedCompletionMinutes: json['estimated_completion_minutes'] ?? 0,
      optimizationTips: json['optimization_tips'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }
}

/// Time block in daily program
class TimeBlock {
  final String blockId;
  final String title;
  final String category; // task, goal, habit, break, learning
  final DateTime startTime;
  final int durationMinutes;
  final String priority; // high, medium, low
  final String? description;
  final String status; // pending, in_progress, completed, skipped
  final String? linkedId; // task_id, goal_id, or habit_id
  final DateTime createdAt;

  TimeBlock({
    required this.blockId,
    required this.title,
    required this.category,
    required this.startTime,
    required this.durationMinutes,
    required this.priority,
    this.description,
    required this.status,
    this.linkedId,
    required this.createdAt,
  });

  factory TimeBlock.fromJson(Map<String, dynamic> json) {
    return TimeBlock(
      blockId: json['block_id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      durationMinutes: json['duration_minutes'] ?? 0,
      priority: json['priority'] ?? 'medium',
      description: json['description'],
      status: json['status'] ?? 'pending',
      linkedId: json['linked_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// Schedule suggestion from AI
class ScheduleSuggestion {
  final String suggestionId;
  final String title;
  final String reason;
  final String category;
  final int durationMinutes;
  final double confidence; // 0-1 score
  final String? action; // take, defer, skip

  ScheduleSuggestion({
    required this.suggestionId,
    required this.title,
    required this.reason,
    required this.category,
    required this.durationMinutes,
    required this.confidence,
    this.action,
  });

  factory ScheduleSuggestion.fromJson(Map<String, dynamic> json) {
    return ScheduleSuggestion(
      suggestionId: json['suggestion_id'] ?? '',
      title: json['title'] ?? '',
      reason: json['reason'] ?? '',
      category: json['category'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      action: json['action'],
    );
  }
}

/// Daily program summary for history
class DailyProgramSummary {
  final String programId;
  final DateTime date;
  final int completedBlocks;
  final int totalBlocks;
  final double completionRate;
  final double effectiveness;
  final String notes;

  DailyProgramSummary({
    required this.programId,
    required this.date,
    required this.completedBlocks,
    required this.totalBlocks,
    required this.completionRate,
    required this.effectiveness,
    required this.notes,
  });

  factory DailyProgramSummary.fromJson(Map<String, dynamic> json) {
    return DailyProgramSummary(
      programId: json['program_id'] ?? '',
      date: DateTime.parse(json['date']),
      completedBlocks: json['completed_blocks'] ?? 0,
      totalBlocks: json['total_blocks'] ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      effectiveness: (json['effectiveness'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] ?? '',
    );
  }
}

/// Optimization status tracking
class OptimizationStatus {
  final String status; // generating, processing, optimizing, completed, error
  final int progress; // 0-100
  final DateTime timestamp;

  OptimizationStatus({
    required this.status,
    required this.progress,
    required this.timestamp,
  });
}
