import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_program_models.dart';
import '../services/daily_program_service.dart';

class ActivityDetailScreen extends StatefulWidget {
  final ProgramActivity activity;
  final DailyProgram program;

  const ActivityDetailScreen({
    super.key,
    required this.activity,
    required this.program,
  });

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isTimerRunning = false;
  Duration _elapsed = Duration.zero;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() => _isTimerRunning = !_isTimerRunning);
    if (_isTimerRunning) {
      _animationController.forward();
      _startTimer();
    } else {
      _animationController.reverse();
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isTimerRunning && mounted) {
        setState(() => _elapsed = _elapsed + const Duration(seconds: 1));
        _startTimer();
      }
    });
  }

  void _resetTimer() {
    setState(() {
      _elapsed = Duration.zero;
      _isTimerRunning = false;
    });
    _animationController.reverse();
  }

  Future<void> _completeActivity() async {
    final dailyService = context.read<DailyProgramService>();

    try {
      await dailyService.completeActivity(
        activityId: widget.activity.id,
        completed: true,
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فعالیت انجام شد')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColors = {
      'goal': Colors.blue,
      'habit': Colors.purple,
      'break': Colors.orange,
      'focus': Colors.green,
      'rest': Colors.pink,
    };

    final categoryNames = {
      'goal': 'هدف',
      'habit': 'عادت',
      'break': 'استراحت',
      'focus': 'تمرکز',
      'rest': 'خواب',
    };

    final color = categoryColors[widget.activity.category] ?? Colors.grey;
    final categoryName = categoryNames[widget.activity.category] ?? 'فعالیت';
    final duration =
        widget.activity.endTime.difference(widget.activity.startTime);
    final progress = _elapsed.inSeconds / duration.inSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات فعالیت'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.flag, color: color),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.activity.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Chip(
                                  label: Text(categoryName),
                                  backgroundColor: color.withOpacity(0.2),
                                  labelStyle: TextStyle(color: color),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoColumn(
                            'شروع',
                            '${widget.activity.startTime.hour.toString().padLeft(2, '0')}:${widget.activity.startTime.minute.toString().padLeft(2, '0')}',
                          ),
                          _buildInfoColumn(
                            'پایان',
                            '${widget.activity.endTime.hour.toString().padLeft(2, '0')}:${widget.activity.endTime.minute.toString().padLeft(2, '0')}',
                          ),
                          _buildInfoColumn(
                            'مدت',
                            '${duration.inMinutes} دقیقه',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Timer section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'تایمر فعالیت',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),

                      // Timer display
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.2),
                              color.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: color.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: CircularProgressIndicator(
                                    value: progress.isNaN ? 0 : progress,
                                    strokeWidth: 8,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      color.withOpacity(0.7),
                                    ),
                                    backgroundColor: color.withOpacity(0.1),
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _formatDuration(_elapsed),
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'از ${_formatDuration(duration)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Timer controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FloatingActionButton(
                                  mini: true,
                                  onPressed: _resetTimer,
                                  tooltip: 'ریست کن',
                                  child: const Icon(Icons.restore),
                                ),
                                const SizedBox(width: 16),
                                FloatingActionButton(
                                  onPressed: _toggleTimer,
                                  tooltip: _isTimerRunning ? 'مکث' : 'شروع',
                                  child: Icon(
                                    _isTimerRunning
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Description
              if (widget.activity.description != null &&
                  widget.activity.description!.isNotEmpty) ...[
                Text(
                  'توضیحات',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.activity.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Metrics
              Text(
                'معیارهای فعالیت',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if ((widget.activity.energyRequired ?? 0) > 0)
                    Expanded(
                      child: _buildMetricCard(
                        title: 'انرژی مورد نیاز',
                        value: (widget.activity.energyRequired ?? 0)
                            .toStringAsFixed(0),
                        icon: Icons.bolt,
                        color: Colors.amber,
                      ),
                    ),
                  const SizedBox(width: 12),
                  if ((widget.activity.moodBenefits ?? 0) > 0)
                    Expanded(
                      child: _buildMetricCard(
                        title: 'تأثیر بر حالت',
                        value:
                            '+${(widget.activity.moodBenefits ?? 0).toStringAsFixed(0)}',
                        icon: Icons.mood,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Notes section
              Text(
                'یادداشت‌ها',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'یادداشت‌های خود را اینجا بنویسید...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // Complete button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _completeActivity,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('فعالیت انجام شد'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Skip button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('بستن'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
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
            Icon(icon, color: color, size: 20),
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
