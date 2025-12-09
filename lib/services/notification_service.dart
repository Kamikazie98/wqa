import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService() : _messaging = FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  String? _token;
  void Function(String)? _tokenListener;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'waiq_default',
    'Waiq Notifications',
    description: 'General notifications from Waiq',
    importance: Importance.high,
  );

  static bool _localNotificationsInitialized = false;

  String? get token => _token;

  Future<void> init() async {
    await _initLocalNotifications();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );
    await _refreshToken();
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageInteraction);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageInteraction(initialMessage);
    }
  }

  static Future<void> initBackground() async {
    await _initLocalNotifications();
  }

  Future<void> subscribeUserTopic(int userId) {
    return _messaging.subscribeToTopic('user-$userId');
  }

  Future<void> unsubscribeUserTopic(int userId) {
    return _messaging.unsubscribeFromTopic('user-$userId');
  }

  void onTokenRefresh(void Function(String) listener) {
    _tokenListener = listener;
  }

  void _handleTokenRefresh(String newToken) {
    _token = newToken;
    _tokenListener?.call(newToken);
  }

  Future<void> _refreshToken() async {
    _token = await _messaging.getToken();
    if (_token != null) {
      _tokenListener?.call(_token!);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
        'FCM foreground message: ${message.messageId} ${message.notification?.title}');
    unawaited(showRemoteMessage(message));
  }

  void _handleMessageInteraction(RemoteMessage message) {
    debugPrint('Notification opened: ${message.messageId}');
  }

  static Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(settings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
    _localNotificationsInitialized = true;
    _ensureTzInitialized();
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();

    if (title == null && body == null) return;

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: notification?.android?.smallIcon,
    );

    const iosDetails =
        DarwinNotificationDetails(presentAlert: true, presentSound: true);

    final id = notification?.hashCode ??
        message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch;

    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data['deeplink']?.toString() ??
          message.data['url']?.toString(),
    );
  }

  /// Show a local notification immediately (used for intent confirmations).
  Future<void> showLocalNow({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails =
        DarwinNotificationDetails(presentAlert: true, presentSound: true);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  /// Schedule a notification at a specific time (uses device timezone).
  Future<void> scheduleLocalNotification({
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    _ensureTzInitialized();
    final tzDateTime = tz.TZDateTime.from(scheduledAt.toLocal(), tz.local);
    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails =
        DarwinNotificationDetails(presentAlert: true, presentSound: true);
    await _localNotifications.zonedSchedule(
      tzDateTime.millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      tzDateTime,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents
          .dateAndTime, // full date-time; no repetition unless specified elsewhere
    );
  }

  static void _ensureTzInitialized() {
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
      _tzInitialized = true;
    }
  }

  static bool _tzInitialized = false;
  static const _androidChannelId = 'waiq_default';
  static const _androidChannelName = 'Waiq Notifications';
  static const _androidChannelDescription = 'General notifications from Waiq';
}
