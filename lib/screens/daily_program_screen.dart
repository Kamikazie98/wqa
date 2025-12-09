import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/daily_program_models.dart';
import '../services/daily_program_service.dart';
import '../services/user_profile_service.dart';

class DailyProgramScreen extends StatefulWidget {
  const DailyProgramScreen({super.key});

  @override
  State<DailyProgramScreen> createState() => _DailyProgramScreenState();
}

class _DailyProgramScreenState extends State<DailyProgramScreen> {
  DateTime _selectedDate = DateTime.now();
  DailyProgram? _program;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProgram();
  }

  Future<void> _loadProgram() async {
    setState(() => _isLoading = true);
    try {
      final dailyService = context.read<DailyProgramService>();
      final program = await dailyService.getProgramForDate(_selectedDate);

      if (mounted) {
        setState(() {
          _program = program;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateNewProgram() async {
    final profileService = context.read<UserProfileService>();

    if (profileService.profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پروفایل کاربری یافت نشد')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dailyService = context.read<DailyProgramService>();
      final program = await dailyService.generateDailyProgram(
        profile: profileService.profile!,
        goals: profileService.goals,
        habits: profileService.habits,
        currentMood: 7,
        currentEnergy: 7,
      );

      if (mounted) {
        setState(() {
          _program = program;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('برنامه روزانه تولید شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToPreviousDay() {
    setState(
        () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _loadProgram();
  }

  void _goToNextDay() {
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _loadProgram();
  }

  void _goToToday() {
    setState(() => _selectedDate = DateTime.now());
    _loadProgram();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('برنامه روزانه'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadProgram,
            tooltip: 'بروزرسانی',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('خطا: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProgram,
                        child: const Text('تلاش دوباره'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Date Navigation
                        _buildDateNavigator(),
                        const SizedBox(height: 20),

                        // Program Statistics
                        if (_program != null) ...[
                          _buildProgramStats(),
                          const SizedBox(height: 20),
                        ],

                        // Activities Timeline
                        if (_program != null && _program!.activities.isNotEmpty)
                          _buildActivitiesTimeline()
                        else
                          _buildEmptyState(),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _generateNewProgram,
        label: const Text('تولید برنامه'),
        icon: const Icon(Icons.auto_awesome),
      ),
    );
  }

  Widget _buildDateNavigator() {
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _goToPreviousDay,
                  tooltip: 'روز قبل',
                ),
                Column(
                  children: [
                    Text(
                      DateFormat('EEEE، d MMMM', 'fa').format(_selectedDate),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (!isToday)
                      Text(
                        DateFormat('HH:mm').format(DateTime.now()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _goToNextDay,
                  tooltip: 'روز بعد',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isToday)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToToday,
                  child: const Text('برگشت به امروز'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramStats() {
    final program = _program!;
    final focusMinutes = program.totalFocusTime.inMinutes;
    final productivity = program.expectedProductivity ?? 75.0;
    final mood = program.expectedMood ?? 7.0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'بهره‌وری',
            value: '${productivity.toStringAsFixed(0)}%',
            icon: Icons.trending_up,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'حالت‌روح',
            value: '${mood.toStringAsFixed(1)}/10',
            icon: Icons.mood,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'تمرکز',
            value: '${(focusMinutes / 60).toStringAsFixed(1)}h',
            icon: Icons.bolt,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitiesTimeline() {
    final activities = _program!.sortedActivities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'فعالیت‌های امروز',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...List.generate(activities.length, (index) {
          final activity = activities[index];
          final nextActivity =
              index < activities.length - 1 ? activities[index + 1] : null;
          final isLast = index == activities.length - 1;

          return _buildActivityTimelineItem(
            activity: activity,
            nextActivity: nextActivity,
            isLast: isLast,
          );
        }),
      ],
    );
  }

  Widget _buildActivityTimelineItem({
    required ProgramActivity activity,
    required ProgramActivity? nextActivity,
    required bool isLast,
  }) {
    final categoryColors = {
      'goal': Colors.blue,
      'habit': Colors.purple,
      'break': Colors.orange,
      'focus': Colors.green,
      'rest': Colors.pink,
    };

    final categoryIcons = {
      'goal': Icons.flag,
      'habit': Icons.repeat,
      'break': Icons.local_cafe,
      'focus': Icons.lightbulb,
      'rest': Icons.nights_stay,
    };

    final color = categoryColors[activity.category] ?? Colors.grey;
    final icon = categoryIcons[activity.category] ?? Icons.circle;
    final duration = activity.endTime.difference(activity.startTime).inMinutes;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline dot
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: color.withOpacity(0.3),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Activity details
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${activity.startTime.hour.toString().padLeft(2, '0')}:${activity.startTime.minute.toString().padLeft(2, '0')} - ${activity.endTime.hour.toString().padLeft(2, '0')}:${activity.endTime.minute.toString().padLeft(2, '0')} • $duration دقیقه',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(icon, color: color, size: 20),
                        ],
                      ),
                      if (activity.description != null &&
                          activity.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          activity.description!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if ((activity.energyRequired ?? 0) > 0 ||
                          (activity.moodBenefits ?? 0) > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if ((activity.energyRequired ?? 0) > 0)
                              Chip(
                                label: Text(
                                  'انرژی: ${(activity.energyRequired ?? 0).toInt()}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                avatar: const Icon(Icons.bolt, size: 14),
                              ),
                            const SizedBox(width: 8),
                            if ((activity.moodBenefits ?? 0) > 0)
                              Chip(
                                label: Text(
                                  'حالت‌روح: +${(activity.moodBenefits ?? 0).toInt()}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                avatar: const Icon(Icons.mood, size: 14),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'برنامه‌ای برای این روز وجود ندارد',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'دکمه زیر را بزنید تا یک برنامه جدید تولید شود',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _generateNewProgram,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('تولید برنامه'),
          ),
        ],
      ),
    );
  }
}
