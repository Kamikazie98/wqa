import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_models.dart';

class MessageReaderService {
  static const _smsChannel = MethodChannel('native/messages');
  static const _messagesKey = 'messages.cache';
  static const _messagesUpdatedKey = 'messages.cache.updated';

  final SharedPreferences _prefs;
  final _messageController = StreamController<Message>.broadcast();

  Timer? _syncTimer;
  final List<String> _processedIds = [];

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
        limit,
      );

      if (result == null) {
        return _getCachedMessages();
      }

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

  /// دریافت تمام پیام‌ها از یک مکالمه
  Future<List<MessageThread>> getMessageThreads({
    int limit = 50,
    MessageChannel? channel,
  }) async {
    try {
      final result = await _smsChannel.invokeMethod<List<dynamic>>(
        'getMessageThreads',
      );

      if (result == null) return [];

      return result
          .map((e) =>
              MessageThread.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      print('Error getting message threads: $e');
      return [];
    }
  }

  /// دریافت پیام‌های یک شماره
  Future<List<Message>> getMessagesFromContact(
    String phoneNumber, {
    int limit = 50,
  }) async {
    try {
      final result = await _smsChannel.invokeMethod<List<dynamic>>(
        'getMessagesFromContact',
        phoneNumber,
      );

      if (result == null) return [];

      return result
          .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      print('Error getting messages from contact: $e');
      return [];
    }
  }

  /// مراقبت پیام‌های جدید
  void startWatching() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final messages = await getPendingMessages();
      for (final msg in messages) {
        if (!msg.isRead && !_processedIds.contains(msg.id)) {
          _processedIds.add(msg.id);
          _messageController.add(msg);
        }
      }
    });
  }

  /// متوقف کردن مراقبت
  void stopWatching() {
    _syncTimer?.cancel();
    _processedIds.clear();
  }

  /// علامت‌گذاری به‌عنوان خوانده‌شده
  Future<void> markAsRead(String messageId) async {
    try {
      await _smsChannel.invokeMethod('markAsRead', messageId);

      // بروز‌رسانی کش
      final cached = _getCachedMessages();
      final updated = cached.map((msg) {
        if (msg.id == messageId) {
          return msg.copyWith(isRead: true);
        }
        return msg;
      }).toList();
      await _cacheMessages(updated);
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// حذف پیام
  Future<void> deleteMessage(String messageId) async {
    try {
      await _smsChannel.invokeMethod('deleteMessage', messageId);

      // بروز‌رسانی کش
      final cached = _getCachedMessages();
      final updated = cached.where((msg) => msg.id != messageId).toList();
      await _cacheMessages(updated);
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  /// ذخیره پیام‌ها در کش
  Future<void> _cacheMessages(List<Message> messages) async {
    try {
      final json = messages.map((e) => jsonEncode(e.toJson())).toList();
      await _prefs.setStringList(_messagesKey, json);
      await _prefs.setString(
        _messagesUpdatedKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('Error caching messages: $e');
    }
  }

  /// بارگذاری پیام‌های کش‌شده
  List<Message> _getCachedMessages() {
    try {
      final raw = _prefs.getStringList(_messagesKey);
      if (raw == null || raw.isEmpty) return [];

      return raw
          .map((e) => Message.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting cached messages: $e');
      return [];
    }
  }

  /// پاک کردن کش
  Future<void> clearCache() async {
    try {
      await _prefs.remove(_messagesKey);
      await _prefs.remove(_messagesUpdatedKey);
      _processedIds.clear();
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// بستن سرویس
  void dispose() {
    stopWatching();
    _messageController.close();
  }
}
