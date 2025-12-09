# Phase 1 Integration Guide - main.dart Setup

## Adding UserProfileService to main.dart

### Step 1: Import the service
Add this to your imports at the top of `main.dart`:

```dart
import 'package:provider/provider.dart';
import 'lib/services/user_profile_service.dart';
import 'lib/models/user_models.dart';
```

### Step 2: Register provider in MultiProvider

Locate your existing `MultiProvider` in the `main()` function and add the UserProfileService:

**Before:**
```dart
runApp(
  MultiProvider(
    providers: [
      // ... existing providers
    ],
    child: const MyApp(),
  ),
);
```

**After:**
```dart
runApp(
  MultiProvider(
    providers: [
      // ... existing providers
      ChangeNotifierProvider(
        create: (context) => UserProfileService(
          apiClient: context.read<ApiClient>(),
        ),
      ),
    ],
    child: const MyApp(),
  ),
);
```

### Step 3: Accessing the service in widgets

**In any widget, consume the service like this:**

```dart
// Access the service
final userProfileService = context.watch<UserProfileService>();

// Access individual properties
final profile = userProfileService.profile;
final goals = userProfileService.goals;
final habits = userProfileService.habits;
final isLoading = userProfileService.isLoading;
final error = userProfileService.error;
```

### Step 4: Using the service methods

**Example: Setting up user profile during onboarding**

```dart
final userProfileService = context.read<UserProfileService>();

try {
  final profile = await userProfileService.setupProfile(
    name: 'علی محمدی',
    role: 'مهندس نرم‌افزار',
    timezone: 'Asia/Tehran',
    interests: ['فلاتر', 'هوش مصنوعی', 'بلاک‌چین'],
    wakeUpTime: '06:00',
    sleepTime: '23:00',
    focusHours: '2-4',
  );
  
  // Profile created successfully
  print('Profile created: ${profile.name}');
  
  // Navigate to next screen
  if (mounted) {
    Navigator.of(context).pushNamed('/home');
  }
} on ApiException catch (e) {
  // Show error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message)),
  );
}
```

**Example: Creating a goal**

```dart
final userProfileService = context.read<UserProfileService>();

final goal = await userProfileService.createGoal(
  title: 'یادگیری فلاتر',
  category: 'برنامه‌نویسی',
  description: 'تسلط بر فریم‌ورک فلاتر',
  deadline: DateTime.now().add(Duration(days: 90)),
  priority: 'high',
  milestones: [
    'یادگیری Widget ها',
    'پروژه کوچک ایجاد کردن',
    'منتشر کردن در Play Store',
  ],
);
```

**Example: Recording mood**

```dart
final userProfileService = context.read<UserProfileService>();

final snapshot = await userProfileService.recordMood(
  energy: 8.0,  // 1-10 scale
  mood: 9.0,    // 1-10 scale
  context: 'work',
  activity: 'برنامه‌نویسی',
  notes: 'بسیار راضی از پیشرفت امروز',
);
```

**Example: Logging habit completion**

```dart
final userProfileService = context.read<UserProfileService>();

await userProfileService.logHabitCompletion(
  habitId: habit.habitId,
  date: DateTime.now(),
  completed: true,
  notes: 'صبح زود بیدار شدم و ورزش کردم',
);
```

**Example: Getting user's data**

```dart
final userProfileService = context.read<UserProfileService>();

// Get profile
final profile = await userProfileService.getProfile();

// Get all goals
final goals = await userProfileService.getGoals();

// Get active goals
final activeGoals = userProfileService.getActiveGoals();

// Get overdue goals
final overdueGoals = userProfileService.getOverdueGoals();

// Get habits
final habits = await userProfileService.getHabits();

// Get active habits
final activeHabits = userProfileService.getActiveHabits();

// Get mood history
final moodHistory = await userProfileService.getMoodHistory(last: 30);

// Get mood average
final moodAvg = userProfileService.getMoodAverage();
```

---

## Building UI Components

### 1. Profile Setup Screen

```dart
class ProfileSetupScreen extends StatefulWidget {
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _role;
  late String _timezone;
  late List<String> _interests;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تکمیل پروفایل')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Name field
            TextFormField(
              decoration: InputDecoration(labelText: 'نام'),
              onSaved: (value) => _name = value ?? '',
            ),
            // Role dropdown
            DropdownButtonFormField(
              decoration: InputDecoration(labelText: 'نقش'),
              items: ['مهندس', 'مدیر', 'کارآفرین']
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ))
                  .toList(),
              onChanged: (value) => _role = value ?? '',
            ),
            // Timezone selector
            DropdownButtonFormField(
              decoration: InputDecoration(labelText: 'منطقه زمانی'),
              items: ['Asia/Tehran', 'UTC', 'Europe/London']
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ))
                  .toList(),
              onChanged: (value) => _timezone = value ?? '',
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _submitForm(context),
              child: Text('تکمیل'),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      try {
        final userProfileService = context.read<UserProfileService>();
        await userProfileService.setupProfile(
          name: _name,
          role: _role,
          timezone: _timezone,
          interests: _interests,
        );
        
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    }
  }
}
```

