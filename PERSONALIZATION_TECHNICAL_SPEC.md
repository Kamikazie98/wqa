ا.# 🛠️ WAIQ Personalization: Technical Specification for Developers

## Architecture Overview

### Current Architecture
```
┌─────────────────────────────────┐
│   UI Layer (Screens/Widgets)    │
├─────────────────────────────────┤
│   Controller Layer               │
│   (ChatController, etc)          │
├─────────────────────────────────┤
│   Service Layer                  │
│   (AssistantService, etc)        │
├─────────────────────────────────┤
│   API Client Layer               │
│   (ApiClient wrapper)            │
├─────────────────────────────────┤
│   Data Layer                     │
│   (SharedPreferences/Backend)    │
└─────────────────────────────────┘
```

### New Personalization Layer
```
┌─────────────────────────────────┐
│   NEW Program UI Layer          │
│   (DailyProgramScreen, etc)     │
├─────────────────────────────────┤
│   NEW Program Logic              │
│   (DailyProgramService, etc)    │
├─────────────────────────────────┤
│   ENHANCED Services              │
│   (User Profile, Analytics)     │
├─────────────────────────────────┤
│   Existing API Clients           │
└─────────────────────────────────┘
```

---

## Phase 1: User Profile System (Weeks 1-2)

### 1.1 Models
**File:** `lib/models/user_models.dart`

