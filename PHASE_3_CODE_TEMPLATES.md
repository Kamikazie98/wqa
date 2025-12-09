# 💻 Ready-to-Implement Code Templates - الگوهای آماده برای پیاده‌سازی

> این فایل شامل کد‌های آماده برای استفاده فوری در Phase 3 است.

---

## 1️⃣ Message Models - `lib/models/message_models.dart`

```dart
import 'package:json_annotation/json_annotation.dart';

part 'message_models.g.dart';

enum MessagePriority {
  @JsonValue('high')
  high,
  @JsonValue('medium')
  medium,
  @JsonValue('low')
  low,
}

enum MessageChannel {
  @JsonValue('sms')
  sms,
  @JsonValue('whatsapp')
  whatsapp,
  @JsonValue('telegram')
  telegram,
  @JsonValue('email')
  email,
  @JsonValue('messenger')
  messenger,
}

@JsonSerializable()
class Message {
  final String id;
  final String sender;
  final String senderName;
  final String body;
  final DateTime timestamp;
  final MessageChannel channel;
  final bool isRead;
  final bool isArchived;
  final List<String> keyPoints;
  final Map<String, dynamic> extractedInfo;
  final MessagePriority priority;
  final String? summary;
  final bool needsReply;
  final List<String> suggestedActions;

  Message({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.body,
    required this.timestamp,
    required this.channel,
    required this.isRead,
    this.isArchived = false,
    this.keyPoints = const [],
    this.extractedInfo = const {},
    this.priority = MessagePriority.medium,
    this.summary,
    this.needsReply = false,
    this.suggestedActions = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);

  Message copyWith({
    bool? isRead,
    bool? isArchived,
    List<String>? keyPoints,
    String? summary,
    bool? needsReply,
    MessagePriority? priority,
  }) {
    return Message(
      id: id,
      sender: sender,
      senderName: senderName,
      body: body,
      timestamp: timestamp,
      channel: channel,
      isRead: isRead ?? this.isRead,
      isArchived: isArchived ?? this.isArchived,
      keyPoints: keyPoints ?? this.keyPoints,
      extractedInfo: extractedInfo,
      priority: priority ?? this.priority,
      summary: summary ?? this.summary,
      needsReply: needsReply ?? this.needsReply,
      suggestedActions: suggestedActions,
    );
  }

  bool get isImportant => priority == MessagePriority.high || needsReply;
  
  Duration get age => DateTime.now().difference(timestamp);
  
  bool get isRecent => age.inHours < 24;
}

@JsonSerializable()
class MessageThread {
  final String id;
  final List<Message> messages;
  final String participantName;
  final MessageChannel channel;
  final DateTime lastMessageTime;
  final bool hasUnread;
  final int unreadCount;

  MessageThread({
    required this.id,
    required this.messages,
    required this.participantName,
    required this.channel,
    required this.lastMessageTime,
    this.hasUnread = false,
    this.unreadCount = 0,
  });

  factory MessageThread.fromJson(Map<String, dynamic> json) =>
      _$MessageThreadFromJson(json);

  Map<String, dynamic> toJson() => _$MessageThreadToJson(this);

  Message? get lastMessage => messages.isNotEmpty ? messages.last : null;
  
  int get messageCount => messages.length;
}

@JsonSerializable()
class ExtractedMessageInfo {
  final List<String> names;
  final List<String> locations;
  final List<String> dates;
  final List<String> times;
  final List<String> phoneNumbers;
  final List<String> emails;
  final List<String> emotions;
  final Map<String, dynamic> customData;

  ExtractedMessageInfo({
    this.names = const [],
    this.locations = const [],
    this.dates = const [],
    this.times = const [],
    this.phoneNumbers = const [],
    this.emails = const [],
    this.emotions = const [],
    this.customData = const {},
  });

  factory ExtractedMessageInfo.fromJson(Map<String, dynamic> json) =>
      _$ExtractedMessageInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ExtractedMessageInfoToJson(this);
}
```

---

## 2️⃣ Message Reader Service - `lib/services/message_reader_service.dart`

```dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_models.dart';

class MessageReaderService {
  static const _channel = MethodChannel('com.example.waiq/messages');
  static const _smsChannel = MethodChannel('com.example.waiq/sms');
  
  final SharedPreferences _prefs;
  final _messageController = StreamController<Message>.broadcast();
  
  Timer? _syncTimer;
  DateTime? _lastSync;

  MessageReaderService({required SharedPreferences prefs}) : _prefs = prefs;

  Stream<Message> get messageStream => _messageController.stream;

  /// دریافت پیام‌های نخوانده
  Future<List<Message>> getPendingMessages({
    int limit = 50,
    MessageChannel? channel,
  }) async {
    try {
      final result = await _smsChannel.invokeMethod<List<dynamic>>(
        'getPendingMessages',
        {
          'limit': limit,
          'channel': channel?.toString() ?? 'all',
        },
      );

      if (result == null) return [];

      final messages = result
          .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      // ذخیره در کش
      await _cacheMessages(messages);

      return messages;
    } catch (e) {
      print('Error getting pending messages: $e');
      return _getCachedMessages();
    }
  }

  /// دریافت تمام پیام‌ها
  Future<List<MessageThread>> getMessageThreads({
    int limit = 50,
    MessageChannel? channel,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getMessageThreads',
        {
          'limit': limit,
          'channel': channel?.toString() ?? 'all',
        },
      );

      if (result == null) return [];

      return result
          .map((e) => MessageThread.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      print('Error getting message threads: $e');
      return [];
    }
  }

  /// مراقبت پیام‌های جدید
  void startWatching() {
    _syncTimer = Timer.periodic(Duration(minutes: 5), (_) async {
      final messages = await getPendingMessages();
      for (final msg in messages) {
        if (!msg.isRead) {
          _messageController.add(msg);
        }
      }
    });
  }

  /// متوقف کردن مراقبت
  void stopWatching() {
    _syncTimer?.cancel();
  }

  /// علامت‌گذاری به‌عنوان خوانده‌شده
  Future<void> markAsRead(String messageId) async {
    try {
      await _channel.invokeMethod('markAsRead', {'messageId': messageId});
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// ذخیره پیام‌ها در کش
  Future<void> _cacheMessages(List<Message> messages) async {
    final json = messages.map((e) => e.toJson()).toList();
    await _prefs.setString('messages.cache', jsonEncode(json));
    await _prefs.setString(
      'messages.cache.updated',
      DateTime.now().toIso8601String(),
    );
  }

  /// بارگذاری پیام‌های کش‌شده
  List<Message> _getCachedMessages() {
    try {
      final raw = _prefs.getString('messages.cache');
      if (raw == null) return [];

      final list = jsonDecode(raw) as List;
      return list.map((e) => Message.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    stopWatching();
    _messageController.close();
  }
}
```

---

## 3️⃣ Message Analysis Service - `lib/services/message_analysis_service.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_models.dart';
import '../services/local_nlp_processor.dart';
import '../services/assistant_service.dart';

class MessageAnalysisService {
  final LocalNLPProcessor _nlp;
  final AssistantService _assistant;
  final SharedPreferences _prefs;

  MessageAnalysisService({
    required LocalNLPProcessor nlp,
    required AssistantService assistant,
    required SharedPreferences prefs,
  })  : _nlp = nlp,
        _assistant = assistant,
        _prefs = prefs;

  /// استخراج نکات مهم
  Future<List<String>> extractKeyPoints(String message) async {
    try {
      // تقسیم جملات
      final sentences = message.split(RegExp(r'[.!?]'));

      final keyPoints = <String>[];

      for (final sentence in sentences) {
        if (sentence.trim().isEmpty) continue;

        // استفاده از NLP برای شناسایی کلمات کلیدی
        final entities = _nlp.extractEntities(sentence);

        // افزودن نام‌ها
        if (entities['names'] != null && entities['names'].isNotEmpty) {
          keyPoints.addAll(entities['names']);
        }

        // افزودن تاریخ‌ها
        if (entities['dates'] != null && entities['dates'].isNotEmpty) {
          keyPoints.addAll(entities['dates']);
        }

        // افزودن اوقات
        if (entities['times'] != null && entities['times'].isNotEmpty) {
          keyPoints.addAll(entities['times']);
        }

        // افزودن مکان‌ها
        if (entities['locations'] != null && entities['locations'].isNotEmpty) {
          keyPoints.addAll(entities['locations']);
        }
      }

      return keyPoints.toSet().toList(); // حذف تکراری‌ها
    } catch (e) {
      return [];
    }
  }

  /// استخراج اطلاعات شخصی
  Future<ExtractedMessageInfo> extractPersonalInfo(String message) async {
    try {
      final entities = _nlp.extractAdvancedEntities(message);

      return ExtractedMessageInfo(
        names: List<String>.from(entities['names'] ?? []),
        locations: List<String>.from(entities['locations'] ?? []),
        dates: List<String>.from(entities['dates'] ?? []),
        times: List<String>.from(entities['times'] ?? []),
        phoneNumbers: _extractPhoneNumbers(message),
        emails: _extractEmails(message),
        emotions: List<String>.from(entities['emotions'] ?? []),
      );
    } catch (e) {
      return ExtractedMessageInfo();
    }
  }

