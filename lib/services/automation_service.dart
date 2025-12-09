import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'workmanager_service.dart';
import 'native_bridge.dart';

/// Manages user automation preferences and schedules WorkManager jobs accordingly.
class AutomationService {
  AutomationService({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _autoNextEnabledKey = 'automation.next.enabled';
  static const _autoModeEnabledKey = 'automation.mode.enabled';
  static const _availableMinutesKey = 'automation.next.minutes';
  static const _energyKey = 'automation.energy';
  static const _modeKey = 'automation.mode';
  static const _modeContextKey = 'automation.mode.context';
  static const _autoWeeklyEnabledKey = 'automation.weekly.enabled';
  static const _weeklyGoalsKey = 'automation.weekly.goals';
  static const _weeklyEventsKey = 'automation.weekly.events';
  static const _autoNotifTriageEnabledKey = 'automation.notif_triage.enabled';
  static const _autoInboxIntelEnabledKey = 'automation.inbox_intel.enabled';
  static const _autoUsageIntelEnabledKey = 'automation.usage_intel.enabled';
  static const _usageIntelPeriodKey = 'automation.usage_intel.period';
  Timer? _sensorTimer;

  bool get autoNextEnabled => _prefs.getBool(_autoNextEnabledKey) ?? false;
  bool get autoModeEnabled => _prefs.getBool(_autoModeEnabledKey) ?? false;
  int get availableMinutes => _prefs.getInt(_availableMinutesKey) ?? 15;
  String get energy => _prefs.getString(_energyKey) ?? 'normal';
  String get mode => _prefs.getString(_modeKey) ?? 'default';
  String get modeContext => _prefs.getString(_modeContextKey) ?? '{}';
  bool get autoWeeklyEnabled => _prefs.getBool(_autoWeeklyEnabledKey) ?? false;
  bool get autoNotifTriageEnabled =>
      _prefs.getBool(_autoNotifTriageEnabledKey) ?? true;
  bool get autoInboxIntelEnabled =>
      _prefs.getBool(_autoInboxIntelEnabledKey) ?? false;
  bool get autoUsageIntelEnabled =>
      _prefs.getBool(_autoUsageIntelEnabledKey) ?? true;
  String get usageIntelPeriod =>
      _prefs.getString(_usageIntelPeriodKey) ?? 'daily';
  List<String> get weeklyGoals =>
      _prefs.getStringList(_weeklyGoalsKey) ?? <String>[];
  List<Map<String, dynamic>> get weeklyEvents {
    final raw = _prefs.getString(_weeklyEventsKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> restore() async {
    if (autoNextEnabled) {
      await WorkmanagerService.scheduleNextAction(
        minutes: availableMinutes,
        energy: energy,
        mode: mode,
      );
    }
    if (autoModeEnabled) {
      await WorkmanagerService.scheduleModeCheck(
        energy: energy,
        mode: mode,
        contextJson: modeContext,
      );
    }
    if (autoWeeklyEnabled) {
      await WorkmanagerService.scheduleWeeklyPlan(
        goals: weeklyGoals,
        hardEvents: weeklyEvents,
      );
    }
    if (autoNotifTriageEnabled) {
      await WorkmanagerService.scheduleNotificationTriage();
    }
    if (autoInboxIntelEnabled) {
      await WorkmanagerService.scheduleInboxIntel();
    }
    if (autoUsageIntelEnabled) {
      await WorkmanagerService.scheduleUsageIntel(period: usageIntelPeriod);
    }
    _startSensorsTicker();
    if (autoModeEnabled || autoNextEnabled) {
      await NativeBridge.startSenseService();
    }
  }

  Future<void> setAutoNextAction({
    required bool enabled,
    int? minutes,
    String? energy,
    String? mode,
  }) async {
    await _prefs.setBool(_autoNextEnabledKey, enabled);
    if (minutes != null) {
      await _prefs.setInt(_availableMinutesKey, minutes);
    }
    if (energy != null) {
      await _prefs.setString(_energyKey, energy);
    }
    if (mode != null) {
      await _prefs.setString(_modeKey, mode);
    }
    if (enabled) {
      await WorkmanagerService.scheduleNextAction(
        minutes: minutes ?? availableMinutes,
        energy: energy ?? this.energy,
        mode: mode ?? this.mode,
      );
    } else {
      await WorkmanagerService.cancelNextAction();
    }
    _startSensorsTicker();
    if (enabled || autoModeEnabled) {
      await NativeBridge.startSenseService();
    } else {
      await NativeBridge.stopSenseService();
    }
  }

  Future<void> setAutoMode({
    required bool enabled,
    String? energy,
    String? mode,
    String? contextJson,
  }) async {
    await _prefs.setBool(_autoModeEnabledKey, enabled);
    if (energy != null) {
      await _prefs.setString(_energyKey, energy);
    }
    if (mode != null) {
      await _prefs.setString(_modeKey, mode);
    }
    if (contextJson != null) {
      // basic validation: ensure valid json map or fallback string.
      try {
        final decoded = jsonDecode(contextJson);
        if (decoded is Map) {
          await _prefs.setString(_modeContextKey, contextJson);
        }
      } catch (_) {
        await _prefs.setString(_modeContextKey, '{}');
      }
    }
    if (enabled) {
      await WorkmanagerService.scheduleModeCheck(
        energy: energy ?? this.energy,
        mode: mode ?? this.mode,
        contextJson: contextJson ?? modeContext,
      );
    } else {
      await WorkmanagerService.cancelModeCheck();
    }
    _startSensorsTicker();
    if (enabled || autoNextEnabled) {
      await NativeBridge.startSenseService();
    } else {
      await NativeBridge.stopSenseService();
    }
  }

  Future<void> setAutoWeekly({
    required bool enabled,
    List<String>? goals,
    List<Map<String, dynamic>>? events,
  }) async {
    await _prefs.setBool(_autoWeeklyEnabledKey, enabled);
    await saveWeeklyData(goals: goals, events: events);
    if (enabled) {
      await WorkmanagerService.scheduleWeeklyPlan(
        goals: goals ?? weeklyGoals,
        hardEvents: events ?? weeklyEvents,
      );
    } else {
      await WorkmanagerService.cancelWeeklyPlan();
    }
  }

  Future<void> saveWeeklyData({
    List<String>? goals,
    List<Map<String, dynamic>>? events,
  }) async {
    if (goals != null) {
      await _prefs.setStringList(_weeklyGoalsKey, goals);
    }
    if (events != null) {
      await _prefs.setString(_weeklyEventsKey, jsonEncode(events));
    }
  }

  Future<void> setAutoNotifTriage({required bool enabled}) async {
    await _prefs.setBool(_autoNotifTriageEnabledKey, enabled);
    if (enabled) {
      await WorkmanagerService.scheduleNotificationTriage();
    } else {
      await WorkmanagerService.cancelNotificationTriage();
    }
  }

  Future<void> setAutoInboxIntel({required bool enabled}) async {
    await _prefs.setBool(_autoInboxIntelEnabledKey, enabled);
    if (enabled) {
      await WorkmanagerService.scheduleInboxIntel();
    } else {
      await WorkmanagerService.cancelInboxIntel();
    }
  }

  Future<void> setAutoUsageIntel({
    required bool enabled,
    String period = 'daily',
  }) async {
    await _prefs.setBool(_autoUsageIntelEnabledKey, enabled);
    await _prefs.setString(_usageIntelPeriodKey, period);
    if (enabled) {
      await WorkmanagerService.scheduleUsageIntel(period: period);
    } else {
      await WorkmanagerService.cancelUsageIntel();
    }
  }

  void dispose() {
    _sensorTimer?.cancel();
  }

  void _startSensorsTicker() {
    _sensorTimer?.cancel();
    // Only poll when any automation is on
    if (!autoModeEnabled && !autoNextEnabled) return;
    _sensorTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      try {
        final ssid = await NativeBridge.getWifiSsid();
        if (ssid.isEmpty) return;
        Map<String, dynamic> ctx = {};
        try {
          final decoded = jsonDecode(modeContext);
          if (decoded is Map<String, dynamic>) {
            ctx = decoded;
          }
        } catch (_) {
          ctx = {};
        }
        if (ctx['wifi'] == ssid) return;
        ctx['wifi'] = ssid;
        await _prefs.setString(_modeContextKey, jsonEncode(ctx));
      } catch (_) {
        // ignore polling errors
      }
    });
  }
}
