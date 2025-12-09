import 'package:intl/intl.dart';

enum MessagePriority {
  high,
  medium,
  low,
}

enum MessageChannel {
  sms,
  whatsapp,
  telegram,
  email,
  messenger,
}

extension MessagePriorityExtension on MessagePriority {
  String get label {
    switch (this) {
      case MessagePriority.high:
        return 'فوری';
      case MessagePriority.medium:
        return 'عادی';
      case MessagePriority.low:
        return 'کم‌اهمیت';
    }
  }

  String get emoji {
    switch (this) {
      case MessagePriority.high:
        return '🔴';
      case MessagePriority.medium:
        return '🟡';
      case MessagePriority.low:
        return '🟢';
    }
  }
}

extension MessageChannelExtension on MessageChannel {
  String get label {
    switch (this) {
      case MessageChannel.sms:
        return 'پیامک';
      case MessageChannel.whatsapp:
        return 'واتس‌اپ';
      case MessageChannel.telegram:
        return 'تلگرام';
      case MessageChannel.email:
        return 'ایمیل';
      case MessageChannel.messenger:
        return 'مسنجر';
    }
  }

  String get emoji {
    switch (this) {
      case MessageChannel.sms:
        return '📱';
      case MessageChannel.whatsapp:
        return '💬';
      case MessageChannel.telegram:
        return '✈️';
      case MessageChannel.email:
        return '📧';
      case MessageChannel.messenger:
        return '💭';
    }
  }
}

class Message {
  final String id;
  final String sender;
  final String senderName;
  final String body;
  final DateTime timestamp;
  final MessageChannel channel;
  final bool isRead;
  final bool isArchived;
  final List<String> keyPoints;
  final Map<String, dynamic> extractedInfo;
  final MessagePriority priority;
  final String? summary;
  final bool needsReply;
  final List<String> suggestedActions;

