import 'package:flutter/foundation.dart';
import '../models/user_models.dart';
import '../models/daily_program_models.dart';

/// Scheduling recommendation for a specific task
class SchedulingRecommendation {
  final String taskId;
  final String taskTitle;
  final DateTime recommendedTime;
  final String reason; // Why this time is recommended
  final double score; // 0-100 confidence score
  final List<String> factors; // Factors affecting the recommendation
  final String? alternativeTime; // Alternative if primary is not available
  final bool isOptimal; // Is this the optimal time?

  SchedulingRecommendation({
    required this.taskId,
    required this.taskTitle,
    required this.recommendedTime,
    required this.reason,
    required this.score,
    required this.factors,
    this.alternativeTime,
    this.isOptimal = false,
  });

  factory SchedulingRecommendation.fromJson(Map<String, dynamic> json) {
    return SchedulingRecommendation(
      taskId: json['task_id'] ?? '',
      taskTitle: json['task_title'] ?? '',
      recommendedTime: DateTime.parse(json['recommended_time']),
      reason: json['reason'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      factors: List<String>.from(json['factors'] ?? []),
      alternativeTime: json['alternative_time'],
      isOptimal: json['is_optimal'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'task_title': taskTitle,
      'recommended_time': recommendedTime.toIso8601String(),
      'reason': reason,
      'score': score,
      'factors': factors,
      'alternative_time': alternativeTime,
      'is_optimal': isOptimal,
    };
  }
}

/// Smart scheduling analysis result
class SchedulingAnalysis {
  final List<SchedulingRecommendation> recommendations;
  final double overallProductivityScore; // 0-100
  final String scheduleHealthStatus; // optimal, good, fair, poor
  final List<String> improvements; // Suggested improvements
  final DateTime generatedAt;

  SchedulingAnalysis({
    required this.recommendations,
    required this.overallProductivityScore,
    required this.scheduleHealthStatus,
    required this.improvements,
    required this.generatedAt,
  });

  factory SchedulingAnalysis.fromJson(Map<String, dynamic> json) {
    return SchedulingAnalysis(
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((r) =>
                  SchedulingRecommendation.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      overallProductivityScore:
          (json['overall_productivity_score'] as num?)?.toDouble() ?? 0.0,
      scheduleHealthStatus: json['schedule_health_status'] ?? 'fair',
      improvements: List<String>.from(json['improvements'] ?? []),
      generatedAt: DateTime.parse(json['generated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recommendations': recommendations.map((r) => r.toJson()).toList(),
      'overall_productivity_score': overallProductivityScore,
      'schedule_health_status': scheduleHealthStatus,
      'improvements': improvements,
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}

/// Smart scheduling service
class SmartSchedulingService extends ChangeNotifier {
  SchedulingAnalysis? _currentAnalysis;
  Map<String, SchedulingRecommendation> _taskRecommendations = {};
  bool _isAnalyzing = false;
  String? _error;

  // Getters
  SchedulingAnalysis? get currentAnalysis => _currentAnalysis;
  Map<String, SchedulingRecommendation> get taskRecommendations =>
      _taskRecommendations;
  bool get isAnalyzing => _isAnalyzing;
  String? get error => _error;

  /// Analyze schedule and generate recommendations
  Future<SchedulingAnalysis> analyzeSchedule({
    required UserProfile profile,
    required List<UserGoal> goals,
    required List<Habit> habits,
    required List<MoodSnapshot> moodHistory,
    required DailyProgram currentProgram,
  }) async {
    try {
      _isAnalyzing = true;
      _error = null;
      notifyListeners();

      // Get user's energy patterns
      final energyPattern = _analyzeEnergyPattern(moodHistory, profile);
      final focusPattern = _analyzeFocusPattern(moodHistory);
      final habitConsistency = _analyzeHabitConsistency(habits);

      // Generate recommendations
      final recommendations = <SchedulingRecommendation>[];

      // 1. Recommend optimal times for high-priority goals
      for (final goal in goals.where((g) => g.isActive)) {
        final rec = _recommendGoalTime(
          goal: goal,
          energyPattern: energyPattern,
          focusPattern: focusPattern,
          currentProgram: currentProgram,
          profile: profile,
        );
        recommendations.add(rec);
        _taskRecommendations[goal.goalId] = rec;
      }

      // 2. Recommend optimal times for habits
      for (final habit in habits.where((h) => h.isActive)) {
        final rec = _recommendHabitTime(
          habit: habit,
          energyPattern: energyPattern,
          profile: profile,
          currentProgram: currentProgram,
        );
        recommendations.add(rec);
        _taskRecommendations[habit.habitId] = rec;
      }

      // Calculate overall score
      final overallScore = _calculateOverallScore(
        currentProgram,
        energyPattern,
        focusPattern,
        habitConsistency,
      );

      // Determine health status
      final healthStatus = _determineHealthStatus(overallScore);

      // Generate improvement suggestions
      final improvements = _generateImprovements(
        currentProgram,
        energyPattern,
        focusPattern,
        habitConsistency,
        goals,
      );

      _currentAnalysis = SchedulingAnalysis(
        recommendations: recommendations,
        overallProductivityScore: overallScore,
        scheduleHealthStatus: healthStatus,
        improvements: improvements,
        generatedAt: DateTime.now(),
      );

      _isAnalyzing = false;
      notifyListeners();
      return _currentAnalysis!;
    } catch (e) {
      _error = e.toString();
      _isAnalyzing = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get recommendation for specific goal
  SchedulingRecommendation? getGoalRecommendation(String goalId) {
    return _taskRecommendations[goalId];
  }

  /// Get recommendation for specific habit
  SchedulingRecommendation? getHabitRecommendation(String habitId) {
    return _taskRecommendations[habitId];
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRIVATE HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// Analyze user's energy pattern from mood history
  Map<int, double> _analyzeEnergyPattern(
    List<MoodSnapshot> moodHistory,
    UserProfile profile,
  ) {
    final hourlyEnergy = <int, List<double>>{};

    for (final snapshot in moodHistory) {
      final hour = snapshot.timestamp.hour;
      if (!hourlyEnergy.containsKey(hour)) {
        hourlyEnergy[hour] = [];
      }
      hourlyEnergy[hour]!.add(snapshot.energy);
    }

    // Calculate average energy for each hour
    final pattern = <int, double>{};
    for (final entry in hourlyEnergy.entries) {
      pattern[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }

    return pattern;
  }

  /// Analyze user's focus pattern
  Map<String, double> _analyzeFocusPattern(List<MoodSnapshot> moodHistory) {
    final contextFocus = <String, List<double>>{};

    for (final snapshot in moodHistory) {
      final context = snapshot.context ?? 'general';
      if (!contextFocus.containsKey(context)) {
        contextFocus[context] = [];
      }
      contextFocus[context]!.add(snapshot.mood);
    }

    // Calculate average focus (mood) for each context
    final pattern = <String, double>{};
    for (final entry in contextFocus.entries) {
      pattern[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }

    return pattern;
  }

  /// Analyze habit consistency
  double _analyzeHabitConsistency(List<Habit> habits) {
    if (habits.isEmpty) return 0.5;
    final totalStreaks = habits.fold<int>(0, (sum, h) => sum + h.currentStreak);
    final totalHabits = habits.length;
    return (totalStreaks / (totalHabits * 30)).clamp(0.0, 1.0);
  }

  /// Recommend optimal time for goal
  SchedulingRecommendation _recommendGoalTime({
    required UserGoal goal,
    required Map<int, double> energyPattern,
    required Map<String, double> focusPattern,
    required DailyProgram currentProgram,
    required UserProfile profile,
  }) {
    // Find hour with highest energy
    final bestHour = energyPattern.isEmpty
        ? 9
        : energyPattern.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Adjust for goal category
    final adjustedHour = _adjustHourForGoal(bestHour, goal);

    // Build recommendation
    final now = DateTime.now();
    final recommendedTime =
        DateTime(now.year, now.month, now.day, adjustedHour, 0);

    final factors = <String>[
      'بالاترین سطح انرژی در ساعت $adjustedHour',
      'اولویت بالا برای کمال‌گرایان',
      'تراز منطبق با زمان تمرکز',
    ];

    final score = (energyPattern[adjustedHour] ?? 5) * 10 +
        (focusPattern[goal.category] ?? 5) * 5;

    return SchedulingRecommendation(
      taskId: goal.goalId,
      taskTitle: goal.title,
      recommendedTime: recommendedTime,
      reason:
          '${goal.title} بهتر است در ساعت $adjustedHour انجام شود زمانی که انرژی شما در بالاترین سطح است',
      score: (score).clamp(0, 100),
      factors: factors,
      isOptimal: true,
    );
  }

  /// Recommend optimal time for habit
  SchedulingRecommendation _recommendHabitTime({
    required Habit habit,
    required Map<int, double> energyPattern,
    required UserProfile profile,
    required DailyProgram currentProgram,
  }) {
    // Habits work better at consistent times
    int recommendedHour;
    if (habit.name.toLowerCase().contains('ورزش') ||
        habit.name.toLowerCase().contains('تمرین')) {
      recommendedHour = 6; // Morning for exercise
    } else if (habit.name.toLowerCase().contains('مطالعه') ||
        habit.name.toLowerCase().contains('یادگیری')) {
      recommendedHour = 8; // Morning for learning
    } else if (habit.name.toLowerCase().contains('تأمل') ||
        habit.name.toLowerCase().contains('مراقبه')) {
      recommendedHour = 6; // Early morning for meditation
    } else {
      // Default to time with decent energy
      recommendedHour = energyPattern.isEmpty ? 10 : 10; // Mid-morning default
    }

    final now = DateTime.now();
    final recommendedTime =
        DateTime(now.year, now.month, now.day, recommendedHour, 0);

    final factors = <String>[
      'سازگاری و تناسب منظم',
      'سطح انرژی کافی در این ساعت',
      'فاصله از سایر فعالیت‌های مهم',
    ];

    return SchedulingRecommendation(
      taskId: habit.habitId,
      taskTitle: habit.name,
      recommendedTime: recommendedTime,
      reason:
          '${habit.name} بهتر است هر روز در ساعت ${recommendedHour.toString().padLeft(2, '0')}:00 انجام شود برای سازگاری بهتر',
      score: 85.0,
      factors: factors,
      isOptimal: true,
    );
  }

  /// Adjust hour based on goal type
  int _adjustHourForGoal(int baseHour, UserGoal goal) {
    // Creative work: 9-11 AM or 4-6 PM
    if (goal.category.toLowerCase().contains('خلاق')) {
      return baseHour >= 16 ? baseHour : 9;
    }
    // Learning: 10 AM - 12 PM
    if (goal.category.toLowerCase().contains('یادگیری')) {
      return 10;
    }
    // Administrative: 2-4 PM
    if (goal.category.toLowerCase().contains('اداری')) {
      return 14;
    }
    return baseHour;
  }

  /// Calculate overall productivity score
  double _calculateOverallScore(
    DailyProgram program,
    Map<int, double> energyPattern,
    Map<String, double> focusPattern,
    double habitConsistency,
  ) {
    final focusMinutes = program.activities.fold<int>(0,
        (sum, a) => a.category == 'focus' ? sum + a.duration.inMinutes : sum);
    final breakMinutes = program.activities.fold<int>(
        0,
        (sum, a) => a.category == 'break' || a.category == 'rest'
            ? sum + a.duration.inMinutes
            : sum);

    final focusScore = (focusMinutes / 240 * 100).clamp(0, 100);
    final balanceScore =
        (breakMinutes > 0 ? 80 : 40) * (focusMinutes > 60 ? 1.0 : 0.5);
    final consistencyScore = habitConsistency * 100;

    return ((focusScore * 0.4) +
            (balanceScore * 0.35) +
            (consistencyScore * 0.25))
        .clamp(0, 100);
  }

  /// Determine schedule health status
  String _determineHealthStatus(double score) {
    if (score >= 80) return 'بسیار خوب';
    if (score >= 60) return 'خوب';
    if (score >= 40) return 'متوسط';
    return 'نیاز به بهبود';
  }

  /// Generate improvement suggestions
  List<String> _generateImprovements(
    DailyProgram program,
    Map<int, double> energyPattern,
    Map<String, double> focusPattern,
    double habitConsistency,
    List<UserGoal> goals,
  ) {
    final improvements = <String>[];

    // Check focus time
    final focusMinutes = program.activities.fold<int>(0,
        (sum, a) => a.category == 'focus' ? sum + a.duration.inMinutes : sum);
    if (focusMinutes < 120) {
      improvements
          .add('⚠️ وقت تمرکز کافی نیست - حداقل 2 ساعت روزانه توصیه می‌شود');
    }

    // Check break time
    final breakMinutes = program.activities.fold<int>(
        0,
        (sum, a) => a.category == 'break' || a.category == 'rest'
            ? sum + a.duration.inMinutes
            : sum);
    if (breakMinutes < 60) {
      improvements.add(
          '✏️ بیشتر استراحت کنید - استراحت منظم تولیدی‌تری را افزایش می‌دهد');
    }

    // Check habit consistency
    if (habitConsistency < 0.5) {
      improvements.add(
          '📌 عادات‌های خود را منظم‌تر انجام دهید - سازگاری در بهتری‌ها کلیدی است');
    }

    // Check goal alignment
    if (goals.isEmpty) {
      improvements
          .add('🎯 اهداف واضح تعریف کنید - اهداف روشن پایه‌ای برای موفقیت است');
    }

    // Check energy patterns
    if (energyPattern.isEmpty) {
      improvements.add(
          '📊 نمودار انرژی‌تان را ثبت کنید - این به برنامه‌ریزی بهتر کمک می‌کند');
    }

    return improvements;
  }
}