```dart
/// User profile with basic information
class UserProfile {
  final String userId;
  final String name;
  final String role; // Student, Professional, Entrepreneur, etc.
  final String timezone; // Asia/Tehran, etc.
  final List<String> interests; // Tags of interests
  
  // Schedule info
  final int wakeUpTime; // 0-23 (6 = 6:00 AM)
  final int sleepTime; // 0-23 (23 = 11:00 PM)
  final int focusHours; // Max daily focus hours
  
  // Calculated/derived
  int? avgEnergy; // Avg energy level 1-10
  int? avgMood; // Avg mood level 1-10
  DateTime? lastMoodUpdate;
  List<String>? activeGoalIds;
  
  // Preferences
  int preferredBreakDuration; // Minutes
  bool enableMotivation;
  String communicationStyle; // Formal, Casual, Motivational
  bool trackHabits;
  
  // Timestamps
  DateTime createdAt;
  DateTime updatedAt;
  
  UserProfile({
    required this.userId,
    required this.name,
    required this.role,
    required this.timezone,
    required this.interests,
    required this.wakeUpTime,
    required this.sleepTime,
    required this.focusHours,
    required this.createdAt,
    required this.updatedAt,
    this.avgEnergy,
    this.avgMood,
    this.lastMoodUpdate,
    this.activeGoalIds,
    this.preferredBreakDuration = 15,
    this.enableMotivation = true,
    this.communicationStyle = 'Casual',
    this.trackHabits = true,
  });
  
  // JSON serialization
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      timezone: json['timezone'] as String,
      interests: List<String>.from(json['interests'] as List),
      wakeUpTime: json['wake_up_time'] as int,
      sleepTime: json['sleep_time'] as int,
      focusHours: json['focus_hours'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      avgEnergy: json['avg_energy'] as int?,
      avgMood: json['avg_mood'] as int?,
      lastMoodUpdate: json['last_mood_update'] != null 
        ? DateTime.parse(json['last_mood_update'] as String)
        : null,
      activeGoalIds: List<String>.from(json['active_goal_ids'] as List? ?? []),
      preferredBreakDuration: json['preferred_break_duration'] as int? ?? 15,
      enableMotivation: json['enable_motivation'] as bool? ?? true,
      communicationStyle: json['communication_style'] as String? ?? 'Casual',
      trackHabits: json['track_habits'] as bool? ?? true,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'role': role,
    'timezone': timezone,
    'interests': interests,
    'wake_up_time': wakeUpTime,
    'sleep_time': sleepTime,
    'focus_hours': focusHours,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'avg_energy': avgEnergy,
    'avg_mood': avgMood,
    'last_mood_update': lastMoodUpdate?.toIso8601String(),
    'active_goal_ids': activeGoalIds,
    'preferred_break_duration': preferredBreakDuration,
    'enable_motivation': enableMotivation,
    'communication_style': communicationStyle,
    'track_habits': trackHabits,
  };
}

/// User goal with milestones
class UserGoal {
  final String id;
  final String userId;
  final String title;
  final String category; // Work, Health, Learning, Personal
  final String description;
  
  final DateTime createdAt;
  final DateTime deadline;
  
  final int priority; // 1-5 (5 = highest)
  
  // Tracking
  final List<String> milestones; // Subtasks
  int progressPercentage; // 0-100
  DateTime? completedAt;
  
  GoalStatus status; // Active, Completed, Archived
  
  UserGoal({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.description,
    required this.createdAt,
    required this.deadline,
    required this.priority,
    this.milestones = const [],
    this.progressPercentage = 0,
    this.completedAt,
    this.status = GoalStatus.active,
  });
  
  // Days until deadline
  int get daysUntilDeadline {
    return deadline.difference(DateTime.now()).inDays;
  }
  
  // Is overdue?
  bool get isOverdue {
    return DateTime.now().isAfter(deadline) && status != GoalStatus.completed;
  }
  
  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      deadline: DateTime.parse(json['deadline'] as String),
      priority: json['priority'] as int,
      milestones: List<String>.from(json['milestones'] as List? ?? []),
      progressPercentage: json['progress_percentage'] as int? ?? 0,
      completedAt: json['completed_at'] != null 
        ? DateTime.parse(json['completed_at'] as String)
        : null,
      status: GoalStatus.values.firstWhere(
        (s) => s.toString() == 'GoalStatus.${json['status']}',
        orElse: () => GoalStatus.active,
      ),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'category': category,
    'description': description,
    'created_at': createdAt.toIso8601String(),
    'deadline': deadline.toIso8601String(),
    'priority': priority,
    'milestones': milestones,
    'progress_percentage': progressPercentage,
    'completed_at': completedAt?.toIso8601String(),
    'status': status.toString().split('.').last,
  };
}

enum GoalStatus { active, completed, archived }

/// Mood snapshot for tracking energy/mood over time
class MoodSnapshot {
  final String id;
  final String userId;
  
  final DateTime timestamp;
  
  final int energy; // 1-10 scale
  final int mood; // 1-10 scale
  
  final String context; // "At work", "Home", etc.
  final String? activity; // "Coding", "Exercising", etc.
  final String? notes;
  
  MoodSnapshot({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.energy,
    required this.mood,
    required this.context,
    this.activity,
    this.notes,
  });
  
  factory MoodSnapshot.fromJson(Map<String, dynamic> json) {
    return MoodSnapshot(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      energy: json['energy'] as int,
      mood: json['mood'] as int,
      context: json['context'] as String,
      activity: json['activity'] as String?,
      notes: json['notes'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'timestamp': timestamp.toIso8601String(),
    'energy': energy,
    'mood': mood,
    'context': context,
    'activity': activity,
    'notes': notes,
  };
}
```

