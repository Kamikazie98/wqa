import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assistant_models.dart';
import '../services/automation_service.dart';
import '../services/workmanager_service.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  late AutomationService _automation;

  bool _autoNext = false;
  bool _autoMode = false;
  bool _autoWeekly = false;

  final _minutesController = TextEditingController();
  final _energyController = TextEditingController(text: 'normal');
  final _modeController = TextEditingController(text: 'default');
  final _modeContextController = TextEditingController(text: '{}');
  final _weeklyGoalsController = TextEditingController();
  final _weeklyEventsController = TextEditingController(text: '[]');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _automation = context.read<AutomationService>();
      setState(() {
        _autoNext = _automation.autoNextEnabled;
        _autoMode = _automation.autoModeEnabled;
        _autoWeekly = _automation.autoWeeklyEnabled;
        _minutesController.text = _automation.availableMinutes.toString();
        _energyController.text = _automation.energy;
        _modeController.text = _automation.mode;
        _modeContextController.text = _automation.modeContext;
        _weeklyGoalsController.text = _automation.weeklyGoals.join('\n');
        _weeklyEventsController.text = jsonEncode(_automation.weeklyEvents);
      });
      _wireAutoSave();
      _loadCachedPlan();
    });
  }

  void _wireAutoSave() {
    _weeklyGoalsController.addListener(_persistWeekly);
    _weeklyEventsController.addListener(_persistWeekly);
    _modeContextController.addListener(_persistModeContext);
  }

  Future<void> _loadCachedPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache.weekly_plan');
      if (cached == null || cached.isEmpty) return;
      WeeklyScheduleResult.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _persistWeekly() async {
    await _automation.saveWeeklyData(
      goals: _lines(_weeklyGoalsController.text),
      events: _decodeWeeklyEvents(_weeklyEventsController.text),
    );
  }

  Future<void> _persistModeContext() async {
    await _automation.setAutoMode(
      enabled: _autoMode,
      energy: _energyController.text.trim().isEmpty
          ? 'normal'
          : _energyController.text.trim(),
      mode: _modeController.text.trim().isEmpty
          ? 'default'
          : _modeController.text.trim(),
      contextJson: _modeContextController.text.trim(),
    );
    setState(() {});
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _energyController.dispose();
    _modeController.dispose();
    _modeContextController.dispose();
    _weeklyGoalsController.dispose();
    _weeklyEventsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اتوماسیون دستیار'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _card(
                title: 'Next Action خودکار',
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _autoNext,
                      title: const Text('فعال‌سازی پیشنهاد خودکار اقدام بعدی'),
                      onChanged: (value) async {
                        setState(() => _autoNext = value);
                        await _automation.setAutoNextAction(
                          enabled: value,
                          minutes:
                              int.tryParse(_minutesController.text.trim()) ??
                                  _automation.availableMinutes,
                          energy: _energyController.text.trim(),
                          mode: _modeController.text.trim(),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minutesController,
                            decoration: const InputDecoration(
                              labelText: 'زمان در دسترس (دقیقه)',
                            ),
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _automation.setAutoNextAction(
                              enabled: _autoNext,
                              minutes: int.tryParse(
                                      _minutesController.text.trim()) ??
                                  _automation.availableMinutes,
                              energy: _energyController.text.trim(),
                              mode: _modeController.text.trim(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _energyController,
                            decoration: const InputDecoration(
                              labelText: 'انرژی (low/normal/high)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _modeController,
                      decoration:
                          const InputDecoration(labelText: 'حالت (mode)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                title: 'Mode Check خودکار',
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _autoMode,
                      title: const Text('فعال‌سازی بررسی دوره‌ای حالت'),
                      onChanged: (value) async {
                        setState(() => _autoMode = value);
                        await _automation.setAutoMode(
                          enabled: value,
                          energy: _energyController.text.trim(),
                          mode: _modeController.text.trim(),
                          contextJson: _modeContextController.text.trim(),
                        );
                      },
                    ),
                    TextField(
                      controller: _modeContextController,
                      decoration: const InputDecoration(
                        labelText: 'context (JSON)',
                        hintText: '{"wifi":"office","location":"tehran"}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _card(
                title: 'برنامه هفتگی خودکار',
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _autoWeekly,
                      title: const Text('فعال‌سازی زمان‌بندی هفتگی'),
                      onChanged: (value) async {
                        setState(() => _autoWeekly = value);
                        await _automation.setAutoWeekly(
                          enabled: value,
                          goals: _lines(_weeklyGoalsController.text),
                          events:
                              _decodeWeeklyEvents(_weeklyEventsController.text),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'برنامه هفتگی خودکار فعال شد'
                                    : 'برنامه هفتگی خودکار غیرفعال شد',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    TextField(
                      controller: _weeklyGoalsController,
                      decoration: const InputDecoration(
                        labelText: 'اهداف (هر خط یک مورد)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _weeklyEventsController,
                      decoration: const InputDecoration(
                        labelText: 'رویدادهای قطعی (JSON array)',
                        hintText:
                            '[{"title":"Meeting","day":"saturday","start":"09:00","end":"10:00"}]',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('ذخیره اهداف/رویدادها'),
                            onPressed: () async {
                              await _persistWeekly();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.alarm),
                            label: const Text('بازسازی یادآورها'),
                            onPressed: () async {
                              final ctx = ScaffoldMessenger.of(context);
                              try {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final cached =
                                    prefs.getString('cache.weekly_plan');
                                if (cached == null || cached.isEmpty) {
                                  ctx.showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('برنامه هفتگی کش‌شده پیدا نشد'),
                                    ),
                                  );
                                  return;
                                }
                                final result = WeeklyScheduleResult.fromJson(
                                  jsonDecode(cached) as Map<String, dynamic>,
                                );
                                await WorkmanagerService
                                    .scheduleWeeklyPlanReminders(
                                  result,
                                );
                                ctx.showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('یادآورها دوباره زمان‌بندی شد'),
                                  ),
                                );
                              } catch (_) {
                                ctx.showSnackBar(
                                  const SnackBar(
                                    content: Text('خطا در بازسازی یادآورها'),
                                  ),
                                );
                              }
                            },
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
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  List<String> _lines(String raw) =>
      raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  List<Map<String, dynamic>> _decodeWeeklyEvents(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