### 2. Goals List Screen

```dart
class GoalsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('اهداف')),
      body: Consumer<UserProfileService>(
        builder: (context, userProfileService, child) {
          if (userProfileService.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          final goals = userProfileService.goals;
          if (goals.isEmpty) {
            return Center(child: Text('هدفی تعریف نشده است'));
          }

          return ListView.builder(
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return ListTile(
                title: Text(goal.title),
                subtitle: Text('${goal.category} - ${goal.priority}'),
                trailing: LinearProgressIndicator(
                  value: goal.progressPercentage / 100,
                  minHeight: 4,
                ),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    '/goal-detail',
                    arguments: goal,
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed('/goal-create'),
        child: Icon(Icons.add),
      ),
    );
  }
}
```

### 3. Mood Tracker Widget

```dart
class MoodTrackerWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('حال و هوا'),
            SizedBox(height: 8),
            Consumer<UserProfileService>(
              builder: (context, userProfileService, child) {
                final avgMood = userProfileService.getMoodAverage();
                final moodLevel = MoodLevelExt.fromValue(avgMood.toInt());
                
                return Column(
                  children: [
                    Text(
                      moodLevel.toDisplayString(),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _showMoodPicker(context),
                      child: Text('ثبت حال و هوا'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoodPicker(BuildContext context) {
    // Show mood picker dialog/sheet
    // Call userProfileService.recordMood() on selection
  }
}
```

---

## Common Patterns

### Loading State Handling
```dart
Consumer<UserProfileService>(
  builder: (context, service, child) {
    if (service.isLoading) {
      return CircularProgressIndicator();
    }
    if (service.error != null) {
      return Text('خطا: ${service.error}');
    }
    return Text('داده‌ها: ${service.goals}');
  },
)
```

### Reactive Updates
```dart
// Watch for changes - rebuilds when UserProfileService updates
final goals = context.watch<UserProfileService>().goals;

// Read once - doesn't rebuild
final service = context.read<UserProfileService>();
```

### Error Handling
```dart
try {
  await userProfileService.createGoal(...);
} on ApiException catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message)),
  );
}
```

---

## Testing the Integration

### 1. Unit Test Example
```dart
void main() {
  group('UserProfileService', () {
    late MockApiClient mockApiClient;
    late UserProfileService service;

    setUp(() {
      mockApiClient = MockApiClient();
      service = UserProfileService(apiClient: mockApiClient);
    });

    test('setupProfile creates profile', () async {
      // Mock API response
      when(mockApiClient.postJson(any, body: anyNamed('body')))
          .thenAnswer((_) async => {
            'user_id': '123',
            'name': 'علی',
            'role': 'مهندس',
            'timezone': 'Asia/Tehran',
            'interests': [],
            'created_at': DateTime.now().toIso8601String(),
          });

      final profile = await service.setupProfile(
        name: 'علی',
        role: 'مهندس',
        timezone: 'Asia/Tehran',
        interests: [],
      );

      expect(profile.name, 'علی');
      expect(profile.role, 'مهندس');
    });
  });
}
```

### 2. Widget Test Example
```dart
void main() {
  testWidgets('GoalsScreen shows loading', (WidgetTester tester) async {
    final mockService = MockUserProfileService();
    when(mockService.isLoading).thenReturn(true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProfileService>.value(
            value: mockService,
          ),
        ],
        child: MaterialApp(home: GoalsScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

---

## Deployment Checklist

Before deploying Phase 1:

```
Backend (e:\ai\app.py):
☐ Database migrations applied
☐ JWT secret key configured
☐ Database connection string correct
☐ CORS configured if needed
☐ API server started and running
☐ All endpoints tested with curl

Frontend (Flutter):
☐ UserProfileService imported in main.dart
☐ Provider registered in MultiProvider
☐ ApiClient instance available
☐ Navigation routes configured
☐ Screens created (ProfileSetup, Goals, etc.)
☐ Testing completed on real device
☐ Persian translations working correctly
```

---

**Ready to proceed with Phase 1 deployment!**
