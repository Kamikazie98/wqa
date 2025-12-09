import 'package:fuzzy/fuzzy.dart';

/// Enhanced local NLP processor with semantic understanding and context awareness
class LocalNLPProcessor {
  // Context storage for sequential user inputs
  final List<String> _recentInputs = [];
  final Map<String, dynamic> _userContext = {};
  static const int _maxContextLength = 5;

  /// Classify user intent locally before sending to API
  /// This reduces API calls for common/simple intents
  Map<String, dynamic>? classifyIntentLocally(String text) {
    final normalizedText = text.toLowerCase().trim();

    // Store context for future classification
    _recentInputs.add(normalizedText);
    if (_recentInputs.length > _maxContextLength) {
      _recentInputs.removeAt(0);
    }

    // Reminder patterns with higher accuracy
    if (_isReminderIntent(normalizedText)) {
      return {
        'action': 'reminder',
        'confidence': _calculateConfidence('reminder', normalizedText),
        'payload': _extractReminderDetails(normalizedText),
        'context': _buildClassificationContext(),
      };
    }

    // Calendar/Event patterns
    if (_isCalendarIntent(normalizedText)) {
      return {
        'action': 'calendar_event',
        'confidence': _calculateConfidence('calendar', normalizedText),
        'payload': _extractEventDetails(normalizedText),
        'context': _buildClassificationContext(),
      };
    }

    // Web search patterns
    if (_isSearchIntent(normalizedText)) {
      return {
        'action': 'web_search',
        'confidence': _calculateConfidence('search', normalizedText),
        'payload': {'query': _extractSearchQuery(normalizedText)},
        'context': _buildClassificationContext(),
      };
    }

    // Call patterns
    if (_isCallIntent(normalizedText)) {
      return {
        'action': 'call',
        'confidence': _calculateConfidence('call', normalizedText),
        'payload': _extractCallDetails(normalizedText),
        'context': _buildClassificationContext(),
      };
    }

    // Message patterns
    if (_isMessageIntent(normalizedText)) {
      return {
        'action': 'send_message',
        'confidence': _calculateConfidence('message', normalizedText),
        'payload': _extractMessageDetails(normalizedText),
        'context': _buildClassificationContext(),
      };
    }

    // Mode switch patterns
    if (_isModeSwitch(normalizedText)) {
      return {
        'action': 'mode_switch',
        'confidence': _calculateConfidence('mode', normalizedText),
        'payload': _extractMode(normalizedText),
        'context': _buildClassificationContext(),
      };
    }

    // New: Smart suggestion intent
    if (_isSmartSuggestionIntent(normalizedText)) {
      return {
        'action': 'smart_suggestion',
        'confidence': _calculateConfidence('suggestion', normalizedText),
        'payload': _extractSuggestionContext(normalizedText),
        'context': _buildClassificationContext(),
      };
    }

    // New: Task management intent
    if (_isTaskIntent(normalizedText)) {
      return {
        'action': 'task_management',
        'confidence': _calculateConfidence('task', normalizedText),
        'payload': _extractTaskDetails(normalizedText),
        'context': _buildClassificationContext(),
      };
    }

    // Low confidence - send to API
    return null;
  }

  /// Calculate confidence score based on multiple factors
  double _calculateConfidence(String intentType, String text) {
    double baseConfidence = 0.8;

    // Boost confidence if similar to recent inputs
    if (_recentInputs.length > 1) {
      final similarity = _calculateTextSimilarity(text, _recentInputs.last);
      if (similarity > 0.7) baseConfidence += 0.05;
    }

    // Boost for specific keywords
    if (_hasSpecificKeywords(text, intentType)) {
      baseConfidence += 0.05;
    }

    // Consider context
    if (_userContext.containsKey('last_action') &&
        _userContext['last_action'] == intentType) {
      baseConfidence += 0.05;
    }

    return (baseConfidence * 100).clamp(0.0, 95.0) / 100;
  }

