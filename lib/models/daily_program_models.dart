import '../models/user_models.dart';

/// Daily program activity item
class ProgramActivity {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String category; // goal, habit, break, focus, rest
  final String priority; // high, medium, low
  final String? relatedGoalId;
  final String? relatedHabitId;
  final double? energyRequired; // 1-10
  final double? moodBenefits; // Expected mood improvement
  final bool isFlexible; // Can be moved
  final int? order; // Sequential order

  ProgramActivity({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.priority,
    this.relatedGoalId,
    this.relatedHabitId,
    this.energyRequired,
    this.moodBenefits,
    this.isFlexible = true,
    this.order,
  });

  Duration get duration => endTime.difference(startTime);

  factory ProgramActivity.fromJson(Map<String, dynamic> json) {
    return ProgramActivity(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      category: json['category'] ?? 'focus',
      priority: json['priority'] ?? 'medium',
      relatedGoalId: json['related_goal_id'],
      relatedHabitId: json['related_habit_id'],
      energyRequired: json['energy_required'],
      moodBenefits: json['mood_benefits'],
      isFlexible: json['is_flexible'] ?? true,
      order: json['order'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'category': category,
      'priority': priority,
      'related_goal_id': relatedGoalId,
      'related_habit_id': relatedHabitId,
      'energy_required': energyRequired,
      'mood_benefits': moodBenefits,
      'is_flexible': isFlexible,
      'order': order,
    };
  }
}

/// Daily program - collection of activities for a day
class DailyProgram {
  final String programId;
  final String userId;
  final DateTime date;
  final List<ProgramActivity> activities;
  final double? expectedProductivity; // 0-100
  final double? expectedMood; // 1-10
  final String? focusTheme; // Main theme for the day
  final DateTime createdAt;
  final DateTime? generatedAt;

  DailyProgram({
    required this.programId,
    required this.userId,
    required this.date,
    required this.activities,
    this.expectedProductivity,
    this.expectedMood,
    this.focusTheme,
    required this.createdAt,
    this.generatedAt,
  });

  /// Get activities sorted by time
  List<ProgramActivity> get sortedActivities {
    final sorted = List<ProgramActivity>.from(activities);
    sorted.sort((a, b) => a.startTime.compareTo(b.startTime));
    return sorted;
  }

  /// Get activities by category
  List<ProgramActivity> getActivitiesByCategory(String category) {
    return activities.where((a) => a.category == category).toList();
  }

  /// Get total focus time
  Duration get totalFocusTime {
    return activities
        .where((a) => a.category == 'focus')
        .fold<Duration>(Duration.zero, (sum, a) => sum + a.duration);
  }

  /// Get total break time
  Duration get totalBreakTime {
    return activities
        .where((a) => a.category == 'break' || a.category == 'rest')
        .fold<Duration>(Duration.zero, (sum, a) => sum + a.duration);
  }

  /// Get high priority tasks
  List<ProgramActivity> get highPriorityTasks {
    return activities.where((a) => a.priority == 'high').toList();
  }