  Message({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.body,
    required this.timestamp,
    required this.channel,
    required this.isRead,
    this.isArchived = false,
    this.keyPoints = const [],
    this.extractedInfo = const {},
    this.priority = MessagePriority.medium,
    this.summary,
    this.needsReply = false,
    this.suggestedActions = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic ts) {
      if (ts == null) return DateTime.now();

      // اگر int یا double باشد (milliseconds)
      if (ts is int) {
        return DateTime.fromMillisecondsSinceEpoch(ts);
      }
      if (ts is double) {
        return DateTime.fromMillisecondsSinceEpoch(ts.toInt());
      }

      // اگر string باشد
      if (ts is String) {
        try {
          return DateTime.parse(ts);
        } catch (_) {
          // اگر ISO format نباشد، شاید milliseconds numeric string است
          try {
            return DateTime.fromMillisecondsSinceEpoch(int.parse(ts));
          } catch (_) {
            return DateTime.now();
          }
        }
      }

      return DateTime.now();
    }

    return Message(
      id: json['id']?.toString() ?? '',
      sender: json['sender']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      timestamp: parseTimestamp(json['timestamp']),
      channel: MessageChannel.values.byName(
        json['channel']?.toString() ?? 'sms',
      ),
      isRead: json['isRead'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      keyPoints: List<String>.from(json['keyPoints'] ?? []),
      extractedInfo: Map<String, dynamic>.from(json['extractedInfo'] ?? {}),
      priority: MessagePriority.values.byName(
        json['priority']?.toString() ?? 'medium',
      ),
      summary: json['summary']?.toString(),
      needsReply: json['needsReply'] as bool? ?? false,
      suggestedActions: List<String>.from(json['suggestedActions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'senderName': senderName,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'channel': channel.name,
        'isRead': isRead,
        'isArchived': isArchived,
        'keyPoints': keyPoints,
        'extractedInfo': extractedInfo,
        'priority': priority.name,
        'summary': summary,
        'needsReply': needsReply,
        'suggestedActions': suggestedActions,
      };

  Message copyWith({
    bool? isRead,
    bool? isArchived,
    List<String>? keyPoints,
    String? summary,
    bool? needsReply,
    MessagePriority? priority,
  }) {
    return Message(
      id: id,
      sender: sender,
      senderName: senderName,
      body: body,
      timestamp: timestamp,
      channel: channel,
      isRead: isRead ?? this.isRead,
      isArchived: isArchived ?? this.isArchived,
      keyPoints: keyPoints ?? this.keyPoints,
      extractedInfo: extractedInfo,
      priority: priority ?? this.priority,
      summary: summary ?? this.summary,
      needsReply: needsReply ?? this.needsReply,
      suggestedActions: suggestedActions,
    );
  }

  bool get isImportant => priority == MessagePriority.high || needsReply;

  Duration get age => DateTime.now().difference(timestamp);

  bool get isRecent => age.inHours < 24;

  String get timeString {
    final formatter = DateFormat('HH:mm', 'fa_IR');
    return formatter.format(timestamp);
  }

  String get dateString {
    final formatter = DateFormat('yyyy/MM/dd', 'fa_IR');
    return formatter.format(timestamp);
  }
}

class MessageThread {
  final String id;
  final List<Message> messages;
  final String participantName;
  final MessageChannel channel;
  final DateTime lastMessageTime;
  final bool hasUnread;
  final int unreadCount;

  MessageThread({
    required this.id,
    required this.messages,
    required this.participantName,
    required this.channel,
    required this.lastMessageTime,
    this.hasUnread = false,
    this.unreadCount = 0,
  });

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    return MessageThread(
      id: json['id']?.toString() ?? '',
      messages: (json['messages'] as List?)
              ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      participantName: json['participantName']?.toString() ?? '',
      channel: MessageChannel.values.byName(
        json['channel']?.toString() ?? 'sms',
      ),
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'].toString())
          : DateTime.now(),
      hasUnread: json['hasUnread'] as bool? ?? false,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'messages': messages.map((e) => e.toJson()).toList(),
        'participantName': participantName,
        'channel': channel.name,
        'lastMessageTime': lastMessageTime.toIso8601String(),
        'hasUnread': hasUnread,
        'unreadCount': unreadCount,
      };

  Message? get lastMessage => messages.isNotEmpty ? messages.last : null;

  int get messageCount => messages.length;
}

class ExtractedMessageInfo {
  final List<String> names;
  final List<String> locations;
  final List<String> dates;
  final List<String> times;
  final List<String> phoneNumbers;
  final List<String> emails;
  final List<String> emotions;
  final Map<String, dynamic> customData;

  ExtractedMessageInfo({
    this.names = const [],
    this.locations = const [],
    this.dates = const [],
    this.times = const [],
    this.phoneNumbers = const [],
    this.emails = const [],
    this.emotions = const [],
    this.customData = const {},
  });

  factory ExtractedMessageInfo.fromJson(Map<String, dynamic> json) {
    return ExtractedMessageInfo(
      names: List<String>.from(json['names'] ?? []),
      locations: List<String>.from(json['locations'] ?? []),
      dates: List<String>.from(json['dates'] ?? []),
      times: List<String>.from(json['times'] ?? []),
      phoneNumbers: List<String>.from(json['phoneNumbers'] ?? []),
      emails: List<String>.from(json['emails'] ?? []),
      emotions: List<String>.from(json['emotions'] ?? []),
      customData: Map<String, dynamic>.from(json['customData'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'names': names,
        'locations': locations,
        'dates': dates,
        'times': times,
        'phoneNumbers': phoneNumbers,
        'emails': emails,
        'emotions': emotions,
        'customData': customData,
      };

  bool get isEmpty =>
      names.isEmpty &&
      locations.isEmpty &&
      dates.isEmpty &&
      times.isEmpty &&
      phoneNumbers.isEmpty &&
      emails.isEmpty &&
      emotions.isEmpty;
}
