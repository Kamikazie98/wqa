import 'package:flutter/material.dart';

import '../models/assistant_models.dart';

/// Enhanced AI response with confidence scoring
class EnhancedAIResponse {
  EnhancedAIResponse({
    required this.action,
    required this.payload,
    required this.confidence,
    this.confidenceBreakdown,
    this.reasoning,
    this.alternatives,
    this.rawText,
  });

  final SmartAction action;
  final Map<String, dynamic> payload;
  final double confidence; // 0.0 to 1.0
  final Map<String, double>? confidenceBreakdown;
  final String? reasoning;
  final List<Map<String, dynamic>>? alternatives;
  final String? rawText;

  /// Get confidence level as human-readable string
  String get confidenceLevel {
    if (confidence >= 0.9) return 'بسیار بالا';
    if (confidence >= 0.75) return 'بالا';
    if (confidence >= 0.6) return 'متوسط';
    if (confidence >= 0.4) return 'پایین';
    return 'بسیار پایین';
  }

  /// Get confidence color
  Color get confidenceColor {
    if (confidence >= 0.75) return Colors.green;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }

  /// Whether the confidence is high enough to auto-execute
  bool get canAutoExecute => confidence >= 0.85;

  factory EnhancedAIResponse.fromJson(Map<String, dynamic> json) {
    return EnhancedAIResponse(
      action: smartActionFromString(json['action']?.toString() ?? 'suggestion'),
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      confidenceBreakdown: json['confidence_breakdown'] != null
          ? Map<String, double>.from(
              (json['confidence_breakdown'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
      reasoning: json['reasoning']?.toString(),
      alternatives: json['alternatives'] != null
          ? List<Map<String, dynamic>>.from(
              (json['alternatives'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : null,
      rawText: json['raw_text']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': smartActionToString(action),
      'payload': payload,
      'confidence': confidence,
      if (confidenceBreakdown != null)
        'confidence_breakdown': confidenceBreakdown,
      if (reasoning != null) 'reasoning': reasoning,
      if (alternatives != null) 'alternatives': alternatives,
      if (rawText != null) 'raw_text': rawText,
    };
  }
}

/// Service for calculating and managing AI confidence scores
class ConfidenceService {
  /// Calculate confidence score based on multiple factors
  static double calculateConfidence({
    required String userInput,
    required Map<String, dynamic> aiResponse,
    Map<String, dynamic>? context,
  }) {
    double score = 0.5; // Base score

    // Factor 1: Input clarity (25%)
    score += _calculateInputClarity(userInput) * 0.25;

    // Factor 2: Pattern matching confidence (25%)
    score += _calculatePatternMatch(userInput) * 0.25;

    // Factor 3: Context availability (20%)
    score += _calculateContextScore(context) * 0.20;

    // Factor 4: Response completeness (20%)
    score += _calculateResponseCompleteness(aiResponse) * 0.20;

    // Factor 5: Historical accuracy (10%)
    score += _calculateHistoricalAccuracy() * 0.10;

    return score.clamp(0.0, 1.0);
  }

  /// Calculate input clarity score
  static double _calculateInputClarity(String input) {
    double score = 0.0;

    // Length check (not too short, not too long)
    final wordCount = input.split(RegExp(r'\s+')).length;
    if (wordCount >= 3 && wordCount <= 20) {
      score += 0.3;
    } else if (wordCount >= 2 && wordCount <= 30) {
      score += 0.15;
    }

    // Has specific keywords
    final specificKeywords = [
      'یادآوری',
      'remind',
      'جلسه',
      'meeting',
      'زنگ',
      'call',
      'پیام',
      'message',
      'جستجو',
      'search'
    ];

    for (final keyword in specificKeywords) {
      if (input.toLowerCase().contains(keyword)) {
        score += 0.3;
        break;
      }
    }

    // Has time/date information
    final hasTimeInfo =
        RegExp(r'\d{1,2}:\d{2}|\d{1,2}\s*(?:am|pm|صبح|عصر)').hasMatch(input);
    if (hasTimeInfo) score += 0.2;

    // Has question mark or command structure
    if (input.contains('?') || input.contains('؟')) {
      score += 0.1;
    }

    // Clear sentence structure
    if (input.trim().endsWith('.') || input.trim().endsWith('!')) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Calculate pattern matching confidence
  static double _calculatePatternMatch(String input) {
    final patterns = {
      'reminder': RegExp(r'یادآوری|remind|یادم باش'),
      'calendar': RegExp(r'جلسه|meeting|قرار|رویداد|event'),
      'search': RegExp(r'جستجو|search|بگرد|find'),
      'call': RegExp(r'زنگ|call|تماس'),
      'message': RegExp(r'پیام|message|sms|بفرست'),
    };

    for (final pattern in patterns.values) {
      if (pattern.hasMatch(input.toLowerCase())) {
        return 0.9; // High confidence for clear pattern match
      }
    }

    return 0.3; // Low confidence for no clear pattern
  }

  /// Calculate context score
  static double _calculateContextScore(Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) return 0.0;

    double score = 0.0;

    // Has conversation history
    if (context.containsKey('history') &&
        (context['history'] as List?)?.isNotEmpty == true) {
      score += 0.4;
    }

    // Has user preferences
    if (context.containsKey('preferences')) {
      score += 0.3;
    }

    // Has current mode/energy info
    if (context.containsKey('mode') || context.containsKey('energy')) {
      score += 0.2;
    }

    // Has location/wifi context
    if (context.containsKey('wifi') || context.containsKey('location')) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Calculate response completeness
  static double _calculateResponseCompleteness(Map<String, dynamic> response) {
    double score = 0.0;

    // Has action
    if (response.containsKey('action') &&
        response['action']?.toString().isNotEmpty == true) {
      score += 0.3;
    }

    // Has payload with data
    if (response.containsKey('payload') &&
        (response['payload'] as Map?)?.isNotEmpty == true) {
      score += 0.4;
    }

    // Has reasoning
    if (response.containsKey('reasoning') &&
        response['reasoning']?.toString().isNotEmpty == true) {
      score += 0.2;
    }

    // Has alternatives
    if (response.containsKey('alternatives') &&
        (response['alternatives'] as List?)?.isNotEmpty == true) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Calculate historical accuracy (placeholder for future ML)
  static double _calculateHistoricalAccuracy() {
    // This would track user feedback on past suggestions
    // For now, return neutral score
    return 0.5;
  }

  /// Get confidence breakdown by factor
  static Map<String, double> getConfidenceBreakdown({
    required String userInput,
    required Map<String, dynamic> aiResponse,
    Map<String, dynamic>? context,
  }) {
    return {
      'input_clarity': _calculateInputClarity(userInput),
      'pattern_match': _calculatePatternMatch(userInput),
      'context_score': _calculateContextScore(context),
      'response_completeness': _calculateResponseCompleteness(aiResponse),
      'historical_accuracy': _calculateHistoricalAccuracy(),
    };
  }
}
