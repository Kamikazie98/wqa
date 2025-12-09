h# ⚡ WAIQ Flutter Quick Reference

## 🚀 Quick Start (Copy-Paste Ready)

### Initialize in main.dart
```dart
import 'services/service_initialization.dart';
import 'services/service_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await ServiceContainer.initialize(
    tokenProvider: () => getToken(),
  );
  
  await ServiceContainer.startBackgroundServices();
  
  runApp(
    ProviderScope(
      overrides: ServiceProviderOverrides.getOverrides(),
      child: const MyApp(),
    ),
  );
}
```

---

## 📋 Common Tasks

### Create a Task
```dart
final taskService = ref.watch(taskManagementServiceProvider);

final task = await taskService.createTask(
  title: 'Complete project',
  category: 'Work',
  priority: 4,
  dueDate: DateTime.now().add(Duration(days: 3)),
);
```

### Watch Tasks in Real-Time
```dart
final tasksAsync = ref.watch(tasksStreamProvider);

tasksAsync.when(
  data: (tasks) => Text('${tasks.length} tasks'),
  loading: () => CircularProgressIndicator(),
  error: (err, st) => Text('Error: $err'),
);
```

### Create a Goal with Milestones
```dart
final goalService = ref.watch(goalManagementServiceProvider);

final goal = await goalService.createGoal(
  title: 'Learn Flutter',
  category: 'Learning',
  deadline: DateTime.now().add(Duration(days: 60)),
);

// Add milestone
await goalService.addMilestone(
  goal!.goalId,
  title: 'Complete basics',
  targetDate: DateTime.now().add(Duration(days: 20)),
);
```

### Link Task to Goal
```dart
await goalService.linkTaskToGoal(goalId, taskId);
```

### Link Habit to Goal
```dart
final linkService = ref.watch(habitGoalLinkServiceProvider);

await linkService.linkHabitToGoal(
  habitId: habit.habitId,
  goalId: goal.goalId,
  contributionWeight: 30.0, // 30% of goal progress
);
```

### Create Geofence for Task
```dart
final locationService = ref.watch(locationReminderServiceProvider);

await locationService.createGeofence(
  taskId: taskId,
  name: 'Office',
  latitude: 35.75,
  longitude: 51.39,
  radiusMeters: 150,
  entryAction: 'remind',
);
```

### Generate Daily Program
```dart
final programService = ref.watch(dailyProgramOptimizerServiceProvider);

final program = await programService.generateDailyProgram(
  date: DateTime.now(),
  moodLevel: 'good',
  energyLevel: 'high',
  focusArea: 'work',
);
```

### Complete Task
```dart
await taskService.completeTask(taskId);
```

### Mark Goal as Completed
```dart
await goalService.updateGoal(
  goalId,
  status: 'completed',
);
```

---

## 🎯 Provider Watch Patterns

### Watch Multiple Providers
```dart
final tasks = ref.watch(tasksStreamProvider);
final goals = ref.watch(goalsStreamProvider);
final program = ref.watch(todayProgramProvider);

// Use all three
```

### Watch with Filters
```dart
final filters = ref.watch(taskFiltersProvider);
final tasksAsync = ref.watch(tasksStreamProvider);

// Filter locally
final filtered = tasksAsync.whenData((tasks) {
  return tasks.where((t) => t.status == 'pending').toList();
});
```

### Watch Computed Data
```dart
final statsAsync = ref.watch(taskStatsStreamProvider);

statsAsync.when(
  data: (stats) => Text('${stats.completionRate}% complete'),
  loading: () => CircularProgressIndicator(),
  error: (err, st) => Text('Error: $err'),
);
```

---

## 🔄 State Management Patterns

### Form State
```dart
class MyForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyForm> createState() => _MyFormState();
}

class _MyFormState extends ConsumerState<MyForm> {
  final controller = TextEditingController();
  
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final service = ref.watch(taskManagementServiceProvider);
    
    return TextField(
      controller: controller,
      onSubmitted: (value) async {
        await service.createTask(title: value, category: 'Work');
      },
    );
  }
}
```

### Update Filter State
```dart
final filters = ref.watch(taskFiltersProvider);

DropdownButton(
  onChanged: (status) {
    ref.read(taskFiltersProvider.notifier).state = 
      filters.copyWith(status: status);
  },
);
```

