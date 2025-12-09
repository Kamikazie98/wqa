import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/message_models.dart';
import 'api_client.dart';

/// خدمات تحلیل پیام‌ها با استفاده از Chat API
class ChatAnalysisService extends ChangeNotifier {
  final ApiClient apiClient;

  ChatAnalysisService({required this.apiClient});

  /// تحلیل پیام با استفاده از Chat API
  Future<Map<String, dynamic>> analyzeMessage(Message message) async {
    try {
      final prompt = _buildAnalysisPrompt(message);
      final response = await _sendChatRequest(prompt);
      return _parseAnalysisResponse(response, message);
    } catch (e) {
      print('Error analyzing message: $e');
      return _getDefaultAnalysis(message);
    }
  }

  /// استخراج نکات مهم از پیام
  Future<List<String>> extractKeyPoints(Message message) async {
    try {
      final prompt = '''
از متن زیر، نکات مهم و کلیدی را استخراج کن:
"${message.body}"

تعداد نکات: حداکثر 5 نکته
زبان: فارسی
فرمت: هر نکته در یک سطر، با شروع از "-"
      ''';

      final response = await _sendChatRequest(prompt);
      return _parseKeyPoints(response);
    } catch (e) {
      print('Error extracting key points: $e');
      return _getDefaultKeyPoints(message);
    }
  }

  /// تشخیص اولویت پیام
  Future<MessagePriority> detectPriority(Message message) async {
    try {
      final prompt = '''
اولویت این پیام را تشخیص بده:
"${message.body}"

بر اساس معیارهای زیر:
- فوری: کلمات مانند "فوری"، "الان"، "سریع"، "فوری"
- عادی: پیام‌های معمول و روزمره
- کم‌اهمیت: اطلاعات عمومی یا غیرضروری

فقط یک واژه پاسخ دهید: "فوری" یا "عادی" یا "کم_اهمیت"
      ''';

      final response = await _sendChatRequest(prompt);
      return _parsePriority(response);
    } catch (e) {
      print('Error detecting priority: $e');
      return _getDefaultPriority(message);
    }
  }

  /// خلاصه‌سازی پیام
  Future<String> getSummary(Message message) async {
    try {
      final prompt = '''
خلاصه‌ای کوتاه (یک جمله) از متن زیر بنویس:
"${message.body}"

خلاصه باید:
- کوتاه و مختصر باشد
- اطلاعات مهم را شامل شود
- در زبان فارسی باشد
      ''';

      final response = await _sendChatRequest(prompt);
      return response.trim();
    } catch (e) {
      print('Error generating summary: $e');
      return _getDefaultSummary(message);
    }
  }

  /// تشخیص اینکه آیا پاسخ لازم است
  Future<bool> needsReply(Message message) async {
    try {
      final prompt = '''
آیا این پیام نیاز به پاسخ دارد؟
"${message.body}"

معیارها:
- سؤال: بله
- درخواست: بله
- اطلاعات: نه
- تشریح: نه

فقط "بله" یا "نه" پاسخ دهید
      ''';

      final response = await _sendChatRequest(prompt);
      return response.toLowerCase().contains('بله');
    } catch (e) {
      print('Error checking needs reply: $e');
      return _getDefaultNeedsReply(message);
    }
  }

  /// استخراج اطلاعات شخصی
  Future<ExtractedMessageInfo> extractPersonalInfo(Message message) async {
    try {
      final prompt = '''
از متن زیر، اطلاعات شخصی را استخراج کن:
"${message.body}"

استخراج کنید:
1. نام‌ها (اسامی اشخاص)
2. مکان‌ها (شهرها، آدرس‌ها)
3. زمان‌ها (ساعت، تاریخ)
4. شماره‌های تلفن
5. ایمیل‌ها
6. احساسات (خوشحالی، غمگینی، عصبانیت)

فرمت JSON:
{
  "names": [...],
  "locations": [...],
  "times": [...],
  "phones": [...],
  "emails": [...],
  "emotions": [...]
}
      ''';

      final response = await _sendChatRequest(prompt);
      return _parsePersonalInfo(response);
    } catch (e) {
      print('Error extracting personal info: $e');
      return _getDefaultPersonalInfo(message);
    }
  }

  /// ارسال درخواست به Chat API
  Future<String> _sendChatRequest(String prompt) async {
    return _sendChatRequestStreaming(prompt);
  }

