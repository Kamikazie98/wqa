import '../models/message_models.dart';
import 'local_nlp_processor.dart';

class MessageAnalysisService {
  final LocalNLPProcessor _nlp;

  MessageAnalysisService({
    required LocalNLPProcessor nlp,
  }) : _nlp = nlp;

  /// استخراج نکات مهم
  Future<List<String>> extractKeyPoints(String message) async {
    try {
      // تقسیم جملات
      final sentences = message.split(RegExp(r'[.!?؟]'));

      final keyPoints = <String>[];

      for (final sentence in sentences) {
        if (sentence.trim().isEmpty) continue;

        // استفاده از NLP برای شناسایی کلمات کلیدی
        final entities = _nlp.extractEntities(sentence);

        // افزودن نام‌ها
        if (entities['names'] != null) {
          keyPoints.addAll(
            List<String>.from(entities['names'] ?? []),
          );
        }

        // افزودن تاریخ‌ها
        if (entities['dates'] != null) {
          keyPoints.addAll(
            List<String>.from(entities['dates'] ?? []),
          );
        }

        // افزودن اوقات
        if (entities['times'] != null) {
          keyPoints.addAll(
            List<String>.from(entities['times'] ?? []),
          );
        }

        // افزودن مکان‌ها
        if (entities['locations'] != null) {
          keyPoints.addAll(
            List<String>.from(entities['locations'] ?? []),
          );
        }
      }

      // حذف تکراری‌ها و محدود کردن تعداد
      return keyPoints.toSet().toList().take(10).toList();
    } catch (e) {
      print('Error extracting key points: $e');
      return [];
    }
  }

  /// استخراج اطلاعات شخصی
  Future<ExtractedMessageInfo> extractPersonalInfo(String message) async {
    try {
      final entities = _nlp.extractAdvancedEntities(message);

      return ExtractedMessageInfo(
        names: List<String>.from(entities['names'] ?? []),
        locations: List<String>.from(entities['locations'] ?? []),
        dates: List<String>.from(entities['dates'] ?? []),
        times: List<String>.from(entities['times'] ?? []),
        phoneNumbers: _extractPhoneNumbers(message),
        emails: _extractEmails(message),
        emotions: List<String>.from(entities['emotions'] ?? []),
      );
    } catch (e) {
      print('Error extracting personal info: $e');
      return ExtractedMessageInfo();
    }
  }

  /// شناسایی اولویت
  Future<MessagePriority> detectPriority(String message) async {
    try {
      // کلمات فوری (فارسی)
      final urgentKeywords = [
        'فوری',
        'الان',
        'فورا',
        'اضطراری',
        'فی‌الحال',
        'شتاب',
      ];

      // کلمات فوری (انگلیسی)
      final urgentKeywordsEn = [
        'urgent',
        'immediately',
        'emergency',
        'asap',
        'critical',
        'now',
      ];

      final messageLower = message.toLowerCase();

      if (urgentKeywords.any((kw) => messageLower.contains(kw)) ||
          urgentKeywordsEn.any((kw) => messageLower.contains(kw))) {
        return MessagePriority.high;
      }

      // کلمات کم‌اهمیت
      final lowKeywords = [
        'معمول',
        'معمولی',
        'عادی',
        'بعدا',
        'خالی',
      ];

      final lowKeywordsEn = [
        'normal',
        'regular',
        'ordinary',
        'later',
        'whenever',
      ];

      if (lowKeywords.any((kw) => messageLower.contains(kw)) ||
          lowKeywordsEn.any((kw) => messageLower.contains(kw))) {
        return MessagePriority.low;
      }

      return MessagePriority.medium;
    } catch (e) {
      print('Error detecting priority: $e');
      return MessagePriority.medium;
    }
  }

  /// خلاصه‌سازی پیام
  Future<String> getSummary(String message) async {
    try {
      // برای پیام‌های کوتاه، خود پیام را بازگردان
      if (message.length < 100) {
        return message;
      }

      // برای پیام‌های بلند، جملۀ اول را برگردان
      final sentences = message.split(RegExp(r'[.!?؟]'));
      if (sentences.isNotEmpty && sentences.first.isNotEmpty) {
        return sentences.first.trim();
      }

      return message.substring(0, 100).trim() + '...';
    } catch (e) {
      print('Error getting summary: $e');
      return message;
    }
  }

  /// آیا نیاز به یادآوری است؟
  Future<bool> shouldRemind(String message) async {
    try {
      // شناسایی کلماتی که نیاز به یادآوری را نشان می‌دهند
      final remindKeywords = [
        'یادآوری',
        'یادم باش',
        'یادآور',
        'لطفا',
        'درخواست',
        'بیا',
        'برو',
      ];

      final remindKeywordsEn = [
        'reminder',
        'remind',
        'please',
        'request',
        'need',
      ];

      final messageLower = message.toLowerCase();

      return remindKeywords.any((kw) => messageLower.contains(kw)) ||
          remindKeywordsEn.any((kw) => messageLower.contains(kw));
    } catch (e) {
      print('Error checking if should remind: $e');
      return false;
    }
  }

  /// آیا پاسخ لازم است؟
  Future<bool> needsReply(String message) async {
    try {
      // علامت‌های سؤال
      if (message.contains('؟') || message.contains('?')) {
        return true;
      }

      // فراخوان‌های مستقیم (فارسی)
      final callKeywords = [
        'تو',
        'شما',
        'می‌تونی',
        'می‌شه',
        'می‌تونید',
        'لطفا',
        'کمکم کن',
      ];

      // فراخوان‌های مستقیم (انگلیسی)
      final callKeywordsEn = [
        'you',
        'can you',
        'could you',
        'can i',
        'would you',
        'please',
      ];

      final messageLower = message.toLowerCase();

      return callKeywords.any((kw) => messageLower.contains(kw)) ||
          callKeywordsEn.any((kw) => messageLower.contains(kw));
    } catch (e) {
      print('Error checking if needs reply: $e');
      return false;
    }
  }

  /// تحلیل کامل پیام
  Future<Message> analyzeMessage(Message message) async {
    try {
      final keyPoints = await extractKeyPoints(message.body);
      final priority = await detectPriority(message.body);
      final summary = await getSummary(message.body);
      final needsRep = await needsReply(message.body);

      return message.copyWith(
        keyPoints: keyPoints,
        priority: priority,
        summary: summary,
        needsReply: needsRep,
      );
    } catch (e) {
      print('Error analyzing message: $e');
      return message;
    }
  }

  // توابع کمکی
  List<String> _extractPhoneNumbers(String message) {
    try {
      // الگوی شماره تلفن (10-11 رقم)
      final regex = RegExp(r'\d{10,11}');
      return regex.allMatches(message).map((m) => m.group(0)!).toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _extractEmails(String message) {
    try {
      // الگوی ایمیل
      final regex = RegExp(
        r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      );
      return regex.allMatches(message).map((m) => m.group(0)!).toList();
    } catch (_) {
      return [];
    }
  }
}
