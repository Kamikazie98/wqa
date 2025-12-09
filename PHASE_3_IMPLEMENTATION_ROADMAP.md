# 🚀 Phase 3 Implementation Roadmap - فاز ۳ پیاده‌سازی

**هدف**: تکمیل ویژگی‌های درخواستی شده

---

## 📋 اولویت‌های پیاده‌سازی

### اولویت ۱ - خواندن و تحلیل پیام‌ها (7-10 روز)

#### 1.1 `MessageReaderService` - خوانندگی پیام‌های بومی
**فایل**: `lib/services/message_reader_service.dart`

```dart
// TODO: پیاده‌سازی نقاط:

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SMSMessage {
  final String id;
  final String sender;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  
  SMSMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.isRead,
  });
}

class MessageReaderService {
  static const _channel = MethodChannel('com.example.waiq/messages');
  final SharedPreferences _prefs;
  final _messageController = StreamController<SMSMessage>.broadcast();
  
  MessageReaderService({required SharedPreferences prefs}) : _prefs = prefs;
  
  // TODO: 1. getPendingSMSMessages() - دریافت پیام‌های نخوانده
  Future<List<SMSMessage>> getPendingSMSMessages({int limit = 50}) async {
    // 1. فراخوانی Native Method برای دریافت از ContentProvider
    // 2. فیلتر کردن پیام‌های نخوانده
    // 3. ذخیره‌سازی در کش
    // 4. بازگشت لیست
  }
  
  // TODO: 2. watchNewMessages() - مراقبت پیام‌های جدید
  Stream<SMSMessage> watchNewMessages() {
    // 1. مراقبت ثابت از ContentProvider
    // 2. ارسال پیام‌های جدید
    // 3. بروز‌رسانی کش
  }
  
  // TODO: 3. getWhatsAppMessages() - دسترسی به WhatsApp
  Future<List<Map<String, dynamic>>> getWhatsAppMessages({
    required int count,
    String? contact,
  }) async {
    // نوت: نیاز به اجازه‌های خاص
    // 1. دسترسی به Database WhatsApp
    // 2. فیلتر کردن مکالمات
    // 3. بازگشت پیام‌های اخیر
  }
  
  // TODO: 4. getTelegramMessages() - دسترسی به Telegram
  Future<List<Map<String, dynamic>>> getTelegramMessages({
    required int count,
    String? contact,
  }) async {
    // نوت: احتمال محدود بسته به اجازات Telegram
    // استفاده از TDLib یا Bot API
  }
}
```

**کارهای نیاز برای مرحله بعد**:
- [ ] ایجاد Native Kotlin Code برای ContentProvider دسترسی
- [ ] پیاده‌سازی WorkManager برای sync پس‌زمینه
- [ ] تست با اجازات مختلف

---

#### 1.2 `MessageAnalysisService` - تحلیل و استخراج اطلاعات
**فایل**: `lib/services/message_analysis_service.dart`

```dart
// TODO: پیاده‌سازی نقاط:

import '../models/assistant_models.dart';
import 'local_nlp_processor.dart';

class MessageAnalysisService {
  final LocalNLPProcessor _nlp;
  final AssistantService _assistant;
  
  MessageAnalysisService({
    required LocalNLPProcessor nlp,
    required AssistantService assistant,
  }) : _nlp = nlp, _assistant = assistant;
  
  // TODO: 1. extractKeyPoints() - استخراج نکات مهم
  Future<List<String>> extractKeyPoints(String message) async {
    // 1. استفاده از NLP محلی
    // 2. شناسایی کلمات کلیدی
    // 3. خلاصه‌سازی جملات
    // مثال: "فردا ساعت 3 جلسه" → ["فردا", "ساعت 3", "جلسه"]
  }
  
  // TODO: 2. extractPersonalInfo() - استخراج اطلاعات شخصی
  Future<Map<String, dynamic>> extractPersonalInfo(String message) async {
    // 1. شناسایی اسامی
    // 2. شناسایی تاریخ‌ها
    // 3. شناسایی فون‌نامبر‌ها
    // 4. شناسایی آدرس‌ها
    // مثال: "علی از تهران پیام داد" → {names: ["علی"], locations: ["تهران"]}
  }
  
  // TODO: 3. detectPriority() - شناسایی اولویت
  Future<MessagePriority> detectPriority(String message) async {
    // 1. شناسایی کلمات فوری ("فوری", "مهم", "الان")
    // 2. شناسایی نوع ارسال‌کننده
    // 3. تحلیل تاریخ/زمان
    // بازگشت: high / medium / low
  }
  
  // TODO: 4. getSmartSummary() - خلاصه‌سازی هوشمند
  Future<String> getSmartSummary(String message) async {
    // 1. استفاده از API Backend
    // 2. ایجاد خلاصۀ فارسی
    // 3. اضافه کردن emoji‌های مناسب
  }
  
  // TODO: 5. shouldRemind() - آیا یادآوری لازم است؟
  Future<bool> shouldRemind(String message) async {
    // 1. بررسی اولویت
    // 2. بررسی وجود درخواست عمل
    // 3. بررسی زمان حساس
  }
}

enum MessagePriority { high, medium, low }
```