  /// شناسایی اولویت
  Future<MessagePriority> detectPriority(String message) async {
    try {
      // کلمات فوری
      final urgentKeywords = [
        'فوری',
        'الان',
        'فورا',
        'اضطراری',
        'emergency',
        'urgent',
        'immediately',
      ];

      final messageLower = message.toLowerCase();
      if (urgentKeywords.any((kw) => messageLower.contains(kw))) {
        return MessagePriority.high;
      }

      // کلمات عادی
      final normalKeywords = [
        'معمول',
        'معمولی',
        'عادی',
        'normal',
        'regular',
      ];

      if (normalKeywords.any((kw) => messageLower.contains(kw))) {
        return MessagePriority.low;
      }

      return MessagePriority.medium;
    } catch (e) {
      return MessagePriority.medium;
    }
  }

  /// خلاصه‌سازی پیام
  Future<String> getSummary(String message) async {
    try {
      // برای پیام‌های کوتاه، خود پیام را بازگردان
      if (message.length < 100) {
        return message;
      }

      // استفاده از Assistant API برای خلاصه‌سازی
      // (توجه: این نیاز به API Backend دارد)
      
      return message.substring(0, 100) + '...';
    } catch (e) {
      return message;
    }
  }

  /// آیا نیاز به یادآوری است؟
  Future<bool> shouldRemind(String message) async {
    try {
      // شناسایی کلماتی که نیاز به یادآوری را نشان می‌دهند
      final remindKeywords = [
        'یادآوری',
        'یادم باش',
        'لطفا',
        'درخواست',
        'reminder',
        'please',
        'request',
        'remind',
      ];

      final messageLower = message.toLowerCase();
      return remindKeywords.any((kw) => messageLower.contains(kw));
    } catch (e) {
      return false;
    }
  }

  /// آیا پاسخ لازم است؟
  Future<bool> needsReply(String message) async {
    try {
      // علامت‌های سؤال
      if (message.contains('؟') || message.contains('?')) {
        return true;
      }

      // فراخوان‌های مستقیم
      final callKeywords = [
        'تو',
        'شما',
        'می‌تونی',
        'می‌شه',
        'you',
        'can you',
        'could you',
      ];

      final messageLower = message.toLowerCase();
      return callKeywords.any((kw) => messageLower.contains(kw));
    } catch (e) {
      return false;
    }
  }

  // توابع کمکی
  List<String> _extractPhoneNumbers(String message) {
    final regex = RegExp(r'\d{10,}');
    return regex.allMatches(message).map((m) => m.group(0)!).toList();
  }

  List<String> _extractEmails(String message) {
    final regex =
        RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    return regex.allMatches(message).map((m) => m.group(0)!).toList();
  }
}
```

---

## 4️⃣ Smart Reminders Service - `lib/services/smart_reminders_service.dart`

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/message_models.dart';
import 'workmanager_service.dart';
import 'notification_service.dart';

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
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: ReminderType.values.byName(json['type']),
      pattern: json['pattern'] != null
          ? ReminderPattern.values.byName(json['pattern'])
          : null,
      nextReminderTime: json['nextReminderTime'] != null
          ? DateTime.parse(json['nextReminderTime'])
          : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
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
}

class SmartRemindersService with ChangeNotifier {
  static const _remindersKey = 'smart_reminders.list';

  final SharedPreferences _prefs;
  final NotificationService _notifications;

  final List<SmartReminder> _reminders = [];

  SmartRemindersService({
    required SharedPreferences prefs,
    required NotificationService notifications,
  })  : _prefs = prefs,
        _notifications = notifications;

  List<SmartReminder> get reminders => _reminders;
  List<SmartReminder> get activeReminders =>
      _reminders.where((r) => r.isActive && !r.isExpired).toList();

  /// بارگذاری یادآورها از ذخیره‌سازی
  Future<void> loadReminders() async {
    try {
      final raw = _prefs.getStringList(_remindersKey) ?? [];
      _reminders.clear();
      _reminders.addAll(
        raw.map((e) => SmartReminder.fromJson(jsonDecode(e))),
      );
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
        _reminders[index] = SmartReminder(
          id: _reminders[index].id,
          title: _reminders[index].title,
          description: _reminders[index].description,
          type: _reminders[index].type,
          pattern: _reminders[index].pattern,
          nextReminderTime: _reminders[index].nextReminderTime,
          endTime: _reminders[index].endTime,
          isActive: false,
          createdAt: _reminders[index].createdAt,
          metadata: _reminders[index].metadata,
        );
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
        _reminders[index] = SmartReminder(
          id: _reminders[index].id,
          title: _reminders[index].title,
          description: _reminders[index].description,
          type: _reminders[index].type,
          pattern: _reminders[index].pattern,
          nextReminderTime: _reminders[index].nextReminderTime,
          endTime: _reminders[index].endTime,
          isActive: true,
          createdAt: _reminders[index].createdAt,
          metadata: _reminders[index].metadata,
        );
        await _saveReminders();
        await _scheduleWorkManagerTask(_reminders[index]);
      }
    } catch (e) {
      print('Error resuming reminder: $e');
    }
  }

  /// محاسبۀ زمان بعدی برای الگو
  DateTime _calculateNextTime(ReminderPattern pattern, DateTime from) {
    final now = DateTime.now();
    final later = from.isBefore(now) ? now : from;

    switch (pattern) {
      case ReminderPattern.daily:
        return later.add(Duration(days: 1));
      case ReminderPattern.everyTwoDays:
        return later.add(Duration(days: 2));
      case ReminderPattern.weekly:
        return later.add(Duration(days: 7));
      case ReminderPattern.biWeekly:
        return later.add(Duration(days: 14));
      case ReminderPattern.monthly:
        return later.add(Duration(days: 30));
    }
  }

  /// برنامه‌ریزی WorkManager Task
  Future<void> _scheduleWorkManagerTask(SmartReminder reminder) async {
    try {
      if (reminder.nextReminderTime == null) return;

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

  void dispose() {
    super.dispose();
  }
}
```