  /// Build context metadata for classification
  Map<String, dynamic> _buildClassificationContext() {
    return {
      'recent_inputs': _recentInputs,
      'user_context': _userContext,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Calculate text similarity using fuzzy matching
  double _calculateTextSimilarity(String text1, String text2) {
    final fuzzy = Fuzzy([text2], options: FuzzyOptions(threshold: 0.0));
    final results = fuzzy.search(text1);
    return results.isNotEmpty ? results.first.score : 0.0;
  }

  /// Check if text has specific keywords for intent type
  bool _hasSpecificKeywords(String text, String intentType) {
    final keywordMap = {
      'reminder': ['یادآوری', 'remind', 'یادم باش', 'notification', 'اعلان'],
      'calendar': ['جلسه', 'meeting', 'event', 'رویداد', 'تقویم'],
      'search': ['جستجو', 'search', 'گوگل', 'بگرد'],
      'call': ['زنگ', 'call', 'تماس', 'phone'],
      'message': ['پیام', 'message', 'sms', 'بفرست'],
      'mode': ['حالت', 'mode', 'switch'],
    };

    final keywords = keywordMap[intentType] ?? [];
    return keywords.any((kw) => text.contains(kw));
  }

  bool _isReminderIntent(String text) {
    final patterns = [
      RegExp(r'یادآوری|remind|یادم باش|یادآور'),
      RegExp(r'به من بگو|notify me|اعلان بده'),
    ];
    return patterns.any((p) => p.hasMatch(text));
  }

  Map<String, dynamic> _extractReminderDetails(String text) {
    // Extract time/date using regex
    final timePatterns = [
      RegExp(r'ساعت (\d{1,2})'),
      RegExp(r'at (\d{1,2})'),
      RegExp(r'(\d{1,2}):\d{2}'),
    ];

    String? time;
    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        time = match.group(1);
        break;
      }
    }

    // Extract the actual reminder content
    final content = text
        .replaceAll(RegExp(r'یادآوری|remind|یادم باش|یادآور'), '')
        .replaceAll(RegExp(r'ساعت \d{1,2}|at \d{1,2}'), '')
        .trim();

    return {
      'time': time,
      'content': content,
      'extracted_locally': true,
    };
  }

  bool _isCalendarIntent(String text) {
    final patterns = [
      RegExp(r'جلسه|meeting|قرار|appointment'),
      RegExp(r'رویداد|event|تقویم|calendar'),
    ];
    return patterns.any((p) => p.hasMatch(text));
  }

  Map<String, dynamic> _extractEventDetails(String text) {
    return {
      'title': text,
      'extracted_locally': true,
    };
  }

  bool _isSearchIntent(String text) {
    final patterns = [
      RegExp(r'^جستجو|^search|^گوگل کن|^google'),
      RegExp(r'بگرد|پیدا کن|find|look for'),
      RegExp(r'چی میدونی درباره|what do you know about'),
    ];
    return patterns.any((p) => p.hasMatch(text));
  }

  String _extractSearchQuery(String text) {
    return text
        .replaceAll(RegExp(r'^جستجو|^search|^گوگل کن|^google'), '')
        .replaceAll(RegExp(r'بگرد|پیدا کن|find|look for'), '')
        .replaceAll(RegExp(r'چی میدونی درباره|what do you know about'), '')
        .trim();
  }

  bool _isCallIntent(String text) {
    final patterns = [
      RegExp(r'زنگ بزن|call|تماس بگیر'),
      RegExp(r'با .* تماس بگیر'),
    ];
    return patterns.any((p) => p.hasMatch(text));
  }

  Map<String, dynamic> _extractCallDetails(String text) {
    final contactPattern =
        RegExp(r'زنگ بزن به (.+)|call (.+)', caseSensitive: false);
    final match = contactPattern.firstMatch(text);

    return {
      'contact': match?.group(1) ?? match?.group(2) ?? text,
      'extracted_locally': true,
    };
  }

  bool _isMessageIntent(String text) {
    final patterns = [
      RegExp(r'پیام بده|send message|sms|بفرست'),
      RegExp(r'به .* بگو'),
    ];
    return patterns.any((p) => p.hasMatch(text));
  }