**کارهای نیاز برای مرحله بعد**:
- [ ] اتصال به Local NLP Processor
- [ ] تست‌های Entity Extraction
- [ ] تطبیق فارسی

---

### اولویت ۲ - یادآوری هوشمند (5-7 روز)

#### 2.1 `SmartRemindersService` - یادآوری‌های هوشمند
**فایل**: `lib/services/smart_reminders_service.dart`

```dart
// TODO: پیاده‌سازی نقاط:

import 'workmanager_service.dart';
import 'package:location/location.dart';

class SmartReminder {
  final String id;
  final String title;
  final String description;
  final ReminderType type;
  final ReminderPattern? pattern;
  final LocationTrigger? location;
  final DateTime createdAt;
  final bool isActive;
  
  SmartReminder({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.pattern,
    this.location,
    required this.createdAt,
    this.isActive = true,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.toString(),
    'pattern': pattern?.toString(),
    'location': location?.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };
}

enum ReminderType { oneTime, pattern, location, smart }
enum ReminderPattern { daily, everyTwoDays, weekly, biWeekly, monthly }

class LocationTrigger {
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String name;
  
  LocationTrigger({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.name,
  });
  
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'name': name,
  };
}

class SmartRemindersService with ChangeNotifier {
  final SharedPreferences _prefs;
  final NotificationService _notifications;
  final Location _location = Location();
  
  final List<SmartReminder> _reminders = [];
  
  SmartRemindersService({
    required SharedPreferences prefs,
    required NotificationService notifications,
  }) : _prefs = prefs, _notifications = notifications;
  
  List<SmartReminder> get reminders => _reminders;
  
  // TODO: 1. schedulePatternReminder() - یادآوری الگویی
  Future<void> schedulePatternReminder({
    required String title,
    required String description,
    required ReminderPattern pattern,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? time,
  }) async {
    // 1. محاسبه تاریخ‌های یادآوری
    // 2. ثبت در WorkManager
    // 3. ذخیره در پایگاه داده
    // 4. آغاز اولین یادآوری
  }
  
  // TODO: 2. scheduleLocationReminder() - یادآوری مکان‌محور
  Future<void> scheduleLocationReminder({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    String? name,
  }) async {
    // 1. فعال‌سازی Location Tracking
    // 2. ایجاد Geofence
    // 3. ثبت یادآوری در پایگاه داده
    // 4. مراقبت موقعیت با WorkManager
  }
  
  // TODO: 3. scheduleSmartReminder() - یادآوری هوشمند
  Future<void> scheduleSmartReminder({
    required String title,
    required String context,
    DateTime? suggestedTime,
    Map<String, dynamic>? metadata,
  }) async {
    // 1. تحلیل متن
    // 2. شناسایی زمان
    // 3. ایجاد یادآوری
    // 4. ثبت در سیستم
  }
  
  // TODO: 4. getAllReminders() - دریافت تمام یادآورها
  Future<List<SmartReminder>> getAllReminders() async {
    // 1. بارگذاری از SharedPreferences
    // 2. فیلتر یادآورهای فعال
    // 3. مرتب‌سازی بر اساس زمان
  }
  
  // TODO: 5. deleteReminder() - حذف یادآوری
  Future<void> deleteReminder(String reminderId) async {
    // 1. حذف از پایگاه داده
    // 2. لغو WorkManager Task
    // 3. بروز‌رسانی State
  }
  
  // TODO: 6. pauseReminder() - موقوف کردن یادآوری
  Future<void> pauseReminder(String reminderId) async {
    // 1. تعطیل Task در WorkManager
    // 2. بروز‌رسانی وضعیت
  }
  
  // TODO: 7. resumeReminder() - ادامه یادآوری
  Future<void> resumeReminder(String reminderId) async {
    // 1. فعال‌سازی Task در WorkManager
    // 2. بروز‌رسانی وضعیت
  }
}
```