---

## 5️⃣ Extensions and Helpers

### `lib/extensions/message_extensions.dart`

```dart
import '../models/message_models.dart';

extension MessagePriorityExtension on MessagePriority {
  String get label {
    switch (this) {
      case MessagePriority.high:
        return 'فوری';
      case MessagePriority.medium:
        return 'عادی';
      case MessagePriority.low:
        return 'کم‌اهمیت';
    }
  }

  String get emoji {
    switch (this) {
      case MessagePriority.high:
        return '🔴';
      case MessagePriority.medium:
        return '🟡';
      case MessagePriority.low:
        return '🟢';
    }
  }
}

extension MessageChannelExtension on MessageChannel {
  String get label {
    switch (this) {
      case MessageChannel.sms:
        return 'پیامک';
      case MessageChannel.whatsapp:
        return 'واتس‌اپ';
      case MessageChannel.telegram:
        return 'تلگرام';
      case MessageChannel.email:
        return 'ایمیل';
      case MessageChannel.messenger:
        return 'مسنجر';
    }
  }

  String get emoji {
    switch (this) {
      case MessageChannel.sms:
        return '📱';
      case MessageChannel.whatsapp:
        return '💬';
      case MessageChannel.telegram:
        return '✈️';
      case MessageChannel.email:
        return '📧';
      case MessageChannel.messenger:
        return '💭';
    }
  }
}
```

---

## 6️⃣ Injectable Service Registration

### بروز‌رسانی `lib/main.dart`

```dart
// اضافه کردن بخش‌های زیر:

final messageReaderService = MessageReaderService(prefs: prefs);
final messageAnalysisService = MessageAnalysisService(
  nlp: context.read<LocalNLPProcessor>(),
  assistant: assistantService,
  prefs: prefs,
);
final smartRemindersService = SmartRemindersService(
  prefs: prefs,
  notifications: notificationService,
);

// بارگذاری یادآورها
await smartRemindersService.loadReminders();

// شروع مراقبت پیام‌ها
messageReaderService.startWatching();

// ثبت در Provider
MultiProvider(
  providers: [
    Provider(create: (_) => messageReaderService),
    Provider(create: (_) => messageAnalysisService),
    ChangeNotifierProvider(create: (_) => smartRemindersService),
  ],
  child: const MyApp(),
);
```

---

## ✨ خلاصه

این کد‌های آماده شامل:
- ✅ تمام مدل‌های داده
- ✅ تمام سرویس‌های مورد نیاز
- ✅ توابع کمکی
- ✅ Extensions
- ✅ Serialization/Deserialization

**نکات مهم**:
- نیاز به `json_serializable` برای تولید کد
- نیاز به `uuid` package برای ID تولید
- نیاز به `location` package برای Geofencing
- تمام مکان‌های `TODO` باید تکمیل شوند