### 1.2 Service Implementation
**File:** `lib/services/user_profile_service.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_models.dart';
import 'api_client.dart';

class UserProfileService {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;
  
  static const _profileCacheKey = 'profile.cache';
  static const _goalsCacheKey = 'goals.cache';
  static const _moodCacheKey = 'mood.snapshots';
  
  UserProfileService({
    required ApiClient apiClient,
    required SharedPreferences prefs,
  })  : _apiClient = apiClient,
        _prefs = prefs;
  
  // ═══════════════════════════════════
  // PROFILE MANAGEMENT
  // ═══════════════════════════════════
  
  /// Get or create user profile
  Future<UserProfile> getProfile(String userId) async {
    try {
      // Try API first
      final response = await _apiClient.getJson('/user/profile');
      final profile = UserProfile.fromJson(response);
      
      // Cache locally
      await _prefs.setString(_profileCacheKey, jsonEncode(profile.toJson()));
      
      return profile;
    } catch (e) {
      // Fallback to cache
      final cached = _prefs.getString(_profileCacheKey);
      if (cached != null) {
        return UserProfile.fromJson(jsonDecode(cached));
      }
      rethrow;
    }
  }
  
  /// Create new profile (onboarding)
  Future<UserProfile> setupProfile({
    required String name,
    required String role,
    required String timezone,
    required List<String> interests,
    required int wakeUpTime,
    required int sleepTime,
    required int focusHours,
  }) async {
    final now = DateTime.now();
    final profile = UserProfile(
      userId: _getCurrentUserId(), // From AuthController
      name: name,
      role: role,
      timezone: timezone,
      interests: interests,
      wakeUpTime: wakeUpTime,
      sleepTime: sleepTime,
      focusHours: focusHours,
      createdAt: now,
      updatedAt: now,
    );
    
    // Send to backend
    await _apiClient.postJson('/user/profile/setup', body: profile.toJson());
    
    // Cache locally
    await _prefs.setString(_profileCacheKey, jsonEncode(profile.toJson()));
    
    return profile;
  }
  
  /// Update profile
  Future<UserProfile> updateProfile({
    required String name,
    required String timezone,
    required List<String> interests,
    required int preferredBreakDuration,
    required bool enableMotivation,
    required String communicationStyle,
  }) async {
    final current = await getProfile(_getCurrentUserId());
    
    final updated = UserProfile(
      userId: current.userId,
      name: name,
      role: current.role,
      timezone: timezone,
      interests: interests,
      wakeUpTime: current.wakeUpTime,
      sleepTime: current.sleepTime,
      focusHours: current.focusHours,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      avgEnergy: current.avgEnergy,
      avgMood: current.avgMood,
      lastMoodUpdate: current.lastMoodUpdate,
      activeGoalIds: current.activeGoalIds,
      preferredBreakDuration: preferredBreakDuration,
      enableMotivation: enableMotivation,
      communicationStyle: communicationStyle,
      trackHabits: current.trackHabits,
    );
    
    await _apiClient.putJson('/user/profile/update', body: updated.toJson());
    await _prefs.setString(_profileCacheKey, jsonEncode(updated.toJson()));
    
    return updated;
  }
  
  // ═══════════════════════════════════
  // GOAL MANAGEMENT
  // ═══════════════════════════════════
  
  /// Add new goal
  Future<UserGoal> addGoal({
    required String title,
    required String category,
    required DateTime deadline,
    required int priority,
    required String description,
    List<String>? milestones,
  }) async {
    final goal = UserGoal(
      id: const Uuid().v4(),
      userId: _getCurrentUserId(),
      title: title,
      category: category,
      description: description,
      createdAt: DateTime.now(),
      deadline: deadline,
      priority: priority,
      milestones: milestones ?? [],
    );
    
    await _apiClient.postJson('/user/goals', body: goal.toJson());
    
    // Update cache
    final goals = await getGoals();
    await _prefs.setString(_goalsCacheKey, jsonEncode(goals.map((g) => g.toJson()).toList()));
    
    return goal;
  }
  
  /// Get all goals for user
  Future<List<UserGoal>> getGoals() async {
    try {
      final response = await _apiClient.getJson('/user/goals') as List;
      return response.map((json) => UserGoal.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = _prefs.getString(_goalsCacheKey);
      if (cached != null) {
        final list = jsonDecode(cached) as List;
        return list.map((json) => UserGoal.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }
  
  /// Update goal progress
  Future<void> updateGoalProgress(String goalId, int percentage) async {
    await _apiClient.putJson('/user/goals/$goalId', body: {
      'progress_percentage': percentage,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
  
  /// Mark goal as completed
  Future<void> completeGoal(String goalId) async {
    await _apiClient.putJson('/user/goals/$goalId/complete', body: {
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    });
  }
  
  // ═══════════════════════════════════
  // MOOD TRACKING
  // ═══════════════════════════════════
  
  /// Record mood snapshot
  Future<MoodSnapshot> recordMood({
    required int energy,
    required int mood,
    required String context,
    String? activity,
    String? notes,
  }) async {
    final snapshot = MoodSnapshot(
      id: const Uuid().v4(),
      userId: _getCurrentUserId(),
      timestamp: DateTime.now(),
      energy: energy,
      mood: mood,
      context: context,
      activity: activity,
      notes: notes,
    );
    
    await _apiClient.postJson('/user/mood/snapshot', body: snapshot.toJson());
    
    return snapshot;
  }
  
  /// Get mood history (last N snapshots)
  Future<List<MoodSnapshot>> getMoodHistory({int last = 30}) async {
    try {
      final response = await _apiClient.getJson('/user/mood/history?last=$last') as List;
      return response.map((json) => MoodSnapshot.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Get average mood/energy for today
  Future<Map<String, int>> getTodaysMoodAverage() async {
    final today = DateTime.now();
    final history = await getMoodHistory(last: 100);
    
    final todaySnapshots = history.where((s) => 
      s.timestamp.year == today.year &&
      s.timestamp.month == today.month &&
      s.timestamp.day == today.day
    ).toList();
    
    if (todaySnapshots.isEmpty) {
      return {'energy': 5, 'mood': 5};
    }
    
    final avgEnergy = (todaySnapshots.fold<int>(0, (sum, s) => sum + s.energy) ~/ todaySnapshots.length).clamp(1, 10);
    final avgMood = (todaySnapshots.fold<int>(0, (sum, s) => sum + s.mood) ~/ todaySnapshots.length).clamp(1, 10);
    
    return {'energy': avgEnergy, 'mood': avgMood};
  }
  
  // ═══════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════
  
  String _getCurrentUserId() {
    // TODO: Get from AuthController
    return 'user123';
  }
  
  void clearCache() {
    _prefs.remove(_profileCacheKey);
    _prefs.remove(_goalsCacheKey);
    _prefs.remove(_moodCacheKey);
  }
}
```