**کارهای نیاز برای مرحله بعد**:
- [ ] Location Tracking فعال‌سازی
- [ ] Geofencing پیاده‌سازی
- [ ] WorkManager Pattern Tasks

---

### اولویت ۳ - رابط‌کاربری (UI Pages) (5-7 روز)

#### 3.1 `RemindersManagementPage` - صفحۀ مدیریت یادآورها
**فایل**: `lib/screens/reminders_management_page.dart`

```dart
// TODO: ویژگی‌های مورد نیاز:

class RemindersManagementPage extends StatefulWidget {
  // 1. لیست یادآورها (List View)
  // 2. ایجاد یادآوری جدید (FAB Button)
  // 3. ویرایش یادآوری (Long Press)
  // 4. حذف یادآوری (Swipe to Delete)
  // 5. غیرفعال‌سازی/فعال‌سازی (Toggle)
  // 6. فیلتر بر اساس نوع (Filter Chips)
  // 7. جستجو (Search Field)
  
  @override
  State<RemindersManagementPage> createState() => _RemindersManagementPageState();
}

class _RemindersManagementPageState extends State<RemindersManagementPage> {
  // TODO: 1. initState() - بارگذاری یادآورها
  @override
  void initState() {
    super.initState();
    // دریافت تمام یادآورها
    // بروز‌رسانی UI
  }
  
  // TODO: 2. _buildReminderCard() - کارت نمایش یادآوری
  Widget _buildReminderCard(SmartReminder reminder) {
    // نمایش عنوان
    // نمایش توضیح
    // نمایش نوع (الگو/مکان/معمولی)
    // نمایش وضعیت (فعال/غیرفعال)
    // دکمه‌های اقدام
  }
  
  // TODO: 3. _showCreateReminderSheet() - ورودی یادآوری جدید
  void _showCreateReminderSheet() {
    // Form برای ورودی
    // انتخاب نوع یادآوری
    // زمان/مکان بر اساس نوع
    // دکمه‌های ذخیره/لغو
  }
  
  // TODO: 4. _deleteReminder() - حذف یادآوری
  Future<void> _deleteReminder(String reminderId) async {
    // درخواست تأیید
    // حذف
    // نمایش پیام موفق
  }
}
```

---

#### 3.2 بهبود `DailyPlanningPage` - صفحۀ برنامه‌ریزی
**فایل**: `lib/screens/daily_planning_page.dart` (بهبود موجود)