  /// ارسال درخواست به Chat API (streaming version)
  Future<String> _sendChatRequestStreaming(String prompt) async {
    try {
      final uri = Uri.parse('https://wqai.morvism.ir/chat/stream');

      final requestBody = {
        'session_id':
            'message_analysis_${DateTime.now().millisecondsSinceEpoch}',
        'web_search': false,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
      };

      final request = http.StreamedRequest('POST', uri)
        ..headers.addAll({
          'Authorization': 'Bearer ${apiClient.tokenProvider()}',
          'Content-Type': 'application/json',
        });

      request.sink.add(utf8.encode(jsonEncode(requestBody)));
      await request.sink.close();

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        throw Exception('API error: ${streamedResponse.statusCode}');
      }

      String fullResponse = '';

      await streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
        if (line.startsWith('data: ')) {
          try {
            final json = jsonDecode(line.substring(6));
            if (json['text'] != null) {
              fullResponse += json['text'];
            }
          } catch (e) {
            // Ignore JSON parsing errors for SSE lines
          }
        }
      });

      return fullResponse;
    } catch (e) {
      print('Error in chat request streaming: $e');
      rethrow;
    }
  }

  /// بناء prompt برای تحلیل کامل پیام
  String _buildAnalysisPrompt(Message message) {
    return '''
لطفاً این پیام را تحلیل کن و اطلاعات زیر را تولید کن:

متن پیام:
"${message.body}"

مورد نیاز:
1. اولویت (فوری/عادی/کم_اهمیت)
2. خلاصه (یک جمله)
3. آیا نیاز به پاسخ دارد (بله/نه)
4. نکات مهم (حداکثر 3 نکته)
5. اعمال پیشنهادی (مثال: reply, save, remind)

فرمت JSON:
{
  "priority": "...",
  "summary": "...",
  "needsReply": true/false,
  "keyPoints": [...],
  "suggestedActions": [...]
}
    ''';
  }

  /// تحلیل پاسخ تحلیل
  Map<String, dynamic> _parseAnalysisResponse(
      String response, Message message) {
    try {
      // تلاش برای استخراج JSON از response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!);
        return {
          'priority': _parsePriorityFromString(json['priority'] ?? ''),
          'summary': json['summary'] ?? _getDefaultSummary(message),
          'needsReply': json['needsReply'] ?? _getDefaultNeedsReply(message),
          'keyPoints': (json['keyPoints'] is List)
              ? List<String>.from(json['keyPoints'])
              : _getDefaultKeyPoints(message),
          'suggestedActions': (json['suggestedActions'] is List)
              ? List<String>.from(json['suggestedActions'])
              : [],
        };
      }
    } catch (e) {
      print('Error parsing analysis response: $e');
    }

    return {
      'priority': _getDefaultPriority(message),
      'summary': _getDefaultSummary(message),
      'needsReply': _getDefaultNeedsReply(message),
      'keyPoints': _getDefaultKeyPoints(message),
      'suggestedActions': [],
    };
  }

  /// تحلیل نکات کلیدی از response
  List<String> _parseKeyPoints(String response) {
    try {
      final lines = response.split('\n');
      return lines
          .where((line) => line.startsWith('-') || line.startsWith('•'))
          .map((line) => line.replaceFirst(RegExp(r'^[\-•]\s*'), '').trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// تحلیل اولویت از response
  MessagePriority _parsePriority(String response) {
    final normalized = response.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    if (normalized.contains('فوری')) {
      return MessagePriority.high;
    } else if (normalized.contains('کماهمیت') ||
        normalized.contains('کم_اهمیت')) {
      return MessagePriority.low;
    } else {
      return MessagePriority.medium;
    }
  }

  /// تحویل اولویت از string
  MessagePriority _parsePriorityFromString(String priority) {
    if (priority.contains('فوری')) {
      return MessagePriority.high;
    } else if (priority.contains('کم') || priority.contains('low')) {
      return MessagePriority.low;
    } else {
      return MessagePriority.medium;
    }
  }

  /// تحلیل اطلاعات شخصی
  ExtractedMessageInfo _parsePersonalInfo(String response) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!);
        return ExtractedMessageInfo(
          names:
              (json['names'] is List) ? List<String>.from(json['names']) : [],
          locations: (json['locations'] is List)
              ? List<String>.from(json['locations'])
              : [],
          dates:
              (json['dates'] is List) ? List<String>.from(json['dates']) : [],
          times:
              (json['times'] is List) ? List<String>.from(json['times']) : [],
          phoneNumbers:
              (json['phones'] is List) ? List<String>.from(json['phones']) : [],
          emails:
              (json['emails'] is List) ? List<String>.from(json['emails']) : [],
          emotions: (json['emotions'] is List)
              ? List<String>.from(json['emotions'])
              : [],
        );
      }
    } catch (e) {
      print('Error parsing personal info: $e');
    }

    return ExtractedMessageInfo();
  }

  // --- Fallback Methods ---

  MessagePriority _getDefaultPriority(Message message) {
    final body = message.body.toLowerCase();
    if (body.contains('فوری') ||
        body.contains('urgent') ||
        body.contains('الان')) {
      return MessagePriority.high;
    }
    return MessagePriority.medium;
  }

  String _getDefaultSummary(Message message) {
    if (message.body.length > 100) {
      return '${message.body.substring(0, 100)}...';
    }
    return message.body;
  }

  bool _getDefaultNeedsReply(Message message) {
    final body = message.body.toLowerCase();
    return body.contains('?') ||
        body.contains('؟') ||
        body.contains('لطفا') ||
        body.contains('please');
  }

  List<String> _getDefaultKeyPoints(Message message) {
    final words = message.body.split(' ');
    return words.where((w) => w.length > 3).take(3).toList();
  }

  ExtractedMessageInfo _getDefaultPersonalInfo(Message message) {
    return ExtractedMessageInfo(
      names: [],
      locations: [],
      dates: [],
      times: [],
      phoneNumbers: [],
      emails: [],
      emotions: [],
    );
  }

  Map<String, dynamic> _getDefaultAnalysis(Message message) {
    return {
      'priority': _getDefaultPriority(message),
      'summary': _getDefaultSummary(message),
      'needsReply': _getDefaultNeedsReply(message),
      'keyPoints': _getDefaultKeyPoints(message),
      'suggestedActions': [],
    };
  }
}