### 1.3 Backend API Endpoints (Required)

```
POST /user/profile/setup
├── Body: UserProfile.toJson()
└── Returns: UserProfile

GET /user/profile
├── Params: None
└── Returns: UserProfile

PUT /user/profile/update
├── Body: Updated fields
└── Returns: UserProfile

POST /user/goals
├── Body: UserGoal.toJson()
└── Returns: UserGoal

GET /user/goals
├── Query: ?status=active|completed|archived
└── Returns: List<UserGoal>

GET /user/goals/:id
├── Params: goalId
└── Returns: UserGoal

PUT /user/goals/:id
├── Body: Updated fields
└── Returns: UserGoal

PUT /user/goals/:id/complete
├── Body: { status: "completed", completed_at: timestamp }
└── Returns: UserGoal

POST /user/mood/snapshot
├── Body: MoodSnapshot.toJson()
└── Returns: MoodSnapshot

GET /user/mood/history
├── Query: ?last=30
└── Returns: List<MoodSnapshot>
```

---

## Phase 2: Daily Program Service (Weeks 3-5)

### 2.1 Models
**File:** `lib/models/program_models.dart`

```dart
class DailyProgram {
  final String id;
  final String userId;
  final DateTime date;
  
  // Structure
  final List<ProgramBlock> blocks; // Morning, Afternoon, Evening
  
  // Content
  final String dailyTheme;
  final String motivationalMessage;
  final String recommendation; // What to do first
  
  // Metadata
  final DateTime generatedAt;
  int completionPercentage; // 0-100
  bool isCompleted;
  
  // Total times
  int get totalScheduledMinutes => blocks.fold(0, (sum, b) => sum + b.totalMinutes);
  int get totalBreakMinutes => blocks.fold(0, (sum, b) => sum + b.breakMinutes);
  int get focusSessionCount => blocks.fold(0, (sum, b) => sum + b.tasks.length);
  
  DailyProgram({
    required this.id,
    required this.userId,
    required this.date,
    required this.blocks,
    required this.dailyTheme,
    required this.motivationalMessage,
    required this.recommendation,
    required this.generatedAt,
    this.completionPercentage = 0,
    this.isCompleted = false,
  });
  
  factory DailyProgram.fromJson(Map<String, dynamic> json) {
    return DailyProgram(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      blocks: (json['blocks'] as List).map((b) => ProgramBlock.fromJson(b as Map<String, dynamic>)).toList(),
      dailyTheme: json['daily_theme'] as String,
      motivationalMessage: json['motivational_message'] as String,
      recommendation: json['recommendation'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      completionPercentage: json['completion_percentage'] as int? ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'date': date.toIso8601String(),
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'daily_theme': dailyTheme,
    'motivational_message': motivationalMessage,
    'recommendation': recommendation,
    'generated_at': generatedAt.toIso8601String(),
    'completion_percentage': completionPercentage,
    'is_completed': isCompleted,
  };
}

class ProgramBlock {
  final String name; // Morning, Afternoon, Evening
  final int startHour;
  final int endHour;
  
  final List<ScheduledTask> tasks;
  final List<BreakSuggestion> breaks;
  
  int? completedPercentage;
  
  int get totalMinutes => (endHour - startHour) * 60;
  int get breakMinutes => breaks.fold(0, (sum, b) => sum + b.duration);
  
  ProgramBlock({
    required this.name,
    required this.startHour,
    required this.endHour,
    required this.tasks,
    required this.breaks,
    this.completedPercentage,
  });
  
  factory ProgramBlock.fromJson(Map<String, dynamic> json) {
    return ProgramBlock(
      name: json['name'] as String,
      startHour: json['start_hour'] as int,
      endHour: json['end_hour'] as int,
      tasks: (json['tasks'] as List).map((t) => ScheduledTask.fromJson(t as Map<String, dynamic>)).toList(),
      breaks: (json['breaks'] as List).map((b) => BreakSuggestion.fromJson(b as Map<String, dynamic>)).toList(),
      completedPercentage: json['completed_percentage'] as int?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'start_hour': startHour,
    'end_hour': endHour,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'breaks': breaks.map((b) => b.toJson()).toList(),
    'completed_percentage': completedPercentage,
  };
}

class ScheduledTask {
  final String id;
  final String title;
  final String category; // From goal or suggested
  final String? description;
  
  final int estimatedMinutes;
  final int priority; // 1-5
  final int energyRequired; // 1-10 (how much energy this task needs)
  
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  
  final String? tool; // 'chat', 'instagram', 'research', etc.
  final String? context; // Additional context or notes
  final String? linkedGoalId; // Link to user's goal
  
  // Tracking
  TaskStatus status; // Pending, InProgress, Completed, Skipped
  int? actualMinutes;
  String? notes;
  
  ScheduledTask({
    required this.id,
    required this.title,
    required this.category,
    required this.estimatedMinutes,
    required this.priority,
    required this.energyRequired,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.description,
    this.tool,
    this.context,
    this.linkedGoalId,
    this.status = TaskStatus.pending,
    this.actualMinutes,
    this.notes,
  });
  
  factory ScheduledTask.fromJson(Map<String, dynamic> json) {
    return ScheduledTask(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      estimatedMinutes: json['estimated_minutes'] as int,
      priority: json['priority'] as int,
      energyRequired: json['energy_required'] as int,
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
      description: json['description'] as String?,
      tool: json['tool'] as String?,
      context: json['context'] as String?,
      linkedGoalId: json['linked_goal_id'] as String?,
      status: TaskStatus.values.firstWhere(
        (s) => s.toString() == 'TaskStatus.${json['status']}',
        orElse: () => TaskStatus.pending,
      ),
      actualMinutes: json['actual_minutes'] as int?,
      notes: json['notes'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'estimated_minutes': estimatedMinutes,
    'priority': priority,
    'energy_required': energyRequired,
    'scheduled_start': scheduledStart.toIso8601String(),
    'scheduled_end': scheduledEnd.toIso8601String(),
    'description': description,
    'tool': tool,
    'context': context,
    'linked_goal_id': linkedGoalId,
    'status': status.toString().split('.').last,
    'actual_minutes': actualMinutes,
    'notes': notes,
  };
}

enum TaskStatus { pending, inProgress, completed, skipped }

class BreakSuggestion {
  final String id;
  final DateTime scheduledTime;
  final int duration; // Minutes
  
  final BreakType type; // Physical, Mental, Social, Nutrition
  final String suggestion; // "Stretch", "Walk", "Breathe", etc.
  final String reason; // Why this break
  
  bool completed;
  
  BreakSuggestion({
    required this.id,
    required this.scheduledTime,
    required this.duration,
    required this.type,
    required this.suggestion,
    required this.reason,
    this.completed = false,
  });
  
  factory BreakSuggestion.fromJson(Map<String, dynamic> json) {
    return BreakSuggestion(
      id: json['id'] as String,
      scheduledTime: DateTime.parse(json['scheduled_time'] as String),
      duration: json['duration'] as int,
      type: BreakType.values.firstWhere(
        (t) => t.toString() == 'BreakType.${json['type']}',
      ),
      suggestion: json['suggestion'] as String,
      reason: json['reason'] as String,
      completed: json['completed'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'scheduled_time': scheduledTime.toIso8601String(),
    'duration': duration,
    'type': type.toString().split('.').last,
    'suggestion': suggestion,
    'reason': reason,
    'completed': completed,
  };
}

enum BreakType { physical, mental, social, nutrition }
```