```dart
// TODO: ویژگی‌های مورد نیاز:

class DailyPlanningPage extends StatefulWidget {
  // 1. Timeline بصری (Vertical Timeline)
  // 2. درگ اند دراپ برای تغییر ترتیب
  // 3. اضافه کردن فعالیت دستی
  // 4. حذف فعالیت
  // 5. تغییر زمان فعالیت
  // 6. نمایش آمار روزانه (Focus/Break Time)
  // 7. ذخیره‌سازی تغییرات
  // 8. اعلان برای هر فعالیت
  
  @override
  State<DailyPlanningPage> createState() => _DailyPlanningPageState();
}

class _DailyPlanningPageState extends State<DailyPlanningPage> {
  // TODO: 1. _buildTimeline() - نمایش Timeline بصری
  Widget _buildTimeline(DailyProgram program) {
    // استفاده از timeline_tile package
    // نمایش فعالیت‌های مرتب بر اساس زمان
    // رنگ‌بندی بر اساس دسته (Goal/Habit/Break)
    // درگ اند دراپ برای تغییر ترتیب
  }
  
  // TODO: 2. _reorderActivities() - تغییر ترتیب
  Future<void> _reorderActivities(int oldIndex, int newIndex) async {
    // به‌روزرسانی موقعیت
    // محاسبه‌ی زمان‌های جدید
    // ذخیره‌سازی تغییرات
  }
  
  // TODO: 3. _showAddActivitySheet() - اضافه کردن فعالیت جدید
  void _showAddActivitySheet() {
    // Form ورودی
    // انتخاب دسته (Goal/Habit/Break)
    // تعیین زمان
    // تعیین مدت
    // ذخیره
  }
  
  // TODO: 4. _scheduleActivityNotification() - اعلان برای فعالیت
  Future<void> _scheduleActivityNotification(ProgramActivity activity) async {
    // برنامه‌ریزی اعلان برای شروع فعالیت
    // اعلان 5 دقیقه قبل از شروع
    // اعلان 1 دقیقه قبل از شروع
  }
}
```

---

## 🔍 فایل‌های مدل‌های داده نیاز

### `lib/models/message_models.dart`

```dart
// TODO: مدل‌های داده پیام‌ها

class Message {
  final String id;
  final String sender;
  final String body;
  final DateTime timestamp;
  final String channel; // sms / whatsapp / telegram / email
  final bool isRead;
  final List<String> keyPoints;
  final Map<String, dynamic> extractedInfo;
  final MessagePriority priority;
  final String? summary;
  
  Message({
    required this.id,
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.channel,
    required this.isRead,
    this.keyPoints = const [],
    this.extractedInfo = const {},
    this.priority = MessagePriority.medium,
    this.summary,
  });
}

enum MessagePriority { high, medium, low }
```

---

## 📊 جدول Gantt - تقویم پیاده‌سازی

```
Phase 3 Timeline (تقریبی):

Week 1:
├─ MessageReaderService (60%)
├─ Native Kotlin Layer (80%)
└─ تست‌های اولیه (40%)

Week 2:
├─ MessageAnalysisService (80%)
├─ NLP Integration (70%)
└─ تست‌های یکپارچگی (60%)

Week 3:
├─ SmartRemindersService (80%)
├─ WorkManager Tasks (70%)
└─ Location Tracking (50%)

Week 4:
├─ RemindersManagementPage (80%)
├─ DailyPlanningPage Enhancement (70%)
└─ تست و بهینه‌سازی (80%)

Week 5:
├─ Bug Fixes (90%)
├─ Performance Optimization (70%)
└─ Documentation (100%)
```

---

## ⚡ فایل‌های اولویت برای شروع فوری

### فاز ۱ - روزهای ۱-۲

```
1. ایجاد lib/services/message_reader_service.dart
2. بروز‌رسانی Native Bridge برای Message Reading
3. ایجاد مدل‌های پیام در lib/models/message_models.dart
4. تست‌های اولیه
```

### فاز ۲ - روزهای ۳-۴

```
1. ایجاد lib/services/message_analysis_service.dart
2. ادغام با LocalNLPProcessor
3. تست‌های Extract Key Points
```

### فاز ۳ - روزهای ۵-۶

```
1. ایجاد lib/services/smart_reminders_service.dart
2. تطبیق با WorkManager
3. تست Pattern Reminders
```

### فاز ۴ - روزهای ۷-۸

```
1. ایجاد lib/screens/reminders_management_page.dart
2. بهبود lib/screens/daily_planning_page.dart
3. تست UI/UX
```

---

## 🎯 معیارهای موفقیت

✅ تمام 7 فایل جدید ایجاد شده
✅ تمام 10+ فراخوانی API موفق هستند
✅ WorkManager Tasks درست کار می‌کنند
✅ Location Tracking کار می‌کند
✅ UI واکنش‌پذیر و زیبا است
✅ کد 90%+ بدون خطا

---