---

## 💾 Using BehaviorSubject Cache

```dart
final taskService = ref.watch(taskManagementServiceProvider);

// Get cached data (instant, no await)
final cachedTasks = taskService.currentTasks;
final cachedStats = taskService.currentStats;

// These are always available after initial load
print('Cached tasks: ${cachedTasks.length}');
```

---

## 🎨 UI Snippet: Task Card

```dart
Card(
  child: ListTile(
    leading: Checkbox(
      value: task.status == 'completed',
      onChanged: (value) => taskService.completeTask(task.taskId),
    ),
    title: Text(task.title),
    subtitle: Text(task.description ?? ''),
    trailing: Chip(
      label: Text('${task.priority}'),
      backgroundColor: _priorityColor(task.priority),
    ),
  ),
)
```

---

## 🎨 UI Snippet: Goal Progress Bar

```dart
Column(
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(goal.title),
        Text('${goal.progressPercentage.toStringAsFixed(1)}%'),
      ],
    ),
    SizedBox(height: 8),
    ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: goal.progressPercentage / 100,
        minHeight: 8,
      ),
    ),
  ],
)
```

---

## 🔍 Debug Helpers

### Check Service Status
```dart
// Location monitoring
if (ServiceContainer.locationReminderService.isMonitoring) {
  print('Location monitoring active');
}

// Cached data
print('Tasks: ${ServiceContainer.taskManagementService.currentTasks.length}');
print('Goals: ${ServiceContainer.goalManagementService.currentGoals.length}');
```

### View Stream Data
```dart
ref.watch(tasksStreamProvider).whenData((tasks) {
  debugPrint('Tasks updated: ${tasks.length}');
});
```

---

## 🚨 Error Handling

```dart
tasksAsync.when(
  data: (tasks) => ListView(...),
  loading: () => CircularProgressIndicator(),
  error: (error, stackTrace) {
    debugPrint('Error: $error\n$stackTrace');
    return ErrorWidget(
      message: 'خطا در بارگذاری کارها',
      onRetry: () => ref.refresh(tasksStreamProvider),
    );
  },
);
```

---

## 📱 Common Screens

### Task List Screen
```dart
class TasksScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('کارها')),
      body: TaskListWidget(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreateTaskScreen()),
        ),
        child: Icon(Icons.add),
      ),
    );
  }
}
```

### Goal List Screen
```dart
class GoalsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('اهداف')),
      body: GoalListWidget(),
    );
  }
}
```

### Daily Program Screen
```dart
class ProgramScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('برنامه امروز')),
      body: Column(
        children: [
          DailyProgramGeneratorWidget(),
          Expanded(child: DailyProgramWidget()),
        ],
      ),
    );
  }
}
```

---

## 🔗 Linking Diagram

```
Task → Goal
      ↓ (60% of progress)
     Goal Progress
      ↑ (40% of progress)
Habit → Goal
```

---

## 📊 Data Types Quick Reference

### Task Status
`'pending' | 'in_progress' | 'completed' | 'cancelled'`

### Goal Status
`GoalStatus.active | .paused | .completed | .archived`

### Block Status
`'pending' | 'in_progress' | 'completed' | 'skipped'`

### Priority
`1-5` (1=lowest, 5=highest)

### Trend
`'increasing' | 'steady' | 'decreasing'`

### Category
`'Work' | 'Personal' | 'Health' | 'Learning' | 'Shopping'`

---

## 🎯 API Response Format

```dart
// Success response
{
  'task_id': 'uuid',
  'title': 'Task title',
  'status': 'pending',
  ...
}

// List response
{
  'tasks': [...],
  'total': 10,
  'completed': 5,
}

// Stream response
{
  'stream': asyncStream,
  'total': 100,
}
```

---

## 💡 Pro Tips

1. **Always use `ref.watch()` in ConsumerWidget** - Don't call services directly
2. **Use `.autoDispose`** - Saves memory by cleaning up unused providers
3. **Cache data locally** - `currentTasks`, `currentGoals` are instant
4. **Handle errors gracefully** - Always show user-friendly messages
5. **Test with mock data** - Override providers in tests
6. **Use `debugPrint()`** - Shows in Debug Console
7. **Check loading states** - Always handle loading/error/data
8. **Batch API calls** - Use bulk operations when possible

