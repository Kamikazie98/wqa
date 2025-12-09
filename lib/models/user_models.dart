
import 'dart:math';

/// Goal status enum
enum GoalStatus { active, paused, completed, archived }

extension GoalStatusExt on GoalStatus {
  String toJson() => toString().split('.').last;

  static GoalStatus fromJson(String json) {
    switch (json) {
      case 'active':
        return GoalStatus.active;
      case 'paused':
        return GoalStatus.paused;
      case 'completed':
        return GoalStatus.completed;
      case 'archived':
        return GoalStatus.archived;
      default:
        return GoalStatus.active;
    }
  }
}

/// Mood enum (1-10 scale)
enum MoodLevel { veryBad, bad, neutral, good, veryGood }

extension MoodLevelExt on MoodLevel {
  int toValue() {
    switch (this) {
      case MoodLevel.veryBad:
        return 1;
      case MoodLevel.bad:
        return 3;
      case MoodLevel.neutral:
        return 5;
      case MoodLevel.good:
        return 7;
      case MoodLevel.veryGood:
        return 10;
    }
  }

  String toDisplayString() {
    switch (this) {
      case MoodLevel.veryBad:
        return 'خیلی بد';
      case MoodLevel.bad:
        return 'بد';
      case MoodLevel.neutral:
        return 'متوسط';
      case MoodLevel.good:
        return 'خوب';
      case MoodLevel.veryGood:
        return 'خیلی خوب';
    }
  }

  static MoodLevel fromValue(int value) {
    if (value <= 2) return MoodLevel.veryBad;
    if (value <= 4) return MoodLevel.bad;
    if (value <= 6) return MoodLevel.neutral;
    if (value <= 8) return MoodLevel.good;
    return MoodLevel.veryGood;
  }
}