### 2.2 Daily Program Service
**File:** `lib/services/daily_program_service.dart`

```dart
import 'package:uuid/uuid.dart';
import '../models/program_models.dart';
import '../models/user_models.dart';
import 'api_client.dart';

class DailyProgramService {
  final ApiClient _apiClient;
  
  DailyProgramService({required ApiClient apiClient}) : _apiClient = apiClient;
  
  /// Generate daily program
  Future<DailyProgram> generateDailyProgram({
    required String userId,
    required UserProfile profile,
    required List<UserGoal> activeGoals,
    int? energyLevel, // Override with current energy
    int? moodLevel,
    List<String>? prioritizedGoalIds,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/program/generate',
        body: {
          'user_id': userId,
          'profile': profile.toJson(),
          'active_goals': activeGoals.map((g) => g.toJson()).toList(),
          'energy_level': energyLevel,
          'mood_level': moodLevel,
          'prioritized_goal_ids': prioritizedGoalIds,
          'date': DateTime.now().toIso8601String(),
        },
      );
      
      return DailyProgram.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      // Fallback: Generate locally if API fails
      return _generateLocalProgram(
        userId: userId,
        profile: profile,
        activeGoals: activeGoals,
        energyLevel: energyLevel ?? 5,
      );
    }
  }
  
  /// Get program for specific date
  Future<DailyProgram?> getProgram(String userId, DateTime date) async {
    try {
      final response = await _apiClient.getJson(
        '/program/${date.toIso8601String().split('T')[0]}',
      );
      return DailyProgram.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
  
  /// Update task status
  Future<void> updateTaskStatus(
    String programId,
    String taskId,
    TaskStatus status, {
    int? actualMinutes,
    String? notes,
  }) async {
    await _apiClient.putJson(
      '/program/$programId/task/$taskId',
      body: {
        'status': status.toString().split('.').last,
        'actual_minutes': actualMinutes,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }
  
  /// Mark break as completed
  Future<void> completeBreak(String programId, String breakId) async {
    await _apiClient.putJson(
      '/program/$programId/break/$breakId',
      body: {
        'completed': true,
        'completed_at': DateTime.now().toIso8601String(),
      },
    );
  }
  
  /// Get daily program feedback
  Future<void> recordProgramFeedback({
    required String programId,
    required int completionPercentage,
    required bool achieved,
    required String? feedback,
  }) async {
    await _apiClient.postJson(
      '/program/$programId/feedback',
      body: {
        'completion_percentage': completionPercentage,
        'achieved': achieved,
        'feedback': feedback,
        'recorded_at': DateTime.now().toIso8601String(),
      },
    );
  }
  
  // ═══════════════════════════════════
  // LOCAL PROGRAM GENERATION (FALLBACK)
  // ═══════════════════════════════════
  
  /// Generate program locally (no internet)
  DailyProgram _generateLocalProgram({
    required String userId,
    required UserProfile profile,
    required List<UserGoal> activeGoals,
    required int energyLevel,
  }) {
    const uuid = Uuid();
    final now = DateTime.now();
    final blocks = <ProgramBlock>[];
    
    // Morning block (high energy work)
    blocks.add(_createMorningBlock(
      activeGoals: activeGoals,
      profile: profile,
      energyLevel: energyLevel,
    ));
    
    // Afternoon block (medium energy)
    blocks.add(_createAfternoonBlock(
      activeGoals: activeGoals,
      profile: profile,
    ));
    
    // Evening block (low energy / maintenance)
    blocks.add(_createEveningBlock(
      profile: profile,
    ));
    
    return DailyProgram(
      id: uuid.v4(),
      userId: userId,
      date: now,
      blocks: blocks,
      dailyTheme: _getThemeForDay(activeGoals, energyLevel),
      motivationalMessage: _getMotivation(energyLevel),
      recommendation: 'Start with your most important task in the morning',
      generatedAt: now,
    );
  }
  
  ProgramBlock _createMorningBlock({
    required List<UserGoal> activeGoals,
    required UserProfile profile,
    required int energyLevel,
  }) {
    const uuid = Uuid();
    final tasks = <ScheduledTask>[];
    final breaks = <BreakSuggestion>[];
    
    // Top priority task
    if (activeGoals.isNotEmpty) {
      final topGoal = activeGoals
        .where((g) => g.status == GoalStatus.active)
        .fold<UserGoal?>(null, (prev, curr) {
          if (prev == null) return curr;
          if (curr.priority > prev.priority) return curr;
          if (curr.daysUntilDeadline < prev.daysUntilDeadline) return curr;
          return prev;
        });
      
      if (topGoal != null) {
        tasks.add(ScheduledTask(
          id: uuid.v4(),
          title: topGoal.title,
          category: topGoal.category,
          description: topGoal.description,
          estimatedMinutes: 120,
          priority: 5,
          energyRequired: 9,
          scheduledStart: DateTime(2024, 12, 6, profile.wakeUpTime),
          scheduledEnd: DateTime(2024, 12, 6, profile.wakeUpTime + 2),
          linkedGoalId: topGoal.id,
          tool: _recommendToolForGoal(topGoal),
        ));
      }
    }
    
    // Break
    breaks.add(BreakSuggestion(
      id: uuid.v4(),
      scheduledTime: DateTime(2024, 12, 6, profile.wakeUpTime + 2),
      duration: 15,
      type: BreakType.physical,
      suggestion: 'Stretch or take a short walk',
      reason: 'You\'ve been focused for 2 hours',
    ));
    
    return ProgramBlock(
      name: 'Morning',
      startHour: profile.wakeUpTime,
      endHour: 12,
      tasks: tasks,
      breaks: breaks,
    );
  }
  
  ProgramBlock _createAfternoonBlock({
    required List<UserGoal> activeGoals,
    required UserProfile profile,
  }) {
    const uuid = Uuid();
    return ProgramBlock(
      name: 'Afternoon',
      startHour: 12,
      endHour: 18,
      tasks: [],
      breaks: [
        BreakSuggestion(
          id: uuid.v4(),
          scheduledTime: DateTime(2024, 12, 6, 15),
          duration: 20,
          type: BreakType.nutrition,
          suggestion: 'Have a snack or light meal',
          reason: 'Mid-afternoon energy boost',
        ),
      ],
    );
  }
  
  ProgramBlock _createEveningBlock({
    required UserProfile profile,
  }) {
    return ProgramBlock(
      name: 'Evening',
      startHour: 18,
      endHour: profile.sleepTime,
      tasks: [],
      breaks: [],
    );
  }
  
  String _getThemeForDay(List<UserGoal> goals, int energyLevel) {
    if (energyLevel >= 8) return '💪 Power Day - High Energy';
    if (energyLevel >= 6) return '⚡ Normal Day - Balanced Focus';
    return '🌙 Light Day - Easy Going';
  }
  
  String _getMotivation(int energyLevel) {
    if (energyLevel >= 8) {
      return 'Your energy is through the roof! Perfect day for tackling difficult tasks.';
    } else if (energyLevel >= 6) {
      return 'You\'re in a good place. Let\'s balance focus with self-care.';
    } else {
      return 'Take it easy today. Focus on small wins and recharge.';
    }
  }
  
  String? _recommendToolForGoal(UserGoal goal) {
    switch (goal.category) {
      case 'Writing':
        return 'chat';
      case 'Research':
        return 'research';
      case 'Social Media':
        return 'instagram';
      default:
        return null;
    }
  }
}
```

