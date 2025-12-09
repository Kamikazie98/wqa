import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'workmanager_service.dart';

enum ReminderType { oneTime, pattern, location, smart }

enum ReminderPattern { daily, everyTwoDays, weekly, biWeekly, monthly }

class SmartReminder {
  final String id;
  final String title;
  final String description;
  final ReminderType type;
  final ReminderPattern? pattern;
  final DateTime? nextReminderTime;
  final DateTime? endTime;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  SmartReminder({
    String? id,
    required this.title,
    required this.description,
    required this.type,
    this.pattern,
    this.nextReminderTime,
    this.endTime,
    this.isActive = true,
    DateTime? createdAt,
    this.metadata = const {},
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory SmartReminder.fromJson(Map<String, dynamic> json) {
    return SmartReminder(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: ReminderType.values.byName(
        json['type']?.toString() ?? 'oneTime',
      ),
      pattern: json['pattern'] != null
          ? ReminderPattern.values.byName(json['pattern'].toString())
          : null,
      nextReminderTime: json['nextReminderTime'] != null
          ? DateTime.parse(json['nextReminderTime'].toString())
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'].toString())
          : null,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'pattern': pattern?.name,
        'nextReminderTime': nextReminderTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'metadata': metadata,
      };

  Duration get timeUntilReminder {
    if (nextReminderTime == null) return Duration.zero;
    return nextReminderTime!.difference(DateTime.now());
  }

  bool get isOverdue {
    if (nextReminderTime == null) return false;
    return nextReminderTime!.isBefore(DateTime.now());
  }

  bool get isExpired {
    if (endTime == null) return false;
    return endTime!.isBefore(DateTime.now());
  }

  SmartReminder copyWith({
    String? id,
    String? title,
    String? description,
    ReminderType? type,
    ReminderPattern? pattern,
    DateTime? nextReminderTime,
    DateTime? endTime,
    bool? isActive,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return SmartReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      pattern: pattern ?? this.pattern,
      nextReminderTime: nextReminderTime ?? this.nextReminderTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class SmartRemindersService with ChangeNotifier {
  static const _remindersKey = 'smart_reminders.list';

  final SharedPreferences _prefs;

  final List<SmartReminder> _reminders = [];

  SmartRemindersService({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  List<SmartReminder> get reminders => List.unmodifiable(_reminders);

  List<SmartReminder> get activeReminders =>
      _reminders.where((r) => r.isActive && !r.isExpired).toList();

  /// بارگذاری یادآورها از ذخیره‌سازی
  Future<void> loadReminders() async {
    try {
      final raw = _prefs.getStringList(_remindersKey) ?? [];
      _reminders.clear();
      for (final item in raw) {
        try {
          _reminders.add(SmartReminder.fromJson(jsonDecode(item)));
        } catch (e) {
          print('Error loading reminder: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading reminders: $e');
    }
  }

  /// ذخیره‌سازی یادآورها
  Future<void> _saveReminders() async {
    try {
      final json = _reminders.map((r) => jsonEncode(r.toJson())).toList();
      await _prefs.setStringList(_remindersKey, json);
      notifyListeners();
    } catch (e) {
      print('Error saving reminders: $e');
    }
  }

  /// ایجاد یادآوری تک‌باره
  Future<void> scheduleOneTimeReminder({
    required String title,
    required String description,
    required DateTime at,
  }) async {
    try {
      final reminder = SmartReminder(
        title: title,
        description: description,
        type: ReminderType.oneTime,
        nextReminderTime: at,
      );

      _reminders.add(reminder);
      await _saveReminders();
      await _scheduleWorkManagerTask(reminder);
    } catch (e) {
      print('Error scheduling one-time reminder: $e');
    }
  }

  /// ایجاد یادآوری الگویی
  Future<void> schedulePatternReminder({
    required String title,
    required String description,
    required ReminderPattern pattern,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final start = startTime ?? DateTime.now();
      final reminder = SmartReminder(
        title: title,
        description: description,
        type: ReminderType.pattern,
        pattern: pattern,
        nextReminderTime: _calculateNextTime(pattern, start),
        endTime: endTime,
      );

      _reminders.add(reminder);
      await _saveReminders();
      await _scheduleWorkManagerTask(reminder);
    } catch (e) {
      print('Error scheduling pattern reminder: $e');
    }
  }

  /// ایجاد یادآوری هوشمند
  Future<void> scheduleSmartReminder({
    required String title,
    required String description,
    DateTime? suggestedTime,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final reminder = SmartReminder(
        title: title,
        description: description,
        type: ReminderType.smart,
        nextReminderTime: suggestedTime,
        metadata: metadata ?? {},
      );

      _reminders.add(reminder);
      await _saveReminders();

      if (suggestedTime != null) {
        await _scheduleWorkManagerTask(reminder);
      }
    } catch (e) {
      print('Error scheduling smart reminder: $e');
    }
  }

  /// حذف یادآوری
  Future<void> deleteReminder(String reminderId) async {
    try {
      _reminders.removeWhere((r) => r.id == reminderId);
      await _saveReminders();
      await WorkmanagerService.cancelReminder(reminderId);
    } catch (e) {
      print('Error deleting reminder: $e');
    }
  }

  /// توقف یادآوری
  Future<void> pauseReminder(String reminderId) async {
    try {
      final index = _reminders.indexWhere((r) => r.id == reminderId);
      if (index >= 0) {
        _reminders[index] = _reminders[index].copyWith(isActive: false);
        await _saveReminders();
        await WorkmanagerService.cancelReminder(reminderId);
      }
    } catch (e) {
      print('Error pausing reminder: $e');
    }
  }

  /// ادامۀ یادآوری
  Future<void> resumeReminder(String reminderId) async {
    try {
      final index = _reminders.indexWhere((r) => r.id == reminderId);
      if (index >= 0) {
        _reminders[index] = _reminders[index].copyWith(isActive: true);
        await _saveReminders();
        await _scheduleWorkManagerTask(_reminders[index]);
      }
    } catch (e) {
      print('Error resuming reminder: $e');
    }
  }

  /// دریافت یادآوری براساس ID
  SmartReminder? getReminder(String reminderId) {
    try {
      return _reminders.firstWhere((r) => r.id == reminderId);
    } catch (_) {
      return null;
    }
  }

  /// محاسبۀ زمان بعدی برای الگو
  DateTime _calculateNextTime(ReminderPattern pattern, DateTime from) {
    final now = DateTime.now();
    final later = from.isBefore(now) ? now : from;

    switch (pattern) {
      case ReminderPattern.daily:
        return later.add(const Duration(days: 1));
      case ReminderPattern.everyTwoDays:
        return later.add(const Duration(days: 2));
      case ReminderPattern.weekly:
        return later.add(const Duration(days: 7));
      case ReminderPattern.biWeekly:
        return later.add(const Duration(days: 14));
      case ReminderPattern.monthly:
        return later.add(const Duration(days: 30));
    }
  }

  /// برنامه‌ریزی WorkManager Task
  Future<void> _scheduleWorkManagerTask(SmartReminder reminder) async {
    try {
      if (reminder.nextReminderTime == null || !reminder.isActive) {
        return;
      }

      await WorkmanagerService.scheduleReminder(
        title: reminder.title,
        body: reminder.description,
        at: reminder.nextReminderTime!,
        payload: {'reminderId': reminder.id},
      );
    } catch (e) {
      print('Error scheduling WorkManager task: $e');
    }
  }

  /// پاک کردن تمام یادآورها
  Future<void> clearAll() async {
    try {
      for (final reminder in _reminders) {
        await WorkmanagerService.cancelReminder(reminder.id);
      }
      _reminders.clear();
      await _saveReminders();
    } catch (e) {
      print('Error clearing all reminders: $e');
    }
  }

  void dispose() {
    super.dispose();
  }
}