---

## 🔗 Quick Links

- **Integration Guide**: `FLUTTER_INTEGRATION_GUIDE.md`
- **Implementation Summary**: `IMPLEMENTATION_COMPLETE.md`
- **Service Code**: `lib/services/`
- **Models**: `lib/models/user_models.dart`
- **UI Widgets**: `lib/screens/widgets/`
- **Backend API**: `https://wqai.morvism.ir`

---

Last Updated: December 7, 2025
Version: 1.0 - Production Ready ✅


### Step 1: مدل‌های داده
```bash
# Copy کنید: PHASE_3_CODE_TEMPLATES.md
# → lib/models/message_models.dart
```

### Step 2: سرویس اول
```bash
# Copy کنید: PHASE_3_CODE_TEMPLATES.md
# → lib/services/message_reader_service.dart
```

### Step 3: Dependencies بروز‌رسانی
```yaml
# pubspec.yaml میں اضافه کنید:
location: ^5.0.0
geolocator: ^10.0.0
uuid: ^4.0.0
```

### Step 4: run
```bash
flutter pub get
flutter analyze  # بررسی خطاها
flutter build apk
```

---

## 🛠️ کار کنید - یک هفته‌ای

```
Day 1-2:  MessageReaderService + MessageAnalysisService ✅
Day 3-4:  SmartRemindersService ✅
Day 5:    RemindersManagementPage ✅
Day 6:    DailyPlanningPage Enhancement ✅
Day 7:    Testing + Bug Fixes ✅
```

---

## 🎯 هریک از سرویس‌ها

### MessageReaderService
```dart
// استفاده:
final reader = context.read<MessageReaderService>();
final messages = await reader.getPendingMessages();
reader.startWatching();
```

### MessageAnalysisService
```dart
// استفاده:
final analyzer = context.read<MessageAnalysisService>();
final keyPoints = await analyzer.extractKeyPoints(message);
final priority = await analyzer.detectPriority(message);
```

### SmartRemindersService
```dart
// استفاده:
final reminders = context.read<SmartRemindersService>();
await reminders.schedulePatternReminder(
  title: 'یادآوری روزانه',
  pattern: ReminderPattern.daily,
);
```

---

## 🔧 Native Layer (Android/Kotlin)

### دو تابع نیاز است:
```kotlin
// 1. getPendingMessages() - پیام‌های نخوانده
// 2. getMessageThreads() - لیست مکالمات

// موجود: MainActivity.kt + NotificationCaptureService.kt
```

---

## 🧪 اولویت تست

### حتمی:
- [ ] Message Reading (90%+ accuracy)
- [ ] Analysis Key Points (80%+ accuracy)
- [ ] Reminders Fire On Time (99%+ reliability)
- [ ] UI Responsive (< 100ms)

### مهم:
- [ ] Language Detection (Persian/English)
- [ ] Pattern Calculations (correct)
- [ ] State Persistence (no data loss)

### Nice-to-have:
- [ ] Performance (< 500ms queries)
- [ ] Memory Usage (< 50MB)
- [ ] Battery Impact (< 5%)

---

## 📊 متریک‌های هدف

| متریک | هدف | قبول | نیاز |
|-------|-----|------|------|
| Coverage | 90% | 85% | 70% |
| Build Time | < 2min | < 3min | < 5min |
| Startup | < 2sec | < 3sec | < 5sec |
| API Call | < 200ms | < 500ms | < 1sec |
| Latency | < 100ms | < 200ms | < 500ms |

---

## 🐛 مشکلات رایج و حل

### Problem 1: Permission Denied
```dart
// حل:
- اجازات AndroidManifest.xml بررسی کنید
- App Permissions توسط کاربر تأیید شود
- USE_FULL_SCREEN_INTENT اضافه کنید
```

### Problem 2: Message Reading Returns Null
```dart
// حل:
- ContentProvider Kotlin کد بررسی کنید
- SMS Read مجازی بودن‌ها تأیید کنید
- Emulator SMS simulation استفاده کنید
```

### Problem 3: Reminders Don't Fire
```dart
// حل:
- WorkManager initialize شده باشد
- AlarmManager permissions موجود باشد
- Battery Optimization غیرفعال باشد
```