### 2.3 Backend API Endpoints (Required)

```
POST /program/generate
├── Body: { user_id, profile, active_goals, energy_level, mood_level, prioritized_goal_ids, date }
└── Returns: DailyProgram

GET /program/:date
├── Params: date (YYYY-MM-DD)
└── Returns: DailyProgram

PUT /program/:programId/task/:taskId
├── Body: { status, actual_minutes, notes, updated_at }
└── Returns: ScheduledTask

PUT /program/:programId/break/:breakId
├── Body: { completed, completed_at }
└── Returns: BreakSuggestion

POST /program/:programId/feedback
├── Body: { completion_percentage, achieved, feedback, recorded_at }
└── Returns: { status, message }
```

---

## Phase 3: Integration Points

### 3.1 Existing Service Enhancements

**Update LocalNLPProcessor:**
```dart
// Add to local_nlp_processor.dart
Future<Map<String, dynamic>?> classifyIntentWithContext(
  String text,
  DailyProgram? todaysProgram,
  UserProfile? profile,
) async {
  // If user says "what's next", recommend next task from program
  if (text.contains('what') && text.contains('next')) {
    if (todaysProgram != null) {
      final nextTask = _getNextIncompleteTask(todaysProgram);
      if (nextTask != null) {
        return {
          'action': 'suggest_task',
          'task': nextTask.toJson(),
          'confidence': 0.9,
        };
      }
    }
  }
  
  // Continue with existing intent classification
  return classifyIntentLocally(text);
}
```

