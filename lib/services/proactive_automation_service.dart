import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_bridge.dart';

/// Proactive automation that learns user patterns and suggests actions
class ProactiveAutomationService {
  ProactiveAutomationService({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  final SharedPreferences _prefs;
  Timer? _learningTimer;

  static const _patternPrefix = 'pattern.';
  static const _lastWifiKey = 'last_wifi';
  static const _lastModeKey = 'last_mode';

  /// Start learning user patterns
  void startLearning() {
    _learningTimer?.cancel();
    _learningTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _analyzeAndSuggest();
    });
  }

  /// Stop learning
  void stopLearning() {
    _learningTimer?.cancel();
  }

  /// Analyze current context and make proactive suggestions
  Future<void> _analyzeAndSuggest() async {
    try {
      // Get current context
      final wifi = await NativeBridge.getWifiSsid();
      final now = DateTime.now();
      final hour = now.hour;
      final dayOfWeek = now.weekday;

      // Detect patterns
      final pattern = _detectPattern(wifi, hour, dayOfWeek);
      if (pattern != null) {
        // Trigger proactive action based on pattern
        await _executeProactiveAction(pattern);
      }

      // Update last known state
      await _updateLastState(wifi);
    } catch (e) {
      // Silently handle errors
    }
  }

  /// Detect patterns based on historical data
  Map<String, dynamic>? _detectPattern(String wifi, int hour, int dayOfWeek) {
    // Create pattern key: wifi_dayOfWeek_hourRange
    final hourRange = '${(hour ~/ 2) * 2}-${((hour ~/ 2) * 2) + 2}';
    final patternKey = '${_patternPrefix}${wifi}_${dayOfWeek}_$hourRange';

    // Get pattern occurrence count
    final occurrences = _prefs.getInt(patternKey) ?? 0;

    // If pattern occurs frequently (>3 times), consider it established
    if (occurrences > 3) {
      return {
        'wifi': wifi,
        'hour': hour,
        'dayOfWeek': dayOfWeek,
        'occurrences': occurrences,
      };
    }

    // Increment occurrence for future learning
    _prefs.setInt(patternKey, occurrences + 1);

    return null;
  }

  /// Execute proactive automation based on detected pattern
  Future<void> _executeProactiveAction(Map<String, dynamic> pattern) async {
    // Example: If at office wifi on Monday morning, suggest mode switch to 'work'
    final wifi = pattern['wifi'] as String;
    final hour = pattern['hour'] as int;
    final dayOfWeek = pattern['dayOfWeek'] as int;

    String suggestedMode = 'default';

    // Pattern-based mode suggestions
    if (wifi.toLowerCase().contains('office') &&
        dayOfWeek >= 1 &&
        dayOfWeek <= 5 &&
        hour >= 8 &&
        hour <= 18) {
      suggestedMode = 'work';
    } else if (wifi.toLowerCase().contains('home') && (hour < 8 || hour > 20)) {
      suggestedMode = 'home';
    }

    // Only suggest if mode is different from last known
    final lastMode = _prefs.getString(_lastModeKey) ?? 'default';
    if (suggestedMode != lastMode && suggestedMode != 'default') {
      // Send notification or auto-switch mode
      // This would integrate with your notification service
      await _prefs.setString(_lastModeKey, suggestedMode);

      // You can call your mode decision API here
      // await _assistant.decideMode(...);
    }
  }

  /// Update last known state for context tracking
  Future<void> _updateLastState(String wifi) async {
    final lastWifi = _prefs.getString(_lastWifiKey);

    if (lastWifi != wifi) {
      await _prefs.setString(_lastWifiKey, wifi);
      // Location/WiFi changed - could trigger context-aware actions
    }
  }

  /// Get learned patterns summary
  Map<String, int> getLearnedPatterns() {
    final patterns = <String, int>{};
    final keys = _prefs.getKeys().where((k) => k.startsWith(_patternPrefix));

    for (final key in keys) {
      final count = _prefs.getInt(key) ?? 0;
      patterns[key.replaceFirst(_patternPrefix, '')] = count;
    }

    return patterns;
  }

  /// Reset all learned patterns
  Future<void> resetLearning() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_patternPrefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  void dispose() {
    _learningTimer?.cancel();
  }
}
