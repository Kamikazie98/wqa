import 'package:rxdart/rxdart.dart';

import 'api_client.dart';

/// AI-Powered Notification and Message Summarizer Service
/// Uses backend AI to intelligently summarize and prioritize notifications and messages
class NotificationSummarizerService {
  final ApiClient apiClient;

  // Stream controllers
  final _summarySubject = BehaviorSubject<NotificationSummary?>();
  final _importantMessagesSubject = BehaviorSubject<List<ImportantMessage>>();
  final _criticalAlertsSubject = BehaviorSubject<List<CriticalAlert>>();
  final _summaryStatsSubject = BehaviorSubject<SummaryStats>();

  NotificationSummarizerService({required this.apiClient});

  // Streams
  Stream<NotificationSummary?> get summaryStream => _summarySubject.stream;
  Stream<List<ImportantMessage>> get importantMessagesStream =>
      _importantMessagesSubject.stream;
  Stream<List<CriticalAlert>> get criticalAlertsStream =>
      _criticalAlertsSubject.stream;
  Stream<SummaryStats> get statsStream => _summaryStatsSubject.stream;

  /// Generate AI summary of all notifications and messages
  Future<NotificationSummary?> generateSummary({
    required List<Map<String, dynamic>> notifications,
    required List<Map<String, dynamic>> messages,
    String? focusArea, // work, personal, health, etc.
    int? hoursBack, // How many hours to look back
  }) async {
    try {
      final body = <String, dynamic>{
        'notifications': notifications,
        'messages': messages,
      };
      if (focusArea != null) body['focus_area'] = focusArea;
      if (hoursBack != null) body['hours_back'] = hoursBack;

      final response = await apiClient.postJson(
        '/notifications/summarize',
        body: body,
      );

      final summary = NotificationSummary.fromJson(response);
      _summarySubject.add(summary);

      // Update stats
      await _updateStats(summary);

      return summary;
    } catch (e) {
      print('Error generating summary: $e');
      return null;
    }
  }

  /// Get today's notification summary
  Future<NotificationSummary?> getTodaySummary() async {
    try {
      final response =
          await apiClient.getJson('/user/notifications/summary/today');

      if (response['summary'] != null) {
        final summary = NotificationSummary.fromJson(response['summary']);
        _summarySubject.add(summary);
        await _updateStats(summary);
        return summary;
      }

      return null;
    } catch (e) {
      print('Error getting today summary: $e');
      // Return empty summary as fallback instead of null
      final emptySummary = NotificationSummary(
        summaryId: 'empty-${DateTime.now().toIso8601String()}',
        totalNotifications: 0,
        readCount: 0,
        unreadCount: 0,
        importantMessages: [],
        criticalAlerts: [],
        actionItems: [],
        aiGeneratedSummary: null,
        sentimentScore: 0.0,
        dominantTopic: '',
        keyPeople: [],
        generatedAt: DateTime.now(),
      );
      return emptySummary;
    }
  }

  /// Get personalized insights from messages
  Future<Map<String, dynamic>> getMessageInsights() async {
    try {
      final response = await apiClient.getJson('/user/messages/insights');

      return {
        'most_contacted': response['most_contacted'],
        'conversation_topics': response['conversation_topics'],
        'sentiment_trend': response['sentiment_trend'],
        'pending_actions': response['pending_actions'],
        'follow_ups_needed': response['follow_ups_needed'],
      };
    } catch (e) {
      print('Error getting message insights: $e');
      return {};
    }
  }