**Update ProactiveAutomationService:**
```dart
// Add to proactive_automation_service.dart
Future<void> suggestNextTaskFromProgram(DailyProgram program) async {
  final nextTask = _getNextIncompleteTask(program);
  if (nextTask != null) {
    // Show proactive suggestion
    await _showProactiveSuggestion(
      title: nextTask.title,
      description: 'Next task in your daily program',
      tool: nextTask.tool,
    );
  }
}
```

---

## Implementation Checklist

### Code Files to Create

- [ ] `lib/models/user_models.dart` - Profile, Goal, Mood models
- [ ] `lib/models/program_models.dart` - Program, Block, Task models
- [ ] `lib/services/user_profile_service.dart` - Profile management
- [ ] `lib/services/daily_program_service.dart` - Program generation
- [ ] `lib/services/habit_service.dart` - Habit tracking
- [ ] `lib/services/smart_suggestion_engine.dart` - Recommendations
- [ ] `lib/services/personal_program_analytics.dart` - Analytics
- [ ] `lib/screens/profile_setup_screen.dart` - Onboarding
- [ ] `lib/screens/daily_program_screen.dart` - Main display
- [ ] `lib/screens/habits_screen.dart` - Habit dashboard
- [ ] `lib/screens/program_analytics_screen.dart` - Analytics
- [ ] `lib/widgets/mood_selector_widget.dart` - Mood input
- [ ] `lib/widgets/program_block_widget.dart` - Block display
- [ ] `lib/widgets/scheduled_task_widget.dart` - Task cards
- [ ] `lib/widgets/habit_card_widget.dart` - Habit progress

### Backend Endpoints to Create

- [ ] 8x `/user/profile/*` endpoints
- [ ] 6x `/user/goals/*` endpoints
- [ ] 2x `/user/mood/*` endpoints
- [ ] 5x `/program/*` endpoints
- [ ] 6x `/habits/*` endpoints
- [ ] 3x `/analytics/*` endpoints

---

**Total Lines of Code:** ~2500 Dart + ~400 SQL (backend)  
**Estimated Timeline:** 7-12 weeks  
**Team Size:** 2-3 developers
