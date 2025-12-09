import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/assistant_models.dart';
import 'assistant_service.dart';
import 'notification_service.dart';
import 'workmanager_service.dart';

class ActionExecutor {
  ActionExecutor(this._notifications, this._assistant);

  final NotificationService _notifications;
  final AssistantService _assistant;

  Future<void> execute(AssistantIntentResult intent) async {
    switch (intent.action) {
      case SmartAction.reminder:
        await _handleReminder(intent.payload);
        break;
      case SmartAction.followUp:
        await _handleFollowUp(intent.payload);
        break;
      case SmartAction.sendMessage:
        await _handleSendMessage(intent.payload);
        break;
      case SmartAction.call:
        await _handleCall(intent.payload);
        break;
      case SmartAction.openApp:
        await _handleOpenApp(intent.payload);
        break;
      case SmartAction.openLink:
      case SmartAction.webSearch:
        await _handleOpenLink(intent.payload);
        break;
      case SmartAction.openCamera:
        await _launchUri(Uri.parse('camera:'));
        break;
      case SmartAction.openGallery:
        await _launchUri(Uri.parse('content://media/internal/images/media'));
        break;
      case SmartAction.calendarEvent:
        await _handleCalendarEvent(intent.payload);
        break;
      case SmartAction.note:
        await _handleNote(intent.payload);
        break;
      case SmartAction.memoryUpsert:
        await _handleMemoryUpsert(intent.payload);
        break;
      case SmartAction.routine:
      case SmartAction.automation:
        await _handleRoutine(intent.payload);
        break;
      case SmartAction.dailyBriefing:
        await _showPayloadNotification(
          title: 'خلاصه روز',
          body: intent.payload['briefing']?.toString() ??
              intent.payload['text']?.toString() ??
              'خلاصه آماده است',
        );
        break;
      case SmartAction.modeSwitch:
        await _showPayloadNotification(
          title: 'تغییر حالت',
          body: intent.payload['mode']?.toString() ?? 'حالت جدید فعال شد',
        );
        break;
      case SmartAction.notificationTriage:
      case SmartAction.suggestion:
        await _showPayloadNotification(
          title: 'اقدام پیشنهادی',
          body: jsonEncode(intent.payload),
        );
        break;
    }
  }

  Future<void> _handleReminder(Map<String, dynamic> payload) async {
    final title = payload['title']?.toString() ?? 'یادآور';
    final details = payload['details']?.toString() ?? '';
    final when = _parseDate(payload['datetime']?.toString());
    if (when != null && when.isAfter(DateTime.now())) {
      await _notifications.scheduleLocalNotification(
        title: title,
        body: details.isEmpty ? 'یادآور زمان‌بندی شد' : details,
        scheduledAt: when,
        payload: jsonEncode(payload),
      );
      await WorkmanagerService.scheduleReminder(
        title: title,
        body: details.isEmpty ? 'یادآور' : details,
        at: when,
        payload: payload,
      );
    } else {
      await _notifications.showLocalNow(
        title: title,
        body: details.isEmpty ? 'یادآور ایجاد شد' : details,
        payload: jsonEncode(payload),
      );
    }
  }

  Future<void> _handleFollowUp(Map<String, dynamic> payload) async {
    final subject = payload['subject']?.toString() ?? 'پیگیری';
    final deadline = _parseDate(payload['deadline']?.toString());
    final task = payload['task']?.toString() ?? 'پیگیری انجام شود';
    if (deadline != null && deadline.isAfter(DateTime.now())) {
      await _notifications.scheduleLocalNotification(
        title: 'پیگیری: $subject',
        body: task,
        scheduledAt: deadline,
        payload: jsonEncode(payload),
      );
      await WorkmanagerService.scheduleFollowUp(
        subject: subject,
        task: task,
        at: deadline,
        payload: payload,
      );
    } else {
      await _notifications.showLocalNow(
        title: 'پیگیری: $subject',
        body: task,
        payload: jsonEncode(payload),
      );
    }
  }

  Future<void> _handleSendMessage(Map<String, dynamic> payload) async {
    final recipient = payload['recipient']?.toString() ?? '';
    final text = payload['suggested_text']?.toString() ?? '';
    final channel = payload['channel']?.toString() ?? 'sms';

    switch (channel) {
      case 'whatsapp':
        final uri = Uri.parse('whatsapp://send').replace(queryParameters: {
          if (recipient.isNotEmpty) 'phone': recipient,
          if (text.isNotEmpty) 'text': text,
        });
        await _launchUri(uri);
        break;
      case 'telegram':
        final uri = Uri.parse('tg://msg').replace(queryParameters: {
          if (recipient.isNotEmpty) 'to': recipient,
          if (text.isNotEmpty) 'text': text,
        });
        await _launchUri(uri);
        break;
      case 'sms':
      default:
        final uri = Uri.parse('sms:$recipient').replace(queryParameters: {
          if (text.isNotEmpty) 'body': text,
        });
        await _launchUri(uri);
        break;
    }
  }