  /// Get action items from messages
  Future<List<ActionItem>> extractActionItems() async {
    try {
      final response = await apiClient.getJson('/user/messages/action-items');

      final items = (response['action_items'] as List<dynamic>?)
              ?.map((a) => ActionItem.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [];

      return items;
    } catch (e) {
      print('Error extracting action items: $e');
      return [];
    }
  }

  /// Mark notification as read/processed by AI
  Future<bool> markNotificationProcessed(String notificationId) async {
    try {
      await apiClient.postJson(
        '/user/notifications/$notificationId/processed',
      );
      return true;
    } catch (e) {
      print('Error marking notification processed: $e');
      return false;
    }
  }

  /// Get notification trends
  Future<NotificationTrends?> getNotificationTrends({int days = 7}) async {
    try {
      final response = await apiClient.getJson(
        '/user/notifications/trends',
        query: {'days': days},
      );

      return NotificationTrends.fromJson(response);
    } catch (e) {
      print('Error getting notification trends: $e');
      return null;
    }
  }

  /// Snooze notifications for a period
  Future<bool> snoozeNotifications({
    required Duration snoozeDuration,
    String? category,
  }) async {
    try {
      await apiClient.postJson('/user/notifications/snooze', body: {
        'snooze_minutes': snoozeDuration.inMinutes,
        'category': category,
      });
      return true;
    } catch (e) {
      print('Error snoozing notifications: $e');
      return false;
    }
  }

  /// Update stats based on summary
  Future<void> _updateStats(NotificationSummary summary) async {
    final stats = SummaryStats(
      totalNotifications: summary.totalNotifications,
      criticalCount: summary.criticalAlerts.length,
      importantCount: summary.importantMessages.length,
      actionItemsCount: summary.actionItems.length,
      sentimentScore: summary.sentimentScore,
      lastUpdated: DateTime.now(),
    );

    _summaryStatsSubject.add(stats);
  }

  /// Get current cached data
  NotificationSummary? get currentSummary => _summarySubject.valueOrNull;
  List<ImportantMessage> get importantMessages =>
      _importantMessagesSubject.valueOrNull ?? [];
  List<CriticalAlert> get criticalAlerts =>
      _criticalAlertsSubject.valueOrNull ?? [];
  SummaryStats get currentStats =>
      _summaryStatsSubject.valueOrNull ?? SummaryStats.empty();

  /// Dispose resources
  Future<void> dispose() async {
    await _summarySubject.close();
    await _importantMessagesSubject.close();
    await _criticalAlertsSubject.close();
    await _summaryStatsSubject.close();
  }
}

/// Overall notification summary
class NotificationSummary {
  final String summaryId;
  final int totalNotifications;
  final int readCount;
  final int unreadCount;
  final List<ImportantMessage> importantMessages;
  final List<CriticalAlert> criticalAlerts;
  final List<ActionItem> actionItems;
  final String? aiGeneratedSummary;
  final double sentimentScore; // -1 to 1 scale
  final String dominantTopic;
  final List<String> keyPeople;
  final DateTime generatedAt;

  NotificationSummary({
    required this.summaryId,
    required this.totalNotifications,
    required this.readCount,
    required this.unreadCount,
    required this.importantMessages,
    required this.criticalAlerts,
    required this.actionItems,
    this.aiGeneratedSummary,
    required this.sentimentScore,
    required this.dominantTopic,
    required this.keyPeople,
    required this.generatedAt,
  });