  Map<String, dynamic> _extractMessageDetails(String text) {
    return {
      'message': text,
      'extracted_locally': true,
    };
  }

  bool _isModeSwitch(String text) {
    final patterns = [
      RegExp(r'حالت|mode|برو به حالت|switch to'),
      RegExp(r'work mode|home mode|focus mode|sleep mode'),
    ];
    return patterns.any((p) => p.hasMatch(text));
  }

  Map<String, dynamic> _extractMode(String text) {
    if (text.contains('work') || text.contains('کار')) {
      return {'mode': 'work'};
    } else if (text.contains('home') || text.contains('خانه')) {
      return {'mode': 'home'};
    } else if (text.contains('focus') || text.contains('تمرکز')) {
      return {'mode': 'focus'};
    } else if (text.contains('sleep') || text.contains('خواب')) {
      return {'mode': 'sleep'};
    }
    return {'mode': 'default'};
  }

  // New: Smart suggestion intent detection
  bool _isSmartSuggestionIntent(String text) {
    final patterns = [
      RegExp(r'چی کار کنم|what should i do|پیشنهاد|suggest'),
      RegExp(r'بهترین کار|بهتر است|should i|می‌تونی کمکم کنی'),
      RegExp(r'راهنمایی کن|guide me|help me decide'),
    ];
    return patterns.any((p) => p.hasMatch(text));
  }

  Map<String, dynamic> _extractSuggestionContext(String text) {
    return {
      'context': text,
      'request_type': _determineSuggestionType(text),
      'extracted_locally': true,
    };
  }

  String _determineSuggestionType(String text) {
    if (text.contains('کار') ||
        text.contains('work') ||
        text.contains('task')) {
      return 'work_related';
    } else if (text.contains('شخصی') ||
        text.contains('personal') ||
        text.contains('خانه')) {
      return 'personal';
    } else if (text.contains('تفریح') ||
        text.contains('fun') ||
        text.contains('entertainment')) {
      return 'entertainment';
    }
    return 'general';
  }

  // New: Task management intent detection
  bool _isTaskIntent(String text) {
    final patterns = [
      RegExp(r'تسک|task|کار|آیتم|item'),
      RegExp(r'انجام دادم|تکمیل کردم|completed|done'),
      RegExp(r'اضافه کن|add|لیست|list'),
      RegExp(r'حذف کن|delete|remove|پاک کن'),
    ];
    return patterns.any((p) => p.hasMatch(text));
  }

  Map<String, dynamic> _extractTaskDetails(String text) {
    final taskAction = _determineTaskAction(text);
    final taskContent = _extractTaskContent(text);

    return {
      'action': taskAction,
      'content': taskContent,
      'priority': _extractTaskPriority(text),
      'extracted_locally': true,
    };
  }

  String _determineTaskAction(String text) {
    if (text.contains('انجام دادم') ||
        text.contains('completed') ||
        text.contains('done')) {
      return 'mark_complete';
    } else if (text.contains('حذف کن') ||
        text.contains('delete') ||
        text.contains('remove')) {
      return 'delete_task';
    } else if (text.contains('اضافه کن') || text.contains('add')) {
      return 'add_task';
    }
    return 'update_task';
  }

  String _extractTaskContent(String text) {
    return text
        .replaceAll(RegExp(r'تسک|task|کار|تکمیل کردم|completed|انجام دادم'), '')
        .replaceAll(RegExp(r'اضافه کن|add|حذف کن|delete|remove'), '')
        .trim();
  }

  String _extractTaskPriority(String text) {
    if (text.contains('فوری') ||
        text.contains('urgent') ||
        text.contains('critical')) {
      return 'high';
    } else if (text.contains('ساده') ||
        text.contains('easy') ||
        text.contains('low')) {
      return 'low';
    }
    return 'medium';
  }

  /// Update user context for better future predictions
  void updateUserContext(Map<String, dynamic> newContext) {
    _userContext.addAll(newContext);
  }

  /// Get user context
  Map<String, dynamic> getUserContext() => Map.from(_userContext);

