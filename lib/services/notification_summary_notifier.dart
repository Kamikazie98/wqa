import 'notification_summarizer_service.dart';
import 'notification_service.dart';

/// می‌گیرد خروجی AI (NotificationSummary) و یک نوتیف خلاصه روی دستگاه نشان می‌دهد.
class AiSummaryNotificationPusher {
  final NotificationSummarizerService summarizer;
  final NotificationService notificationService;

  AiSummaryNotificationPusher({
    required this.summarizer,
    required this.notificationService,
  });

  /// این متد را هر وقت خواستی (مثلاً یک بار در روز) صدا بزن
  Future<void> pushTodaySummaryNotification() async {
    // اینجا می‌تونی بعداً به‌جاش از generateSummary با notif.buffer هم استفاده کنی
    final summary = await summarizer.getTodaySummary();

    if (summary == null) {
      return;
    }

    final hasContent = summary.totalNotifications > 0 ||
        summary.importantMessages.isNotEmpty ||
        summary.criticalAlerts.isNotEmpty ||
        summary.actionItems.isNotEmpty ||
        (summary.aiGeneratedSummary?.isNotEmpty ?? false);

    if (!hasContent) {
      // چیزی نداریم که واقعا ارزش نوتیف داشته باشه
      return;
    }

    final body = _buildNotificationBody(summary);

    await notificationService.showLocalNow(
      title: 'خلاصه هوشمند امروزت ✨',
      body: body,
    );
  }

  String _buildNotificationBody(NotificationSummary summary) {
    final buffer = StringBuffer();

    // ۱) کارهای قابل اقدام (Action Items)
    if (summary.actionItems.isNotEmpty) {
      final items = summary.actionItems.take(3).toList();
      buffer.writeln('📌 کارهای مهم امروزت:');

      for (final item in items) {
        var priorityFa = item.priority;
        if (item.priority == 'high') {
          priorityFa = 'بالا';
        } else if (item.priority == 'medium') {
          priorityFa = 'متوسط';
        } else if (item.priority == 'low') {
          priorityFa = 'کم';
        }

        buffer.write('• ${item.title}');
        if (item.assignee != null && item.assignee!.isNotEmpty) {
          buffer.write(' برای ${item.assignee}');
        }
        buffer.write(' (اولویت: $priorityFa)');

        if (item.dueDate != null && item.dueDate!.isNotEmpty) {
          buffer.write(' – موعد: ${item.dueDate}');
        }

        buffer.writeln();
      }
    }

    // ۲) پیام‌های مهم
    if (summary.importantMessages.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();

      final msgs = summary.importantMessages.take(3).toList();
      buffer.writeln('💬 پیام‌هایی که بهتره امروز ببینی:');

      for (final msg in msgs) {
        final subject =
            msg.subject.isNotEmpty ? msg.subject : 'یک موضوع مهم';
        buffer.writeln('• ${msg.sender} درباره "$subject" بهت پیام داده');
      }
    }

    // ۳) اگر هیچ‌کدوم نبود، از خلاصه‌ی AI استفاده کن
    if (buffer.isEmpty && summary.aiGeneratedSummary?.isNotEmpty == true) {
      buffer.write(summary.aiGeneratedSummary);
    }

    // ۴) اگر هنوز هم خالی بود، یه پیام مثبت!
    if (buffer.isEmpty) {
      buffer.write('امروز اعلان مهمی نداشتی 🎉');
    }

    return buffer.toString().trim();
  }
}
