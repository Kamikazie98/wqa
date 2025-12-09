# WAIQ Flutter Integration Guide

## Overview

WAIQ now has complete integration of:
1. **Task Management System** - Create, track, and manage tasks with recurring support
2. **Goal Tracking with Auto-Update** - Set goals with milestones and auto-progress calculation
3. **Location-Based Reminders** - Geofence-based task reminders
4. **Habit-Goal Linking** - Link habits to goals and track contribution
5. **Daily Program AI Optimizer** - AI-generated daily schedules
6. **Smart Services Architecture** - Reactive streams with RxDart and Riverpod

---

## Project Structure

```
lib/
├── models/
│   └── user_models.dart          # All data models (Tasks, Goals, Geofences, etc.)
├── services/
│   ├── api_client.dart           # HTTP client with auth & error handling
│   ├── location_reminder_service.dart     # Geofencing implementation
│   ├── habit_goal_link_service.dart       # Habit-goal relationships
│   ├── task_management_service.dart       # Task CRUD & filtering
│   ├── goal_management_service.dart       # Goal CRUD & progress tracking
│   ├── daily_program_optimizer_service.dart # AI schedule generation
│   ├── service_providers.dart    # Riverpod providers for all services
│   ├── service_initialization.dart # Initialization & lifecycle management
│   └── notification_service.dart  # Push notifications (existing)
└── screens/
    └── widgets/
        ├── task_list_widget.dart       # Task UI components
        ├── goal_list_widget.dart       # Goal UI components
        └── daily_program_widget.dart   # Daily program UI components
```

---

## Setup Instructions

### 1. Initialize Services in main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/service_initialization.dart';
import 'services/service_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all WAIQ services
  await ServiceContainer.initialize(
    tokenProvider: () {
      // Return your JWT token here
      return getStoredToken();
    },
  );

  // Start background services
  await ServiceContainer.startBackgroundServices();

  runApp(
    ProviderScope(
      overrides: ServiceProviderOverrides.getOverrides(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    // Cleanup on app exit
    ServiceContainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fa', 'IR')],
    );
  }
}
```

---

## Core Services

### Task Management Service

```dart
// Get all tasks
final tasks = await taskService.loadTasks(
  status: 'pending',
  category: 'Work',
  sortByPriority: true,
);

// Create a new task
final task = await taskService.createTask(
  title: 'Complete project report',
  category: 'Work',
  priority: 5,
  dueDate: DateTime.now().add(Duration(days: 3)),
  linkedGoalId: 'goal-123',
);

// Mark as completed
await taskService.completeTask(task!.taskId);

// Create recurring task
await taskService.createRecurringTask(
  title: 'Daily standup',
  category: 'Work',
  pattern: 'daily',
  frequency: 1,
);

// Real-time streaming
final tasksStream = taskService.tasksStream;
tasksStream.listen((tasks) {
  print('Tasks updated: ${tasks.length}');
});
```

### Goal Management Service

```dart
// Create goal with milestones
final goal = await goalService.createGoal(
  title: 'Complete Flutter certification',
  category: 'Learning',
  deadline: DateTime.now().add(Duration(days: 60)),
  milestones: [
    {
      'title': 'Basics',
      'target_date': DateTime.now().add(Duration(days: 15)),
      'progress_contribution': 25,
    },
    {
      'title': 'Intermediate',
      'target_date': DateTime.now().add(Duration(days: 30)),
      'progress_contribution': 35,
    },
    {
      'title': 'Advanced',
      'target_date': DateTime.now().add(Duration(days: 45)),
      'progress_contribution': 40,
    },
  ],
);

// Link task to goal
await goalService.linkTaskToGoal(goal!.goalId, taskId);

// Add milestone
await goalService.addMilestone(
  goal.goalId,
  title: 'Project submission',
  targetDate: DateTime.now().add(Duration(days: 50)),
);