  Future<void> _handleCall(Map<String, dynamic> payload) async {
    final recipient = payload['recipient']?.toString() ?? '';
    if (recipient.isEmpty) return;
    final uri = Uri.parse('tel:$recipient');
    await _launchUri(uri);
  }

  Future<void> _handleOpenApp(Map<String, dynamic> payload) async {
    final scheme = payload['scheme']?.toString();
    if (scheme == null || scheme.isEmpty) {
      await _showPayloadNotification(
        title: 'باز کردن اپ',
        body: 'شناسه اپ مشخص نیست',
      );
      return;
    }
    await _launchUri(Uri.parse(scheme));
  }

  Future<void> _handleOpenLink(Map<String, dynamic> payload) async {
    final link = payload['url']?.toString() ??
        payload['query']?.toString() ??
        payload['text']?.toString();
    if (link == null || link.isEmpty) return;
    final uri = link.startsWith('http')
        ? Uri.parse(link)
        : Uri.parse('https://www.google.com/search?q=$link');
    await _launchUri(uri);
  }

  Future<void> _handleCalendarEvent(Map<String, dynamic> payload) async {
    final title = payload['title']?.toString() ?? 'رویداد';
    final start = _parseDate(payload['start']?.toString());
    final end = _parseDate(payload['end']?.toString());
    final location = payload['location']?.toString() ?? '';
    final params = {
      'action': 'TEMPLATE',
      'text': title,
      if (start != null) 'dates': _googleDateRange(start, end),
      if (location.isNotEmpty) 'location': location,
    };
    final uri = Uri.https('calendar.google.com', '/calendar/render', params);
    await _launchUri(uri);
  }

  Future<void> _handleNote(Map<String, dynamic> payload) async {
    final title = payload['title']?.toString() ?? 'یادداشت';
    final body = payload['content']?.toString() ??
        payload['text']?.toString() ??
        payload['details']?.toString() ??
        'یادداشت ذخیره شد';
    await _notifications.showLocalNow(
      title: title,
      body: body,
      payload: jsonEncode(payload),
    );
  }

  Future<void> _handleMemoryUpsert(Map<String, dynamic> payload) async {
    try {
      final factsRaw = payload['facts'] ??
          payload['fact'] ??
          payload['items'] ??
          payload['text'];
      List<String> facts = <String>[];
      if (factsRaw is List) {
        facts = factsRaw.map((e) => e.toString()).toList();
      } else if (factsRaw != null) {
        facts = <String>[factsRaw.toString()];
      }
      if (facts.isEmpty) {
        await _showPayloadNotification(
          title: 'حافظه',
          body: 'موردی برای ذخیره ارسال نشد',
        );
        return;
      }
      final key = payload['key']?.toString() ??
          payload['topic']?.toString() ??
          'general';
      await _assistant.memoryUpsert(
        MemoryUpsertRequest(facts: facts, key: key),
      );
      await _showPayloadNotification(
        title: 'حافظه',
        body: 'ذخیره شد: ${facts.length} مورد',
      );
    } catch (e) {
      await _showPayloadNotification(
        title: 'حافظه',
        body: 'خطا: $e',
      );
    }
  }

  Future<void> _handleRoutine(Map<String, dynamic> payload) async {
    final title =
        payload['title']?.toString() ?? payload['name']?.toString() ?? 'روتین';
    final whenIso = payload['run_at']?.toString() ??
        payload['datetime']?.toString() ??
        payload['time']?.toString();
    final when = _parseDate(whenIso);
    final body = payload['description']?.toString() ??
        payload['action']?.toString() ??
        'اجرا شود';
    if (when != null && when.isAfter(DateTime.now())) {
      await _notifications.scheduleLocalNotification(
        title: title,
        body: body,
        scheduledAt: when,
        payload: jsonEncode(payload),
      );
      await WorkmanagerService.scheduleReminder(
        title: title,
        body: body,
        at: when,
        payload: payload,
      );
    } else {
      await _showPayloadNotification(
        title: title,
        body: body,
      );
    }
  }

  Future<void> _showPayloadNotification({
    required String title,
    required String body,
  }) {
    return _notifications.showLocalNow(
      title: title,
      body: body,
      payload: body,
    );
  }

  Future<void> _launchUri(Uri uri) async {
    try {
      final can = await canLaunchUrl(uri);
      if (!can) {
        await _notifications.showLocalNow(
          title: 'خطا در باز کردن',
          body: uri.toString(),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Launch failed: $e');
      await _notifications.showLocalNow(
        title: 'خطا در اکشن',
        body: uri.toString(),
      );
    }
  }

  DateTime? _parseDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  String _googleDateRange(DateTime start, DateTime? end) {
    final s = _formatGoogleDate(start);
    final e = _formatGoogleDate(end ?? start.add(const Duration(hours: 1)));
    return '$s/$e';
  }

  String _formatGoogleDate(DateTime dt) {
    final utc = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}00Z';
  }
}