  factory DailyProgram.fromJson(Map<String, dynamic> json) {
    return DailyProgram(
      programId: json['program_id'] ?? '',
      userId: json['user_id'] ?? '',
      date: DateTime.parse(json['date']),
      activities: (json['activities'] as List<dynamic>?)
              ?.map((a) => ProgramActivity.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      expectedProductivity: json['expected_productivity'],
      expectedMood: json['expected_mood'],
      focusTheme: json['focus_theme'],
      createdAt: DateTime.parse(json['created_at']),
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'program_id': programId,
      'user_id': userId,
      'date': date.toIso8601String(),
      'activities': activities.map((a) => a.toJson()).toList(),
      'expected_productivity': expectedProductivity,
      'expected_mood': expectedMood,
      'focus_theme': focusTheme,
      'created_at': createdAt.toIso8601String(),
      'generated_at': generatedAt?.toIso8601String(),
    };
  }
}

/// Daily program generation algorithm
class DailyProgramGenerator {
  /// Generate daily program based on profile, goals, habits, and mood
  static DailyProgram generateProgram({
    required String userId,
    required UserProfile profile,
    required List<UserGoal> goals,
    required List<Habit> habits,
    required double currentMood,
    required double currentEnergy,
    DateTime? date,
  }) {
    date ??= DateTime.now();
    final programId = _generateId();
    final activities = <ProgramActivity>[];

    // 1. Parse schedule
    final wakeTime = _parseTime(profile.wakeUpTime ?? '06:00');
    final focusHours = _parseFocusHours(profile.focusHours ?? '2-4');

    // 2. Morning routine (30 mins)
    activities.add(ProgramActivity(
      id: _generateId(),
      title: 'صبح بیداری و آماده‌سازی',
      description: 'صبح بیدار شدن، آب‌تناول، تمدد و آماده‌سازی روز',
      startTime: _dateTime(date, wakeTime),
      endTime: _dateTime(date, wakeTime).add(Duration(minutes: 30)),
      category: 'rest',
      priority: 'medium',
      energyRequired: 3.0,
      moodBenefits: 1.0,
      isFlexible: false,
      order: 1,
    ));

    // 3. Habit activities (morning habits)
    var currentTime = _dateTime(date, wakeTime).add(Duration(minutes: 30));
    final morningHabits = habits
        .where((h) => h.isActive && h.frequency == 'daily')
        .take(2)
        .toList();

    for (final habit in morningHabits) {
      activities.add(ProgramActivity(
        id: _generateId(),
        title: habit.name,
        description: habit.description,
        startTime: currentTime,
        endTime: currentTime.add(Duration(minutes: 20)),
        category: 'habit',
        priority: 'high',
        relatedHabitId: habit.habitId,
        energyRequired: 4.0,
        moodBenefits: 2.0,
        isFlexible: true,
        order: 2 + morningHabits.indexOf(habit),
      ));
      currentTime = currentTime.add(Duration(minutes: 20));
    }

    // 4. Breakfast break (20 mins)
    activities.add(ProgramActivity(
      id: _generateId(),
      title: 'صبحانه',
      startTime: currentTime,
      endTime: currentTime.add(Duration(minutes: 20)),
      category: 'break',
      priority: 'medium',
      energyRequired: 2.0,
      moodBenefits: 1.5,
      isFlexible: true,
      order: 5,
    ));
    currentTime = currentTime.add(Duration(minutes: 20));

    // 5. High-priority goals (focused work)
    final highPriorityGoals =
        goals.where((g) => g.isActive && g.priority == 'high').take(2).toList();

    for (final goal in highPriorityGoals) {
      final focusMinutes =
          focusHours.$1 * 60 ~/ (highPriorityGoals.length.clamp(1, 3));
      activities.add(ProgramActivity(
        id: _generateId(),
        title: 'کار بر روی: ${goal.title}',
        description: goal.description ?? 'تمرکز بر روی ${goal.title}',
        startTime: currentTime,
        endTime: currentTime.add(Duration(minutes: focusMinutes)),
        category: 'focus',
        priority: 'high',
        relatedGoalId: goal.goalId,
        energyRequired: 8.0,
        moodBenefits: 3.0,
        isFlexible: true,
        order: 6 + highPriorityGoals.indexOf(goal),
      ));
      currentTime = currentTime.add(Duration(minutes: focusMinutes));

      // Add break after focus
      activities.add(ProgramActivity(
        id: _generateId(),
        title: 'استراحت کوتاه',
        startTime: currentTime,
        endTime: currentTime.add(Duration(minutes: 10)),
        category: 'break',
        priority: 'medium',
        energyRequired: 1.0,
        moodBenefits: 1.0,
        isFlexible: true,
        order: 0,
      ));
      currentTime = currentTime.add(Duration(minutes: 10));
    }

    // 6. Lunch break (30 mins)
    activities.add(ProgramActivity(
      id: _generateId(),
      title: 'ناهار',
      startTime: currentTime,
      endTime: currentTime.add(Duration(minutes: 30)),
      category: 'break',
      priority: 'medium',
      energyRequired: 2.0,
      moodBenefits: 2.0,
      isFlexible: true,
      order: 8,
    ));
    currentTime = currentTime.add(Duration(minutes: 30));

    // 7. Afternoon goals (medium priority)
    final mediumPriorityGoals =
        goals.where((g) => g.isActive && g.priority == 'medium').take(1);

    for (final goal in mediumPriorityGoals) {
      activities.add(ProgramActivity(
        id: _generateId(),
        title: '${goal.title} - ادامه',
        startTime: currentTime,
        endTime: currentTime.add(Duration(minutes: 45)),
        category: 'focus',
        priority: 'medium',
        relatedGoalId: goal.goalId,
        energyRequired: 6.0,
        moodBenefits: 2.0,
        isFlexible: true,
        order: 9,
      ));
      currentTime = currentTime.add(Duration(minutes: 45));
    }

    // 8. Habit check-in (evening habits)
    final eveningHabits = habits
        .where((h) => h.isActive && h.frequency == 'daily')
        .skip(2)
        .take(2)
        .toList();

    for (final habit in eveningHabits) {
      activities.add(ProgramActivity(
        id: _generateId(),
        title: habit.name,
        startTime: currentTime,
        endTime: currentTime.add(Duration(minutes: 20)),
        category: 'habit',
        priority: 'medium',
        relatedHabitId: habit.habitId,
        energyRequired: 3.0,
        moodBenefits: 1.5,
        isFlexible: true,
        order: 10 + eveningHabits.indexOf(habit),
      ));
      currentTime = currentTime.add(Duration(minutes: 20));
    }

    // 9. Evening routine & reflection (20 mins)
    activities.add(ProgramActivity(
      id: _generateId(),
      title: 'بازنگری روز و برنامه‌ریزی فردا',
      description: 'تأمل در دستاورد‌های روز و برنامه‌ریزی روز بعد',
      startTime: currentTime,
      endTime: currentTime.add(Duration(minutes: 20)),
      category: 'rest',
      priority: 'medium',
      energyRequired: 2.0,
      moodBenefits: 2.0,
      isFlexible: true,
      order: 12,
    ));
    currentTime = currentTime.add(Duration(minutes: 20));

    // 10. Wind-down before sleep (20 mins)
    activities.add(ProgramActivity(
      id: _generateId(),
      title: 'آماده‌سازی برای خواب',
      description: 'خاموش کردن دستگاه‌ها، تنظیم محیط خواب',
      startTime: currentTime,
      endTime: currentTime.add(Duration(minutes: 20)),
      category: 'rest',
      priority: 'medium',
      energyRequired: 1.0,
      moodBenefits: 1.0,
      isFlexible: false,
      order: 13,
    ));

    // Calculate expectations
    final expectedProductivity = _calculateProductivity(activities, goals);
    final expectedMood = _calculateExpectedMood(activities, currentMood);
    final focusTheme = _determineFocusTheme(highPriorityGoals);

    return DailyProgram(
      programId: programId,
      userId: userId,
      date: date,
      activities: activities,
      expectedProductivity: expectedProductivity,
      expectedMood: expectedMood,
      focusTheme: focusTheme,
      createdAt: DateTime.now(),
      generatedAt: DateTime.now(),
    );
  }