/// User profile model
class UserProfile {
  final String userId;
  final String name;
  final String role;
  final String timezone;
  final List<String> interests;
  final String? wakeUpTime;
  final String? sleepTime;
  final String? focusHours;
  final double? avgEnergy;
  final double? avgMood;
  final List<String> activeGoalIds;
  final int? preferredBreakDuration;
  final bool? enableMotivation;
  final String? communicationStyle;
  final bool? trackHabits;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.userId,
    required this.name,
    required this.role,
    required this.timezone,
    required this.interests,
    this.wakeUpTime,
    this.sleepTime,
    this.focusHours,
    this.avgEnergy,
    this.avgMood,
    this.activeGoalIds = const [],
    this.preferredBreakDuration,
    this.enableMotivation,
    this.communicationStyle,
    this.trackHabits,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: (json['user_id'] ?? '').toString(),
      name: json['name'] ?? '',
      role: json['role'] ?? 'user',
      timezone: json['timezone'] ?? 'UTC',
      interests: List<String>.from(json['interests'] ?? []),
      wakeUpTime: json['wake_up_time']?.toString(),
      sleepTime: json['sleep_time']?.toString(),
      focusHours: json['focus_hours']?.toString(),
      avgEnergy: json['avg_energy'] != null
          ? (json['avg_energy'] as num).toDouble()
          : null,
      avgMood: json['avg_mood'] != null
          ? (json['avg_mood'] as num).toDouble()
          : null,
      activeGoalIds: List<String>.from(json['active_goal_ids'] ?? []),
      preferredBreakDuration: json['preferred_break_duration'],
      enableMotivation: json['enable_motivation'],
      communicationStyle: json['communication_style'],
      trackHabits: json['track_habits'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'role': role,
      'timezone': timezone,
      'interests': interests,
      'wake_up_time': wakeUpTime,
      'sleep_time': sleepTime,
      'focus_hours': focusHours,
      'avg_energy': avgEnergy,
      'avg_mood': avgMood,
      'active_goal_ids': activeGoalIds,
      'preferred_break_duration': preferredBreakDuration,
      'enable_motivation': enableMotivation,
      'communication_style': communicationStyle,
      'track_habits': trackHabits,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? userId,
    String? name,
    String? role,
    String? timezone,
    List<String>? interests,
    String? wakeUpTime,
    String? sleepTime,
    String? focusHours,
    double? avgEnergy,
    double? avgMood,
    List<String>? activeGoalIds,
    int? preferredBreakDuration,
    bool? enableMotivation,
    String? communicationStyle,
    bool? trackHabits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      timezone: timezone ?? this.timezone,
      interests: interests ?? this.interests,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      sleepTime: sleepTime ?? this.sleepTime,
      focusHours: focusHours ?? this.focusHours,
      avgEnergy: avgEnergy ?? this.avgEnergy,
      avgMood: avgMood ?? this.avgMood,
      activeGoalIds: activeGoalIds ?? this.activeGoalIds,
      preferredBreakDuration:
          preferredBreakDuration ?? this.preferredBreakDuration,
      enableMotivation: enableMotivation ?? this.enableMotivation,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      trackHabits: trackHabits ?? this.trackHabits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// User goal model
class UserGoal {
  final String goalId;
  final String userId;
  final String title;
  final String category;
  final String? description;
  final DateTime deadline;
  final String priority; // low, medium, high, urgent
  final double progressPercentage;
  final GoalStatus status;
  final List<GoalMilestone>? milestones;
  final DateTime createdAt;
  final DateTime? completedAt;

  UserGoal({
    required this.goalId,
    required this.userId,
    required this.title,
    required this.category,
    this.description,
    required this.deadline,
    required this.priority,
    this.progressPercentage = 0.0,
    this.status = GoalStatus.active,
    this.milestones,
    required this.createdAt,
    this.completedAt,
  });

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      goalId: json['goal_id'] ?? '',
      userId: json['user_id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      description: json['description'],
      deadline: DateTime.parse(json['deadline']),
      priority: json['priority'] ?? 'medium',
      progressPercentage: json['progress_percentage'] != null
          ? (json['progress_percentage'] as num).toDouble()
          : 0.0,
      status: GoalStatusExt.fromJson(json['status'] ?? 'active'),
      milestones: (json['milestones'] as List<dynamic>?)
          ?.map((m) => GoalMilestone.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal_id': goalId,
      'user_id': userId,
      'title': title,
      'category': category,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'priority': priority,
      'progress_percentage': progressPercentage,
      'status': status.toJson(),
      'milestones': milestones?.map((m) => m.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  UserGoal copyWith({
    String? goalId,
    String? userId,
    String? title,
    String? category,
    String? description,
    DateTime? deadline,
    String? priority,
    double? progressPercentage,
    GoalStatus? status,
    List<GoalMilestone>? milestones,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return UserGoal(
      goalId: goalId ?? this.goalId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      status: status ?? this.status,
      milestones: milestones ?? this.milestones,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  bool get isCompleted => status == GoalStatus.completed;
  bool get isActive => status == GoalStatus.active;
  bool get isOverdue => DateTime.now().isAfter(deadline) && !isCompleted;
}

class Goal {
  final String id;
  final String title;
  final String description;

  Goal({
    required this.id,
    required this.title,
    required this.description,
  });
}

/// Mood snapshot model
class MoodSnapshot {
  final String snapshotId;
  final String userId;
  final DateTime timestamp;
  final double energy; // 1-10 scale
  final double mood; // 1-10 scale
  final String? context; // work, personal, health, etc.
  final String? activity; // What user was doing
  final String? notes;

  MoodSnapshot({
    required this.snapshotId,
    required this.userId,
    required this.timestamp,
    required this.energy,
    required this.mood,
    this.context,
    this.activity,
    this.notes,
  });

  factory MoodSnapshot.fromJson(Map<String, dynamic> json) {
    return MoodSnapshot(
      snapshotId: json['snapshot_id'] ?? '',
      userId: json['user_id'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      energy: (json['energy'] as num).toDouble(),
      mood: (json['mood'] as num).toDouble(),
      context: json['context'],
      activity: json['activity'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'snapshot_id': snapshotId,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
      'energy': energy,
      'mood': mood,
      'context': context,
      'activity': activity,
      'notes': notes,
    };
  }

  MoodLevel get moodLevel => MoodLevelExt.fromValue(mood.toInt());
  MoodLevel get energyLevel => MoodLevelExt.fromValue(energy.toInt());
}

/// Habit streak tracking
class HabitStreak {
  final int current;
  final int longest;
  final int total;

  HabitStreak({
    required this.current,
    required this.longest,
    required this.total,
  });

  factory HabitStreak.fromJson(Map<String, dynamic> json) {
    return HabitStreak(
      current: json['current'] ?? 0,
      longest: json['longest'] ?? 0,
      total: json['total'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'longest': longest,
      'total': total,
    };
  }
}

/// User habit model
class Habit {
  final String habitId;
  final String userId;
  final String name;
  final String category;
  final String? description;
  final String frequency; // daily, weekly, custom
  final int targetCount; // Target completions per period
  final int currentStreak;
  final int longestStreak;
  final int totalCompletions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Habit({
    required this.habitId,
    required this.userId,
    required this.name,
    required this.category,
    this.description,
    required this.frequency,
    required this.targetCount,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalCompletions = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      habitId: json['habit_id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'],
      frequency: json['frequency'] ?? 'daily',
      targetCount: json['target_count'] ?? 1,
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      totalCompletions: json['total_completions'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'habit_id': habitId,
      'user_id': userId,
      'name': name,
      'category': category,
      'description': description,
      'frequency': frequency,
      'target_count': targetCount,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'total_completions': totalCompletions,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Habit copyWith({
    String? habitId,
    String? userId,
    String? name,
    String? category,
    String? description,
    String? frequency,
    int? targetCount,
    int? currentStreak,
    int? longestStreak,
    int? totalCompletions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Habit(
      habitId: habitId ?? this.habitId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      targetCount: targetCount ?? this.targetCount,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Habit with today's completion status
class HabitWithStatus {
  final Habit habit;
  final bool completedToday;
  final DateTime? lastCompletedDate;

  HabitWithStatus({
    required this.habit,
    required this.completedToday,
    this.lastCompletedDate,
  });

  factory HabitWithStatus.fromJson(Map<String, dynamic> json) {
    return HabitWithStatus(
      habit: Habit.fromJson(json['habit']),
      completedToday: json['completed_today'] ?? false,
      lastCompletedDate: json['last_completed_date'] != null
          ? DateTime.parse(json['last_completed_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'habit': habit.toJson(),
      'completed_today': completedToday,
      'last_completed_date': lastCompletedDate?.toIso8601String(),
    };
  }
}

/// Task model for task management
class UserTask {
  final String taskId;
  final String userId;
  final String title;
  final String? description;
  final String category;
  final String status; // pending, in_progress, completed, cancelled
  final int priority; // 1-5
  final DateTime? dueDate;
  final int? estimatedDurationMinutes;
  final String? location;
  final int? reminderBeforeMinutes;
  final bool reminderSent;
  final List<String> subtasks;
  final List<String> tags;
  final String? linkedGoalId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserTask({
    required this.taskId,
    required this.userId,
    required this.title,
    this.description,
    required this.category,
    required this.status,
    required this.priority,
    this.dueDate,
    this.estimatedDurationMinutes,
    this.location,
    this.reminderBeforeMinutes,
    required this.reminderSent,
    required this.subtasks,
    required this.tags,
    this.linkedGoalId,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserTask.fromJson(Map<String, dynamic> json) {
    return UserTask(
      taskId: json['task_id'] ?? '',
      userId: json['user_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      category: json['category'] ?? '',
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 3,
      dueDate:
          json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      estimatedDurationMinutes: json['estimated_duration_minutes'],
      location: json['location'],
      reminderBeforeMinutes: json['reminder_before_minutes'],
      reminderSent: json['reminder_sent'] ?? false,
      subtasks: List<String>.from(json['subtasks'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      linkedGoalId: json['linked_goal_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'status': status,
      'priority': priority,
      'due_date': dueDate?.toIso8601String(),
      'estimated_duration_minutes': estimatedDurationMinutes,
      'location': location,
      'reminder_before_minutes': reminderBeforeMinutes,
      'reminder_sent': reminderSent,
      'subtasks': subtasks,
      'tags': tags,
      'linked_goal_id': linkedGoalId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Location-based reminder model
class LocationReminder {
  final String reminderId;
  final String taskId;
  final String userId;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String type; // entry or exit
  final String message;
  final bool isActive;
  final DateTime createdAt;

  LocationReminder({
    required this.reminderId,
    required this.taskId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.type,
    required this.message,
    required this.isActive,
    required this.createdAt,
  });

  factory LocationReminder.fromJson(Map<String, dynamic> json) {
    return LocationReminder(
      reminderId: json['reminder_id'] ?? '',
      taskId: json['task_id'] ?? '',
      userId: json['user_id'] ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      type: json['type'] ?? 'entry',
      message: json['message'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reminder_id': reminderId,
      'task_id': taskId,
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'type': type,
      'message': message,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Habit-Goal link model
class HabitGoalLink {
  final String linkId;
  final String habitId;
  final String goalId;
  final double
      contributionWeight; // 0-100, how much this habit contributes to goal
  final DateTime createdAt;

  HabitGoalLink({
    required this.linkId,
    required this.habitId,
    required this.goalId,
    required this.contributionWeight,
    required this.createdAt,
  });

  factory HabitGoalLink.fromJson(Map<String, dynamic> json) {
    return HabitGoalLink(
      linkId: json['link_id'] ?? '',
      habitId: json['habit_id'] ?? '',
      goalId: json['goal_id'] ?? '',
      contributionWeight: (json['contribution_weight'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'link_id': linkId,
      'habit_id': habitId,
      'goal_id': goalId,
      'contribution_weight': contributionWeight,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Goal Milestone model
class GoalMilestone {
  final String milestoneId;
  final String goalId;
  final String title;
  final String? description;
  final DateTime? targetDate;
  final String status; // pending, in_progress, completed
  final double progressContribution; // 0-100, percentage contribution to goal
  final DateTime? completedAt;
  final DateTime createdAt;

  GoalMilestone({
    required this.milestoneId,
    required this.goalId,
    required this.title,
    this.description,
    this.targetDate,
    required this.status,
    required this.progressContribution,
    this.completedAt,
    required this.createdAt,
  });

  factory GoalMilestone.fromJson(Map<String, dynamic> json) {
    return GoalMilestone(
      milestoneId: json['milestone_id'] ?? '',
      goalId: json['goal_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'])
          : null,
      status: json['status'] ?? 'pending',
      progressContribution: (json['progress_contribution'] as num).toDouble(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'milestone_id': milestoneId,
      'goal_id': goalId,
      'title': title,
      'description': description,
      'target_date': targetDate?.toIso8601String(),
      'status': status,
      'progress_contribution': progressContribution,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// GeoFence model for location-based reminders
class GeoFence {
  final String geofenceId;
  final String taskId;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String entryAction; // remind, notify, silent
  final String? exitAction;
  final bool isActive;
  final DateTime createdAt;

  GeoFence({
    required this.geofenceId,
    required this.taskId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.entryAction,
    this.exitAction,
    required this.isActive,
    required this.createdAt,
  });

  factory GeoFence.fromJson(Map<String, dynamic> json) {
    return GeoFence(
      geofenceId: json['geofence_id'] ?? '',
      taskId: json['task_id'] ?? '',
      name: json['name'] ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      entryAction: json['entry_action'] ?? 'remind',
      exitAction: json['exit_action'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'geofence_id': geofenceId,
      'task_id': taskId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'entry_action': entryAction,
      'exit_action': exitAction,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Calculate distance to a point in meters using Haversine formula
  double distanceTo(double lat, double lng) {
    const R = 6371000; // Earth's radius in meters
    final dLat = _toRad(lat - latitude);
    final dLng = _toRad(lng - longitude);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRad(latitude)) *
            cos(_toRad(lat)) *
            (sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Check if a location is within this geofence
  bool isLocationWithin(double lat, double lng) {
    return distanceTo(lat, lng) <= radiusMeters;
  }

  static double _toRad(double deg) => deg * (3.141592653589793 / 180);
}

/// Helper functions
List<UserGoal> parseGoals(List<dynamic> json) {
  return json.map((e) => UserGoal.fromJson(e as Map<String, dynamic>)).toList();
}

List<Habit> parseHabits(List<dynamic> json) {
  return json.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
}

List<UserTask> parseTasks(List<dynamic> json) {
  return json.map((e) => UserTask.fromJson(e as Map<String, dynamic>)).toList();
}

List<LocationReminder> parseLocationReminders(List<dynamic> json) {
  return json
      .map((e) => LocationReminder.fromJson(e as Map<String, dynamic>))
      .toList();
}

List<HabitGoalLink> parseHabitGoalLinks(List<dynamic> json) {
  return json
      .map((e) => HabitGoalLink.fromJson(e as Map<String, dynamic>))
      .toList();
}

List<MoodSnapshot> parseMoodSnapshots(List<dynamic> json) {
  return json
      .map((e) => MoodSnapshot.fromJson(e as Map<String, dynamic>))
      .toList();
}

List<GoalMilestone> parseMilestones(List<dynamic> json) {
  return json
      .map((e) => GoalMilestone.fromJson(e as Map<String, dynamic>))
      .toList();
}

List<GeoFence> parseGeofences(List<dynamic> json) {
  return json.map((e) => GeoFence.fromJson(e as Map<String, dynamic>)).toList();
}