// Get goal progress
final progress = goalService.currentProgress[goal.goalId];
print('Goal progress: ${progress?.progressPercentage}%');
print('Trend: ${progress?.trend}');
print('On track: ${progress?.onTrack}');
```

### Habit-Goal Linking Service

```dart
// Link habit to goal
final link = await habitGoalLinkService.linkHabitToGoal(
  habitId: 'habit-123',
  goalId: 'goal-456',
  contributionWeight: 40.0, // 40% contribution to goal progress
);

// Get habits linked to a goal
final habits = await habitGoalLinkService.getHabitsForGoal(goalId);

// Calculate habit contribution to goals
final contributions = await habitGoalLinkService.calculateHabitContribution(habitId);
// Returns: {'goal-123': 15.5, 'goal-456': 20.3}

// Get analytics
final analytics = await habitGoalLinkService.getHabitGoalAnalytics();
print('Total links: ${analytics['total_links']}');
print('Average effectiveness: ${analytics['average_link_effectiveness']}%');
```

### Location-Based Reminders Service

```dart
// Start location monitoring
await locationService.startLocationMonitoring();

// Create geofence for a task
final geofence = await locationService.createGeofence(
  taskId: 'task-123',
  name: 'Office',
  latitude: 35.7530,
  longitude: 51.3890,
  radiusMeters: 150,
  entryAction: 'remind',
);

// Get nearby geofences
final nearby = await locationService.getNearbyGeofences(radiusKm: 5);

// Update geofence
await locationService.updateGeofence(
  geofence!.geofenceId,
  radiusMeters: 200,
  isActive: true,
);

// Check if location is within geofence
final isWithin = geofence.isLocationWithin(35.75, 51.39);

// Stop monitoring
await locationService.stopLocationMonitoring();
```

### Daily Program Optimizer Service

```dart
// Generate today's program
final program = await programService.generateDailyProgram(
  date: DateTime.now(),
  moodLevel: 'good',
  energyLevel: 'high',
  focusArea: 'work',
);

// Get time blocks
for (final block in program!.timeBlocks) {
  print('${block.title}: ${block.startTime} (${block.durationMinutes} min)');
}

// Complete a time block
await programService.completeBlock(
  program.programId,
  block.blockId,
  actualDurationMinutes: 45,
  feedback: 'productive',
);

// Get next action
final suggestion = await programService.getNextAction();

// Optimize based on feedback
await programService.optimizeProgram(
  program.programId,
  feedback: 'too_easy',
);

// Get program history
final history = await programService.getProgramHistory(days: 30);
```

---

## UI Widget Usage

### In ConsumerWidget

```dart
class TaskDashboard extends ConsumerWidget {
  const TaskDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch real-time task stream
    final tasksAsync = ref.watch(tasksStreamProvider);
    
