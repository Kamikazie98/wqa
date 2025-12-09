import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class NativeBridge {
  const NativeBridge._();

  static const _channel = MethodChannel('native/automation');

  static Future<List<Map<String, dynamic>>> getBusyEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!Platform.isAndroid) return <Map<String, dynamic>>[];
    final formatter = (DateTime dt) => dt.toIso8601String().split('.').first;
    final result = await _channel.invokeMethod<List<dynamic>>(
      'getBusyEvents',
      {
        'start': formatter(start),
        'end': formatter(end),
      },
    );
    if (result == null) return <Map<String, dynamic>>[];
    return result
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<String> getWifiSsid() async {
    if (!Platform.isAndroid) return '';
    final result = await _channel.invokeMethod<String>('getWifiSsid');
    return result ?? '';
  }

  static Future<void> startSenseService() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('startSenseService');
  }

  static Future<void> stopSenseService() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('stopSenseService');
  }

  static Future<List<Map<String, dynamic>>> getUsageStats() async {
    if (!Platform.isAndroid) return <Map<String, dynamic>>[];
    final result = await _channel.invokeMethod<List<dynamic>>('getUsageStats');
    if (result == null) return <Map<String, dynamic>>[];
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> cacheUsageStats() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('cacheUsageStats');
  }

  static Future<bool> isNotificationListenerEnabled() async {
    if (!Platform.isAndroid) return true;
    final result =
        await _channel.invokeMethod<bool>('isNotificationListenerEnabled');
    return result ?? false;
  }
}