  /// Reset conversation context
  void resetContext() {
    _recentInputs.clear();
    _userContext.clear();
  }

  /// Extract entities from text (names, dates, times, locations)
  Map<String, List<String>> extractEntities(String text) {
    return {
      'times': _extractTimes(text),
      'dates': _extractDates(text),
      'numbers': _extractNumbers(text),
      'urls': _extractUrls(text),
    };
  }

  List<String> _extractTimes(String text) {
    final pattern = RegExp(r'\d{1,2}:\d{2}|\d{1,2}\s*(?:am|pm|صبح|عصر|شب)');
    return pattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  List<String> _extractDates(String text) {
    final patterns = [
      RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}'),
      RegExp(
          r'\d{1,2}\s+(?:ژانویه|فوریه|مارس|آوریل|مه|ژوئن|ژوئیه|اوت|سپتامبر|اکتبر|نوامبر|دسامبر)'),
    ];

    final dates = <String>[];
    for (final pattern in patterns) {
      dates.addAll(pattern.allMatches(text).map((m) => m.group(0)!));
    }
    return dates;
  }

  List<String> _extractNumbers(String text) {
    final pattern = RegExp(r'\d+(?:\.\d+)?');
    return pattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  List<String> _extractUrls(String text) {
    final pattern = RegExp(
      r'https?://[^\s]+|www\.[^\s]+',
      caseSensitive: false,
    );
    return pattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Sentiment analysis with confidence scoring
  Map<String, dynamic> analyzeSentimentWithContext(String text) {
    final sentiment = analyzeSentiment(text);
    final intensity = _calculateSentimentIntensity(text);
    final emotionKeywords = _extractEmotionKeywords(text);

    return {
      'sentiment': sentiment,
      'intensity': intensity,
      'emotion_keywords': emotionKeywords,
      'confidence': _calculateSentimentConfidence(text, sentiment),
    };
  }

  /// Sentiment analysis (enhanced rule-based)
  String analyzeSentiment(String text) {
    final positiveWords = [
      'خوب',
      'عالی',
      'excellent',
      'amazing',
      'wonderful',
      'fantastic',
      'good',
      'great',
      'happy',
      'خوشحال',
      'دوست دارم',
      'love',
      'beautiful',
      'perfect',
      'amazing',
      'awesome',
      'عالی',
      'بهترین',
      'best',
    ];
    final negativeWords = [
      'بد',
      'ضعیف',
      'bad',
      'poor',
      'terrible',
      'awful',
      'horrible',
      'sad',
      'ناراحت',
      'خسته',
      'angry',
      'hate',
      'dislike',
      'برای من خوب نیس',
      'worst',
      'disgusting',
      'بدترین',
      'frustrating',
      'annoyed',
    ];
    final neutralWords = [
      'okay',
      'fine',
      'medium',
      'average',
      'normal',
      'معمولی',
      'خوب نیست اما بد نیست',
    ];

    final normalizedText = text.toLowerCase();
    var positiveScore = 0;
    var negativeScore = 0;
    var neutralScore = 0;

    for (final word in positiveWords) {
      if (normalizedText.contains(word)) positiveScore++;
    }

    for (final word in negativeWords) {
      if (normalizedText.contains(word)) negativeScore++;
    }

    for (final word in neutralWords) {
      if (normalizedText.contains(word)) neutralScore++;
    }

    // Calculate sentiment with weights
    if (positiveScore > negativeScore && positiveScore > neutralScore) {
      return 'positive';
    } else if (negativeScore > positiveScore && negativeScore > neutralScore) {
      return 'negative';
    } else if (neutralScore > positiveScore && neutralScore > negativeScore) {
      return 'neutral';
    } else if (positiveScore == negativeScore && positiveScore > 0) {
      return 'mixed';
    }
    return 'neutral';
  }

  /// Calculate sentiment intensity (weak, moderate, strong)
  String _calculateSentimentIntensity(String text) {
    final intensifiers = [
      'خیلی',
      'very',
      'extremely',
      'absolutely',
      'definitely',
      'utterly'
    ];
    final weakeners = ['کمی', 'slightly', 'somewhat', 'rather', 'quite'];

    var intensityScore = 0;
    for (final word in intensifiers) {
      if (text.toLowerCase().contains(word)) intensityScore += 2;
    }
    for (final word in weakeners) {
      if (text.toLowerCase().contains(word)) intensityScore -= 1;
    }

    if (intensityScore >= 2) return 'strong';
    if (intensityScore >= 0) return 'moderate';
    return 'weak';
  }

  /// Extract emotion keywords from text
  List<String> _extractEmotionKeywords(String text) {
    final emotionMap = {
      'joy': ['خوشحال', 'happy', 'خندان', 'laugh', 'smile'],
      'sadness': ['ناراحت', 'sad', 'گریه', 'cry', 'upset'],
      'anger': ['عصبانی', 'angry', 'furious', 'خشمگین'],
      'fear': ['ترس', 'afraid', 'scared', 'frightened'],
      'excitement': ['هیجان', 'excited', 'thrilled', 'amazed'],
      'confidence': ['اعتماد', 'confident', 'sure', 'certain'],
    };

    final emotions = <String>[];
    for (final entry in emotionMap.entries) {
      if (entry.value.any((kw) => text.toLowerCase().contains(kw))) {
        emotions.add(entry.key);
      }
    }
    return emotions;
  }

  /// Calculate confidence in sentiment analysis
  double _calculateSentimentConfidence(String text, String sentiment) {
    double confidence = 0.5;

    // Boost confidence if multiple indicators match
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    var matchCount = 0;

    if (sentiment == 'positive') {
      final positiveKeywords = [
        'خوب',
        'عالی',
        'excellent',
        'good',
        'great',
        'happy'
      ];
      matchCount = words
          .where((w) => positiveKeywords.any((kw) => w.contains(kw)))
          .length;
    } else if (sentiment == 'negative') {
      final negativeKeywords = ['بد', 'ضعیف', 'bad', 'poor', 'sad', 'angry'];
      matchCount = words
          .where((w) => negativeKeywords.any((kw) => w.contains(kw)))
          .length;
    }

    confidence += (matchCount * 0.1).clamp(0.0, 0.3);
    return (confidence * 100).clamp(0.0, 95.0) / 100;
  }

  /// Advanced entity extraction with NER
  Map<String, dynamic> extractAdvancedEntities(String text) {
    return {
      'times': _extractTimes(text),
      'dates': _extractDates(text),
      'numbers': _extractNumbers(text),
      'urls': _extractUrls(text),
      'names': _extractProbableNames(text),
      'locations': _extractLocationMentions(text),
      'emotions': _extractEmotionKeywords(text),
    };
  }

  /// Extract probable person names from text
  List<String> _extractProbableNames(String text) {
    // Simple heuristic: capitalized words or Persian names
    final words = text.split(RegExp(r'\s+'));
    return words
        .where((w) =>
            (w.isNotEmpty && w[0].toUpperCase() == w[0] && w.length > 2) ||
            _isPersianName(w))
        .toList();
  }

  /// Check if word is likely a Persian name
  bool _isPersianName(String word) {
    final commonPersianNames = [
      'علی',
      'محمد',
      'فاطمه',
      'زینب',
      'حسن',
      'حسین',
      'مریم',
      'نرگس',
      'بهرام',
      'داریوش',
      'کیارش',
      'شهاب',
      'امیر',
      'سارا',
      'نیلوفر',
    ];
    return commonPersianNames.any((name) => word.contains(name));
  }

  /// Extract location mentions
  List<String> _extractLocationMentions(String text) {
    final locationPatterns = [
      'تهران',
      'tehran',
      'isfahan',
      'اصفهان',
      'shiraz',
      'شیراز',
      'بندرعباس',
      'mashhad',
      'مشهد',
      'tabriz',
      'تبریز',
    ];
    return locationPatterns
        .where((loc) => text.toLowerCase().contains(loc.toLowerCase()))
        .toList();
  }
}
