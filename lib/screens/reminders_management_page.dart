import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';
import '../services/service_providers.dart';
import '../services/smart_reminders_service.dart';

class RemindersManagementPage extends StatefulWidget {
  const RemindersManagementPage({super.key});

  @override
  State<RemindersManagementPage> createState() =>
      _RemindersManagementPageState();
}

class _RemindersManagementPageState extends State<RemindersManagementPage> {
  final _searchController = TextEditingController();
  ReminderType? _filterType;
  bool _showOnlyActive = true;
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = serviceProvider.get<NotificationService>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 مدیریت یادآورها'),
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<SmartRemindersService>(
        builder: (context, service, _) {
          final reminders = _filterReminders(service.reminders);

          return Column(
            children: [
              // جستجو
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'جستجو در یادآورها...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              // فیلترها
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('فعال'),
                      selected: _showOnlyActive,
                      onSelected: (value) {
                        setState(() => _showOnlyActive = value);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('تک‌باره'),
                      selected: _filterType == ReminderType.oneTime,
                      onSelected: (value) {
                        setState(() {
                          _filterType = value ? ReminderType.oneTime : null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('الگویی'),
                      selected: _filterType == ReminderType.pattern,
                      onSelected: (value) {
                        setState(() {
                          _filterType = value ? ReminderType.pattern : null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('هوشمند'),
                      selected: _filterType == ReminderType.smart,
                      onSelected: (value) {
                        setState(() {
                          _filterType = value ? ReminderType.smart : null;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // لیست یادآورها
              Expanded(
                child: reminders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.notifications_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'هیچ یادآوری یافت نشد',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: reminders.length,
                        itemBuilder: (context, index) {
                          final reminder = reminders[index];
                          return _buildReminderCard(
                            context,
                            reminder,
                            service,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateReminderDialog,
        tooltip: 'یادآوری جدید',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    SmartReminder reminder,
    SmartRemindersService service,
  ) {
    final formatter = DateFormat('HH:mm', 'fa_IR');
    final dateFormatter = DateFormat('yyyy/MM/dd', 'fa_IR');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(reminder.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(reminder.description),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildTypeChip(reminder.type),
                    const SizedBox(width: 8),
                    if (reminder.pattern != null)
                      Chip(
                        label: Text(_getPatternLabel(reminder.pattern!)),
                        backgroundColor: Colors.blue.withOpacity(0.1),
                      ),
                  ],
                ),
              ],
            ),
            trailing: reminder.isActive
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.pause_circle, color: Colors.grey),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (reminder.nextReminderTime != null)
                  Text(
                    '⏰ ${dateFormatter.format(reminder.nextReminderTime!)} '
                    '${formatter.format(reminder.nextReminderTime!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                Row(
                  children: [
                    if (reminder.isActive)
                      IconButton(
                        icon: const Icon(Icons.pause, size: 20),
                        onPressed: () {
                          service.pauseReminder(reminder.id);
                          _notificationService.showLocalNow(
                            title: 'یادآور موقوف شد',
                            body: 'یادآور "${reminder.title}" موقوف شد.',
                          );
                        },
                        tooltip: 'موقوف کردن',
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.play_arrow, size: 20),
                        onPressed: () {
                          service.resumeReminder(reminder.id);
                           _notificationService.showLocalNow(
                            title: 'یادآور فعال شد',
                            body: 'یادآور "${reminder.title}" از سر گرفته شد.',
                          );
                        },
                        tooltip: 'ادامه',
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _showDeleteConfirmation(
                        context,
                        reminder.id,
                        service,
                      ),
                      tooltip: 'حذف',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(ReminderType type) {
    final label = _getTypeLabel(type);
    final icon = _getTypeIcon(type);

    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 16),
      backgroundColor: Colors.grey.withOpacity(0.2),
    );
  }

  String _getTypeLabel(ReminderType type) {
    switch (type) {
      case ReminderType.oneTime:
        return 'تک‌باره';
      case ReminderType.pattern:
        return 'الگویی';
      case ReminderType.location:
        return 'مکان‌محور';
      case ReminderType.smart:
        return 'هوشمند';
    }
  }

  IconData _getTypeIcon(ReminderType type) {
    switch (type) {
      case ReminderType.oneTime:
        return Icons.schedule;
      case ReminderType.pattern:
        return Icons.repeat;
      case ReminderType.location:
        return Icons.location_on;
      case ReminderType.smart:
        return Icons.lightbulb;
    }
  }

  String _getPatternLabel(ReminderPattern pattern) {
    switch (pattern) {
      case ReminderPattern.daily:
        return 'روزانه';
      case ReminderPattern.everyTwoDays:
        return 'دو روز یک‌بار';
      case ReminderPattern.weekly:
        return 'هفتگی';
      case ReminderPattern.biWeekly:
        return 'دو هفته یک‌بار';
      case ReminderPattern.monthly:
        return 'ماهانه';
    }
  }

  List<SmartReminder> _filterReminders(List<SmartReminder> reminders) {
    var filtered = reminders;

    if (_showOnlyActive) {
      filtered = filtered.where((r) => r.isActive).toList();
    }

    if (_filterType != null) {
      filtered = filtered.where((r) => r.type == _filterType).toList();
    }

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where((r) =>
              r.title.toLowerCase().contains(query) ||
              r.description.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
  }

  void _showCreateReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateReminderDialog(
        notificationService: _notificationService,
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String reminderId,
    SmartRemindersService service,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف یادآوری'),
        content: const Text('آیا مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              final reminder = service.getReminder(reminderId);
              service.deleteReminder(reminderId);
              if (reminder != null) {
                _notificationService.showLocalNow(
                  title: 'یادآور حذف شد',
                  body: 'یادآور "${reminder.title}" حذف شد.',
                );
              }
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CreateReminderDialog extends StatefulWidget {
  final NotificationService notificationService;

  const _CreateReminderDialog({required this.notificationService});

  @override
  State<_CreateReminderDialog> createState() => _CreateReminderDialogState();
}

class _CreateReminderDialogState extends State<_CreateReminderDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  ReminderType _selectedType = ReminderType.oneTime;
  ReminderPattern? _selectedPattern;
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('یادآوری جدید'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'توضیح',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButton<ReminderType>(
              isExpanded: true,
              value: _selectedType,
              items: ReminderType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(_getTypeLabel(type)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            if (_selectedType == ReminderType.pattern)
              DropdownButton<ReminderPattern>(
                isExpanded: true,
                value: _selectedPattern,
                items: ReminderPattern.values
                    .map((pattern) => DropdownMenuItem(
                          value: pattern,
                          child: Text(_getPatternLabel(pattern)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedPattern = value);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        ElevatedButton(
          onPressed: () async {
            final service = context.read<SmartRemindersService>();

            if (_titleController.text.isEmpty) {
              widget.notificationService.showLocalNow(
                title: 'خطا',
                body: 'عنوان الزامی است',
              );
              return;
            }

            if (_selectedType == ReminderType.oneTime) {
              final now = DateTime.now();
              var reminderTime = DateTime(
                now.year,
                now.month,
                now.day,
                _selectedTime.hour,
                _selectedTime.minute,
              );

              if (reminderTime.isBefore(now)) {
                reminderTime = reminderTime.add(const Duration(days: 1));
              }

              await service.scheduleOneTimeReminder(
                title: _titleController.text,
                description: _descController.text,
                at: reminderTime,
              );
            } else if (_selectedType == ReminderType.pattern &&
                _selectedPattern != null) {
              await service.schedulePatternReminder(
                title: _titleController.text,
                description: _descController.text,
                pattern: _selectedPattern!,
              );
            }

            if (mounted) {
              Navigator.pop(context);
               widget.notificationService.showLocalNow(
                  title: 'یادآوری ایجاد شد ✅',
                  body: 'یادآور جدید "${_titleController.text}" ایجاد شد.',
                );
            }
          },
          child: const Text('ایجاد'),
        ),
      ],
    );
  }

  String _getTypeLabel(ReminderType type) {
    switch (type) {
      case ReminderType.oneTime:
        return 'تک‌باره';
      case ReminderType.pattern:
        return 'الگویی';
      case ReminderType.location:
        return 'مکان‌محور';
      case ReminderType.smart:
        return 'هوشمند';
    }
  }

    String _getPatternLabel(ReminderPattern pattern) {
    switch (pattern) {
      case ReminderPattern.daily:
        return 'روزانه';
      case ReminderPoint.everyTwoDays:
        return 'دو روز یک‌بار';
      case ReminderPattern.weekly:
        return 'هفتگی';
      case ReminderPattern.biWeekly:
        return 'دو هفته یک‌بار';
      case ReminderPattern.monthly:
        return 'ماهانه';
    }
  }
}
