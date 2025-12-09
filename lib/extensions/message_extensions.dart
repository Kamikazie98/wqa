import '../models/message_models.dart';

/// توسیع برای Message
extension MessageExtensions on Message {
  /// دریافت متن خلاصه‌شده
  String get displaySummary =>
      summary ?? (body.length > 100 ? body.substring(0, 100) + '...' : body);

  /// آیا این پیام قدیمی است؟ (بیش از 7 روز)
  bool get isOld => age.inDays > 7;

  /// دریافت رنگ بر اساس اولویت
  String get priorityColor {
    switch (priority) {
      case MessagePriority.high:
        return '#FF6B6B';
      case MessagePriority.medium:
        return '#FFA726';
      case MessagePriority.low:
        return '#66BB6A';
    }
  }

  /// دریافت نام کناب برای نمایش
  String get displayName {
    if (senderName.isNotEmpty) return senderName;
    return sender;
  }

  /// دریافت خلاصۀ فعالیت
  String get activitySummary {
    final parts = <String>[];

    if (priority == MessagePriority.high) {
      parts.add('🔴 فوری');
    }

    if (needsReply) {
      parts.add('💬 نیاز به پاسخ');
    }

    if (keyPoints.isNotEmpty) {
      parts.add('📌 نکات: ${keyPoints.take(2).join(', ')}');
    }

    return parts.join(' | ');
  }
}

/// توسیع برای MessageThread
extension MessageThreadExtensions on MessageThread {
  /// دریافت پیام آخر
  String get lastMessagePreview {
    final last = lastMessage;
    if (last == null) return 'بدون پیام';

    return last.body.length > 50
        ? last.body.substring(0, 50) + '...'
        : last.body;
  }

  /// آیا این thread مهم است؟
  bool get isImportant {
    return unreadCount > 2 ||
        messages.any((m) => m.priority == MessagePriority.high);
  }

  /// دریافت نشان نخوانده‌ها
  String get unreadBadge {
    if (unreadCount == 0) return '';
    if (unreadCount > 99) return '99+';
    return unreadCount.toString();
  }
}

/// توسیع برای List<Message>
extension MessageListExtensions on List<Message> {
  /// فیلتر پیام‌های نخوانده
  List<Message> get unreadMessages => where((m) => !m.isRead).toList();

  /// فیلتر پیام‌های مهم
  List<Message> get importantMessages => where((m) => m.isImportant).toList();

  /// فیلتر پیام‌های اخیر (امروز)
  List<Message> get recentMessages {
    final today = DateTime.now();
    return where((m) {
      final sameDay = m.timestamp.year == today.year &&
          m.timestamp.month == today.month &&
          m.timestamp.day == today.day;
      return sameDay;
    }).toList();
  }

  /// دریافت خلاصه
  String get summary {
    if (isEmpty) return 'بدون پیام';

    final unread = unreadMessages.length;
    final important = importantMessages.length;

    final parts = <String>[];
    parts.add('$length پیام');

    if (unread > 0) {
      parts.add('$unread نخوانده');
    }

    if (important > 0) {
      parts.add('$important مهم');
    }

    return parts.join(' • ');
  }

  /// ترتیب براساس اولویت و زمان
  List<Message> get sortedByPriority {
    final sorted = [...this];
    sorted.sort((a, b) {
      // اولویت بالاتر ابتدا
      if (a.priority.index != b.priority.index) {
        return a.priority.index.compareTo(b.priority.index);
      }
      // سپس بر اساس زمان (جدیدتر ابتدا)
      return b.timestamp.compareTo(a.timestamp);
    });
    return sorted;
  }
}
