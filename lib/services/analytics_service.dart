import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Analytics service for tracking app usage and productivity
class AnalyticsService {
  AnalyticsService({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _analyticsPrefix = 'analytics.';
  static const _actionsCountKey = '${_analyticsPrefix}actions_count';
  static const _actionsByTypeKey = '${_analyticsPrefix}actions_by_type';
  static const _dailyUsageKey = '${_analyticsPrefix}daily_usage';
  static const _aiAccuracyKey = '${_analyticsPrefix}ai_accuracy';

  /// Track an action execution
  Future<void> trackAction({
    required String actionType,
    required bool success,
    Map<String, dynamic>? metadata,
  }) async {
    // Increment total count
    final totalCount = _prefs.getInt(_actionsCountKey) ?? 0;
    await _prefs.setInt(_actionsCountKey, totalCount + 1);

    // Track by type
    final byType = _getActionsByType();
    byType[actionType] = (byType[actionType] ?? 0) + 1;
    await _prefs.setString(_actionsByTypeKey, jsonEncode(byType));

    // Track daily usage
    await _trackDailyUsage(actionType, success);

    // Update AI accuracy if applicable
    if (metadata != null && metadata.containsKey('confidence')) {
      await _trackAIAccuracy(
        confidence: metadata['confidence'] as double,
        success: success,
      );
    }
  }

  /// Get total actions count
  int getTotalActionsCount() {
    return _prefs.getInt(_actionsCountKey) ?? 0;
  }

  /// Get actions breakdown by type
  Map<String, int> getActionsByType() {
    return _getActionsByType();
  }

  Map<String, int> _getActionsByType() {
    final raw = _prefs.getString(_actionsByTypeKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  /// Track daily usage
  Future<void> _trackDailyUsage(String actionType, bool success) async {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final dailyUsage = _getDailyUsage();

    if (!dailyUsage.containsKey(dateKey)) {
      dailyUsage[dateKey] = {
        'date': dateKey,
        'total': 0,
        'successful': 0,
        'actions': <String, int>{},
      };
    }

    final dayData = dailyUsage[dateKey]!;
    dayData['total'] = (dayData['total'] as int) + 1;

    if (success) {
      dayData['successful'] = (dayData['successful'] as int) + 1;
    }

    final actions = dayData['actions'] as Map<String, int>;
    actions[actionType] = (actions[actionType] ?? 0) + 1;

    // Keep only last 30 days
    if (dailyUsage.length > 30) {
      final sortedKeys = dailyUsage.keys.toList()..sort();
      for (var i = 0; i < dailyUsage.length - 30; i++) {
        dailyUsage.remove(sortedKeys[i]);
      }
    }

    await _prefs.setString(_dailyUsageKey, jsonEncode(dailyUsage));
  }

  /// Get daily usage data
  Map<String, Map<String, dynamic>> _getDailyUsage() {
    final raw = _prefs.getString(_dailyUsageKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  /// Get usage data for last N days
  List<Map<String, dynamic>> getUsageForLastNDays(int days) {
    final dailyUsage = _getDailyUsage();
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    for (var i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      if (dailyUsage.containsKey(dateKey)) {
        result.add(dailyUsage[dateKey]!);
      } else {
        result.add({
          'date': dateKey,
          'total': 0,
          'successful': 0,
          'actions': <String, int>{},
        });
      }
    }

    return result;
  }

  /// Calculate productivity score (0-100)
  int calculateProductivityScore() {
    final last7Days = getUsageForLastNDays(7);

    if (last7Days.isEmpty) return 0;

    var totalActions = 0;
    var successfulActions = 0;

    for (final day in last7Days) {
      totalActions += day['total'] as int;
      successfulActions += day['successful'] as int;
    }

    if (totalActions == 0) return 0;

    // Base score on success rate
    final successRate = successfulActions / totalActions;
    var score = successRate * 50; // Max 50 points for success rate

    // Add points for consistent usage
    final daysUsed = last7Days.where((d) => (d['total'] as int) > 0).length;
    score += (daysUsed / 7) * 30; // Max 30 points for consistency

    // Add points for volume (capped at 20 actions per day)
    final avgActionsPerDay = totalActions / 7;
    score +=
        (avgActionsPerDay / 20).clamp(0, 1) * 20; // Max 20 points for volume

    return score.round().clamp(0, 100);
  }

  /// Track AI accuracy
  Future<void> _trackAIAccuracy({
    required double confidence,
    required bool success,
  }) async {
    final accuracyData = _getAIAccuracyData();

    accuracyData.add({
      'confidence': confidence,
      'success': success,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Keep only last 100 entries
    if (accuracyData.length > 100) {
      accuracyData.removeAt(0);
    }

    await _prefs.setString(_aiAccuracyKey, jsonEncode(accuracyData));
  }

  List<Map<String, dynamic>> _getAIAccuracyData() {
    final raw = _prefs.getString(_aiAccuracyKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get AI accuracy statistics
  Map<String, dynamic> getAIAccuracyStats() {
    final data = _getAIAccuracyData();

    if (data.isEmpty) {
      return {
        'total_predictions': 0,
        'successful': 0,
        'accuracy_rate': 0.0,
        'avg_confidence': 0.0,
      };
    }

    final successful = data.where((d) => d['success'] == true).length;
    final totalConfidence = data.fold<double>(
      0,
      (sum, d) => sum + (d['confidence'] as double),
    );

    return {
      'total_predictions': data.length,
      'successful': successful,
      'accuracy_rate': successful / data.length,
      'avg_confidence': totalConfidence / data.length,
    };
  }

  /// Get insights and recommendations
  List<String> getInsights() {
    final insights = <String>[];
    final productivityScore = calculateProductivityScore();
    final last7Days = getUsageForLastNDays(7);
    final actionsByType = getActionsByType();

    // Productivity insights
    if (productivityScore >= 80) {
      insights.add('عملکرد شما در هفته گذشته عالی بوده! 🎉');
    } else if (productivityScore >= 60) {
      insights.add('عملکرد خوبی دارید، اما می‌توانید بهتر شوید! 💪');
    } else if (productivityScore >= 40) {
      insights.add('سعی کنید از ابزارهای اتوماسیون بیشتر استفاده کنید.');
    } else {
      insights.add('شروع کنید! حتی اقدامات کوچک هم مهم هستند.');
    }

    // Usage pattern insights
    final daysUsed = last7Days.where((d) => (d['total'] as int) > 0).length;
    if (daysUsed < 3) {
      insights.add('استفاده روزانه شما کم است. استفاده منظم نتایج بهتری دارد.');
    } else if (daysUsed >= 6) {
      insights.add('شما کاربر فعالی هستید! عادت خوبی دارید. ✨');
    }

    // Action type insights
    if (actionsByType.isNotEmpty) {
      final mostUsedAction =
          actionsByType.entries.reduce((a, b) => a.value > b.value ? a : b);
      insights.add(
          'بیشترین استفاده شما از: ${_translateActionType(mostUsedAction.key)}');
    }

    // AI accuracy insights
    final aiStats = getAIAccuracyStats();
    final accuracyRate = aiStats['accuracy_rate'] as double;
    if (accuracyRate >= 0.8) {
      insights.add('هوش مصنوعی با دقت بالا به شما کمک می‌کند! 🤖');
    }

    return insights;
  }

  String _translateActionType(String type) {
    const translations = {
      'reminder': 'یادآوری',
      'calendar_event': 'رویداد تقویم',
      'web_search': 'جستجوی وب',
      'call': 'تماس',
      'message': 'پیام',
      'note': 'یادداشت',
      'suggestion': 'پیشنهاد',
    };

    return translations[type] ?? type;
  }

  /// Export analytics data
  String exportData() {
    return jsonEncode({
      'total_actions': getTotalActionsCount(),
      'actions_by_type': getActionsByType(),
      'daily_usage': _getDailyUsage(),
      'productivity_score': calculateProductivityScore(),
      'ai_accuracy': getAIAccuracyStats(),
      'exported_at': DateTime.now().toIso8601String(),
    });
  }

  /// Clear all analytics data
  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_analyticsPrefix));

    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
