import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages conversation context and history for improved AI responses
class ConversationMemoryService {
  ConversationMemoryService({required SharedPreferences prefs})
      : _prefs = prefs;

  final SharedPreferences _prefs;

  static const _conversationHistoryKey = 'conversation.history';
  static const _contextKey = 'conversation.context';
  static const _maxHistorySize = 10; // Keep last 10 interactions
  static const _contextExpiryHours = 2; // Context expires after 2 hours

  /// Add a new conversation turn to history
  Future<void> addConversation({
    required String userInput,
    required String aiResponse,
    Map<String, dynamic>? metadata,
  }) async {
    final history = getHistory();

    final conversation = {
      'timestamp': DateTime.now().toIso8601String(),
      'user': userInput,
      'ai': aiResponse,
      'metadata': metadata ?? {},
    };

    history.add(conversation);

    // Keep only last N conversations
    if (history.length > _maxHistorySize) {
      history.removeRange(0, history.length - _maxHistorySize);
    }

    await _prefs.setString(_conversationHistoryKey, jsonEncode(history));
    await _updateContext(userInput, aiResponse);
  }

  /// Get conversation history
  List<Map<String, dynamic>> getHistory() {
    final raw = _prefs.getString(_conversationHistoryKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get recent conversation context (last 3 interactions)
  String getRecentContext({int last = 3}) {
    final history = getHistory();
    if (history.isEmpty) return '';

    final recent = history.length > last
        ? history.sublist(history.length - last)
        : history;

    final buffer = StringBuffer();
    for (final conv in recent) {
      buffer.writeln('User: ${conv['user']}');
      buffer.writeln('AI: ${conv['ai']}');
      buffer.writeln('---');
    }

    return buffer.toString();
  }

  /// Update semantic context based on conversations
  Future<void> _updateContext(String userInput, String aiResponse) async {
    final context = getCurrentContext();
    final now = DateTime.now();

    // Extract important entities and topics
    final entities = _extractEntities(userInput);
    final topics = _extractTopics(userInput, aiResponse);

    // Update context with new information
    context['last_updated'] = now.toIso8601String();
    context['entities'] = entities;
    context['topics'] = topics;

    // Track user preferences
    if (!context.containsKey('preferences')) {
      context['preferences'] = <String, dynamic>{};
    }

    _updatePreferences(
        context['preferences'] as Map<String, dynamic>, userInput);

    await _prefs.setString(_contextKey, jsonEncode(context));
  }

  /// Get current semantic context
  Map<String, dynamic> getCurrentContext() {
    final raw = _prefs.getString(_contextKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final context = jsonDecode(raw) as Map<String, dynamic>;

      // Check if context has expired
      final lastUpdated =
          DateTime.tryParse(context['last_updated']?.toString() ?? '');
      if (lastUpdated != null) {
        final age = DateTime.now().difference(lastUpdated);
        if (age.inHours > _contextExpiryHours) {
          // Context expired, return fresh context
          return {};
        }
      }

      return context;
    } catch (_) {
      return {};
    }
  }

  /// Extract named entities from text
  Map<String, List<String>> _extractEntities(String text) {
    final entities = <String, List<String>>{
      'times': [],
      'dates': [],
      'locations': [],
      'people': [],
      'numbers': [],
    };

    // Extract times (e.g., "3pm", "14:00", "3 o'clock")
    final timePattern =
        RegExp(r'\d{1,2}(?::\d{2})?\s*(?:am|pm|صبح|عصر|ظهر|شب)?');
    entities['times'] = timePattern
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();

    // Extract dates
    final datePattern = RegExp(
        r'\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?|فردا|امروز|دیروز|tomorrow|today|yesterday');
    entities['dates'] = datePattern
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();

    // Extract numbers
    final numberPattern = RegExp(r'\d+(?:\.\d+)?');
    entities['numbers'] =
        numberPattern.allMatches(text).map((m) => m.group(0)!).toList();

    return entities;
  }

  /// Extract topics/keywords from conversation
  List<String> _extractTopics(String userInput, String aiResponse) {
    final topics = <String>{};

    // Common important keywords
    final keywords = [
      'meeting',
      'جلسه',
      'call',
      'تماس',
      'reminder',
      'یادآوری',
      'task',
      'وظیفه',
      'project',
      'پروژه',
      'work',
      'کار',
      'home',
      'خانه',
      'schedule',
      'برنامه',
      'event',
      'رویداد'
    ];

    final combinedText = '$userInput $aiResponse'.toLowerCase();

    for (final keyword in keywords) {
      if (combinedText.contains(keyword)) {
        topics.add(keyword);
      }
    }

    return topics.toList();
  }

  /// Update user preferences based on patterns
  void _updatePreferences(Map<String, dynamic> preferences, String userInput) {
    final lower = userInput.toLowerCase();

    // Track language preference
    final persianChars =
        RegExp(r'[\u0600-\u06FF]').allMatches(userInput).length;
    final englishChars = RegExp(r'[a-zA-Z]').allMatches(userInput).length;

    if (persianChars > englishChars) {
      preferences['preferred_language'] = 'fa';
    } else if (englishChars > persianChars) {
      preferences['preferred_language'] = 'en';
    }

    // Track communication style
    if (lower.contains('please') ||
        lower.contains('لطفا') ||
        lower.contains('خواهش')) {
      preferences['communication_style'] = 'formal';
    } else if (lower.length < 20 && !lower.contains('?')) {
      preferences['communication_style'] = 'casual';
    }

    // Track time preferences
    final hour = DateTime.now().hour;
    if (!preferences.containsKey('active_hours')) {
      preferences['active_hours'] = <int>[];
    }

    final activeHours = List<int>.from(preferences['active_hours'] as List);
    if (!activeHours.contains(hour)) {
      activeHours.add(hour);
      // Keep only last 20 active hours
      if (activeHours.length > 20) {
        activeHours.removeAt(0);
      }
      preferences['active_hours'] = activeHours;
    }
  }

  /// Get context-aware prompt enhancement
  String enhancePrompt(String userInput) {
    final context = getCurrentContext();
    final recentContext = getRecentContext(last: 2);

    if (context.isEmpty && recentContext.isEmpty) {
      return userInput;
    }

    final buffer = StringBuffer();

    // Add recent conversation context
    if (recentContext.isNotEmpty) {
      buffer.writeln('Recent conversation:');
      buffer.writeln(recentContext);
      buffer.writeln();
    }

    // Add semantic context
    if (context.containsKey('topics') &&
        (context['topics'] as List).isNotEmpty) {
      buffer
          .writeln('Current topics: ${(context['topics'] as List).join(', ')}');
    }

    // Add user preferences
    if (context.containsKey('preferences')) {
      final prefs = context['preferences'] as Map<String, dynamic>;
      if (prefs.containsKey('preferred_language')) {
        buffer.writeln('User prefers ${prefs['preferred_language']} language');
      }
      if (prefs.containsKey('communication_style')) {
        buffer.writeln('Communication style: ${prefs['communication_style']}');
      }
    }

    buffer.writeln();
    buffer.writeln('Current request: $userInput');

    return buffer.toString();
  }

  /// Clear conversation history
  Future<void> clearHistory() async {
    await _prefs.remove(_conversationHistoryKey);
    await _prefs.remove(_contextKey);
  }

  /// Get conversation statistics
  Map<String, dynamic> getStatistics() {
    final history = getHistory();
    final context = getCurrentContext();

    return {
      'total_conversations': history.length,
      'context_age_minutes': _getContextAge(),
      'topics_tracked': (context['topics'] as List?)?.length ?? 0,
      'has_preferences': context.containsKey('preferences'),
      'preferred_language':
          (context['preferences'] as Map?)?['preferred_language'],
    };
  }

  int _getContextAge() {
    final context = getCurrentContext();
    final lastUpdated =
        DateTime.tryParse(context['last_updated']?.toString() ?? '');

    if (lastUpdated == null) return 0;

    return DateTime.now().difference(lastUpdated).inMinutes;
  }

  /// Export conversation history for analysis
  String exportHistory() {
    final history = getHistory();
    return jsonEncode(history);
  }

  /// Import conversation history
  Future<void> importHistory(String jsonHistory) async {
    try {
      final decoded = jsonDecode(jsonHistory) as List<dynamic>;
      final history =
          decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await _prefs.setString(_conversationHistoryKey, jsonEncode(history));
    } catch (_) {
      // Invalid format, ignore
    }
  }
}