  static double _calculateProductivity(
    List<ProgramActivity> activities,
    List<UserGoal> goals,
  ) {
    final focusActivities =
        activities.where((a) => a.category == 'focus').toList();
    final focusMinutes =
        focusActivities.fold<int>(0, (sum, a) => sum + a.duration.inMinutes);
    final goalAlignment = goals.isEmpty ? 0.5 : 0.8;
    return (focusMinutes / 240 * 100).clamp(0, 100) * goalAlignment;
  }

  static double _calculateExpectedMood(
    List<ProgramActivity> activities,
    double currentMood,
  ) {
    final moodBenefits =
        activities.fold<double>(0, (sum, a) => sum + (a.moodBenefits ?? 0));
    final improvement = (moodBenefits / 20).clamp(0, 3);
    return (currentMood + improvement).clamp(1, 10);
  }

  static String? _determineFocusTheme(List<UserGoal> highPriorityGoals) {
    if (highPriorityGoals.isEmpty) return null;
    return highPriorityGoals.first.category;
  }

  static String _generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  static TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 6,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  static (int, int) _parseFocusHours(String focusStr) {
    final parts = focusStr.split('-');
    final first = int.tryParse(parts[0].trim()) ?? 2;
    final second = int.tryParse(parts.length > 1 ? parts[1].trim() : '4') ?? 4;
    return (first, second);
  }

  static DateTime _dateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class TimeOfDay {
  final int hour;
  final int minute;

  TimeOfDay({required this.hour, required this.minute});

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