    // Watch task statistics
    final statsAsync = ref.watch(taskStatsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('کارها')),
      body: Column(
        children: [
          // Stats card
          statsAsync.when(
            data: (stats) => TaskStatsWidget(),
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => Text('خطا: $error'),
          ),
          // Task list
          Expanded(
            child: tasksAsync.when(
              data: (tasks) => TaskListWidget(),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('خطا: $error'),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Task Creation

```dart
class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  int priority = 3;
  String category = 'Personal';

  @override
  Widget build(BuildContext context) {
    final taskService = ref.watch(taskManagementServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ایجاد کار')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              label: Text('عنوان'),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              label: Text('توضیح'),
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Slider(
            value: priority.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: 'اولویت: $priority',
            onChanged: (value) => setState(() => priority = value.toInt()),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final task = await taskService.createTask(
                title: titleController.text,
                description: descriptionController.text,
                category: category,
                priority: priority,
              );
              if (task != null) {
                Navigator.pop(context);
              }
            },
            child: const Text('ایجاد'),
          ),
        ],
      ),
    );
  }
}
```

---

## Stream Providers Available

| Provider | Type | Returns |
|----------|------|---------|
| `tasksStreamProvider` | Stream | `List<UserTask>` |
| `goalsStreamProvider` | Stream | `List<UserGoal>` |
| `taskStatsStreamProvider` | Stream | `TaskStats` |
| `goalProgressStreamProvider` | Stream | `Map<String, GoalProgress>` |
| `dailyProgramStreamProvider` | Stream | `DailyProgram?` |
| `habitGoalLinksStreamProvider` | Stream | `List<HabitGoalLink>` |
| `overdueTasksProvider` | Future | `List<UserTask>` |
| `todayTasksProvider` | Future | `List<UserTask>` |
| `activeGoalsProvider` | Future | `List<UserGoal>` |
| `todayProgramProvider` | Future | `DailyProgram?` |
| `goalStatsProvider` | Future | `GoalStats?` |
| `activeGeofencesStreamProvider` | Future | `List<GeoFence>` |
| `nearbyGeofencesProvider` | Future | `List<GeoFence>` |

---

## API Endpoints Integration

The following backend endpoints are now fully utilized:

### Tasks
- `POST /tasks` - Create task
- `GET /tasks` - List tasks
- `GET /tasks/{id}` - Get task
- `PUT /tasks/{id}` - Update task
- `DELETE /tasks/{id}` - Delete task
- `POST /tasks/{id}/complete` - Mark complete
- `POST /tasks/recurring` - Create recurring task

### Goals
- `POST /user/goals` - Create goal
- `GET /user/goals` - List goals with progress
- `PUT /user/goals/{id}` - Update goal
- `DELETE /user/goals/{id}` - Archive goal
- `POST /user/goals/{id}/link-task` - Link task
- `POST /user/goals/{id}/milestones` - Add milestone
- `PUT /user/goals/{id}/milestones/{mid}` - Update milestone

### Location
- `POST /user/geofences` - Create geofence
- `GET /user/geofences` - List geofences
- `PUT /user/geofences/{id}` - Update geofence
- `DELETE /user/geofences/{id}` - Delete geofence
- `POST /user/geofences/{id}/checkin` - Log checkin

### Habits-Goals
- `POST /user/habits/{id}/goals/{gid}/link` - Link habit to goal
- `DELETE /user/habits/{id}/goals/{gid}/link` - Unlink
- `GET /user/goals/{id}/linked-habits` - Get linked habits

### Daily Program
- `POST /user/daily-program/generate` - Generate program
- `GET /user/daily-program/today` - Get today's program
- `GET /user/daily-program/next-action` - Get next action
- `POST /user/daily-program/{id}/blocks/{bid}/complete` - Complete block

---

## Best Practices

1. **Always use Riverpod providers** instead of directly instantiating services
2. **Use `.when()` for AsyncValue** to handle loading/error/data states
3. **Watch streams** in ConsumerWidget for real-time updates
4. **Dispose services** properly in `dispose()` method
5. **Use `autoDispose`** for providers to free memory when unused
6. **Cache data locally** using BehaviorSubject for instant updates
7. **Handle errors gracefully** with user-friendly messages

---

## Debugging

Enable debug logging:

```dart
// In service_initialization.dart
debugPrint('Message'); // Will show in Debug Console
```

Check service status:

```dart
// Check if location monitoring is active
if (ServiceContainer.locationReminderService.isMonitoring) {
  print('Location monitoring is active');
}

// Check cached data
final tasks = ServiceContainer.taskManagementService.currentTasks;
print('Cached tasks: ${tasks.length}');
```

---

## Next Steps

1. Connect UI screens to service providers
2. Implement error handling UI components
3. Add analytics and logging
4. Set up local notifications for reminders
5. Implement push notification integration
6. Add offline sync support
7. Create comprehensive UI for all features

---

## Support

For issues or questions, refer to:
- Service class documentation
- Model definitions in `user_models.dart`
- Example widgets in `screens/widgets/`
- Backend API documentation