### Problem 4: NLP Detection Wrong
```dart
// حل:
- updateUserContext() صدا زد
- Persian keywords اضافه کنید
- تست‌های بیشتر اجرا کنید
```

---

## 💡 نکات طلایی

### ✨ Best Practices:
1. **Batch Requests** - یک بار بسیاری فیچ کنید
2. **Cache Aggressively** - کش‌کاری تمام چیز
3. **Handle Errors Gracefully** - همیشه fallback
4. **Test Early** - هر روز تست کنید
5. **Document Everything** - کد نویسی با شرح

### 🚀 Performance Tips:
1. SharedPreferences نه SQLite (کوچک‌تر)
2. Debounce user input (50-100ms)
3. Use StreamBuilder نه setState
4. Lazy load screens (Route-based)
5. Dispose resources properly

### 🎨 UI/UX Tips:
1. Skeletons برای loading
2. Animations ابتدایی (100-200ms)
3. Dark mode support
4. Accessibility check (فونت بزرگ‌تر)
5. Persian RTL support

---

## 📱 UI Mockups (توضیح متن)

### RemindersManagementPage
```
┌─────────────────────────┐
│ 🔔 مدیریت یادآورها      │
├─────────────────────────┤
│ [Search Box]            │
├─────────────────────────┤
│ ┌─ یادآوری 1           │
│ │ 📅 هر روز ساعت 9    │
│ │ ✏️ | 🗑️              │
│ └─────────────────────┘│
│ ┌─ یادآوری 2           │
│ │ 📍 تهران، 500 متر    │
│ │ ⏸️ | 🗑️              │
│ └─────────────────────┘│
├─────────────────────────┤
│            [+ جدید]     │
└─────────────────────────┘
```

### DailyPlanningPage Enhanced
```
┌─────────────────────────┐
│ 📅 برنامه امروز         │
├─────────────────────────┤
│ 6:00 AM ━ 🟢 صبحانه    │
│         ↓ (drag)       │
│ 6:30 AM ━ 🟡 عادات     │
│         ↓ (drag)       │
│ 7:30 AM ━ 🔵 هدف‌ها     │
├─────────────────────────┤
│ 📊 Focus: 240 min       │
│ ☕ Break: 60 min        │
│         [ذخیره]        │
└─────────────────────────┘
```

---

## 📚 مراجع

### فایل‌های مهم:
- 📄 `PENDING_FEATURES_ANALYSIS.md` - تفصیل کامل
- 🗺️ `PHASE_3_IMPLEMENTATION_ROADMAP.md` - نقشه راه
- 💻 `PHASE_3_CODE_TEMPLATES.md` - کد‌های آماده
- 📊 `PHASE_3_EXECUTIVE_SUMMARY.md` - خلاصه

### Links مفید:
- 📱 [Flutter WorkManager](https://pub.dev/packages/workmanager)
- 📍 [Location Tracking](https://pub.dev/packages/location)
- 🔔 [Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- 🗃️ [SharedPreferences](https://pub.dev/packages/shared_preferences)

---

## ✅ نقطه‌ی پایان

### Phase 3 Complete When:
```
✅ 7 فایل جدید بدون خطا
✅ 4 فایل موجود بهبودیافته
✅ 90%+ تست‌ها pass می‌شوند
✅ UI Responsive و زیبا است
✅ Documentation تکمیل
✅ 0 Critical Bugs
✅ Code reviewed
✅ Deployed to TestFlight/Internal
```

---

## 🎊 Celebration Criteria

```
🎉 جشن برای:
- تمام 5 ویژگی کار کنند ✅
- 99%+ User Satisfaction ✅
- 0 Critical Issues ✅
- Release Ready ✅
```

---

## 📞 تماس سریع

**سوال؟** آسان جواب بده:
- 🔵 خطا: `get_errors()` استفاده کن
- 🟡 مبهم: مستندات دوباره خوند
- 🔴 مسدود: مدیر رو صدا کن

---

**بخت خوش! تو این کار میتونی! 🚀**

*آخرین به‌روزرسانی: دسامبر 2025*
*وقت آزاد برای تست: 2 هفته*
*زمان انتظار برای تایید: 1 هفته*