  factory NotificationSummary.fromJson(Map<String, dynamic> json) {
    return NotificationSummary(
      summaryId: json['summary_id'] ?? '',
      totalNotifications: json['total_notifications'] ?? 0,
      readCount: json['read_count'] ?? 0,
      unreadCount: json['unread_count'] ?? 0,
      importantMessages: (json['important_messages'] as List<dynamic>?)
              ?.map((m) => ImportantMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      criticalAlerts: (json['critical_alerts'] as List<dynamic>?)
              ?.map((a) => CriticalAlert.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      actionItems: (json['action_items'] as List<dynamic>?)
              ?.map((a) => ActionItem.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      aiGeneratedSummary: json['ai_generated_summary'],
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble() ?? 0.0,
      dominantTopic: json['dominant_topic'] ?? '',
      keyPeople: List<String>.from(json['key_people'] ?? []),
      generatedAt: DateTime.parse(json['generated_at']),
    );
  }
}

/// Important message
class ImportantMessage {
  final String messageId;
  final String sender;
  final String subject;
  final String preview;
  final String importance; // critical, high, medium, low
  final List<String> keywords;
  final DateTime receivedAt;

  ImportantMessage({
    required this.messageId,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.importance,
    required this.keywords,
    required this.receivedAt,
  });

  factory ImportantMessage.fromJson(Map<String, dynamic> json) {
    return ImportantMessage(
      messageId: json['message_id'] ?? '',
      sender: json['sender'] ?? '',
      subject: json['subject'] ?? '',
      preview: json['preview'] ?? '',
      importance: json['importance'] ?? 'medium',
      keywords: List<String>.from(json['keywords'] ?? []),
      receivedAt: DateTime.parse(json['received_at']),
    );
  }
}

/// Critical alert
class CriticalAlert {
  final String alertId;
  final String title;
  final String description;
  final String severity; // critical, high, medium
  final String? action;
  final DateTime createdAt;

  CriticalAlert({
    required this.alertId,
    required this.title,
    required this.description,
    required this.severity,
    this.action,
    required this.createdAt,
  });

  factory CriticalAlert.fromJson(Map<String, dynamic> json) {
    return CriticalAlert(
      alertId: json['alert_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      severity: json['severity'] ?? 'high',
      action: json['action'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// Action item extracted from messages
class ActionItem {
  final String itemId;
  final String title;
  final String description;
  final String? dueDate;
  final String? assignee;
  final String priority; // high, medium, low
  final String source; // message_id
  final bool completed;

  ActionItem({
    required this.itemId,
    required this.title,
    required this.description,
    this.dueDate,
    this.assignee,
    required this.priority,
    required this.source,
    required this.completed,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      itemId: json['item_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      dueDate: json['due_date'],
      assignee: json['assignee'],
      priority: json['priority'] ?? 'medium',
      source: json['source'] ?? '',
      completed: json['completed'] ?? false,
    );
  }
}

/// Notification category
class NotificationCategory {
  final String category; // work, personal, social, system, etc.
  final String urgency; // critical, high, medium, low
  final double confidence;
  final String? suggestedAction;

  NotificationCategory({
    required this.category,
    required this.urgency,
    required this.confidence,
    this.suggestedAction,
  });

  factory NotificationCategory.fromJson(Map<String, dynamic> json) {
    return NotificationCategory(
      category: json['category'] ?? 'other',
      urgency: json['urgency'] ?? 'medium',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      suggestedAction: json['suggested_action'],
    );
  }
}

/// Notification trends
class NotificationTrends {
  final int totalNotifications;
  final int averagePerDay;
  final List<String> topSenders;
  final Map<String, int> categoryBreakdown;
  final double averageSentiment;
  final List<String> emergingTopics;

  NotificationTrends({
    required this.totalNotifications,
    required this.averagePerDay,
    required this.topSenders,
    required this.categoryBreakdown,
    required this.averageSentiment,
    required this.emergingTopics,
  });

  factory NotificationTrends.fromJson(Map<String, dynamic> json) {
    return NotificationTrends(
      totalNotifications: json['total_notifications'] ?? 0,
      averagePerDay: json['average_per_day'] ?? 0,
      topSenders: List<String>.from(json['top_senders'] ?? []),
      categoryBreakdown: Map<String, int>.from(
        (json['category_breakdown'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toInt()),
            ) ??
            {},
      ),
      averageSentiment: (json['average_sentiment'] as num?)?.toDouble() ?? 0.0,
      emergingTopics: List<String>.from(json['emerging_topics'] ?? []),
    );
  }
}

/// Summary statistics
class SummaryStats {
  final int totalNotifications;
  final int criticalCount;
  final int importantCount;
  final int actionItemsCount;
  final double sentimentScore;
  final DateTime lastUpdated;

  SummaryStats({
    required this.totalNotifications,
    required this.criticalCount,
    required this.importantCount,
    required this.actionItemsCount,
    required this.sentimentScore,
    required this.lastUpdated,
  });

  factory SummaryStats.empty() {
    return SummaryStats(
      totalNotifications: 0,
      criticalCount: 0,
      importantCount: 0,
      actionItemsCount: 0,
      sentimentScore: 0.0,
      lastUpdated: DateTime.now(),
    );
  }
}
