import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../services/exceptions.dart';

const _uuid = Uuid();

class ChatMessage {
  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.warning,
    this.error,
    this.model,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final String? warning;
  final String? error;
  final String? model;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatMessage copyWith({
    String? content,
    String? warning,
    String? error,
    String? model,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'warning': warning,
        'error': error,
        'model': model,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      warning: json['warning'] as String?,
      error: json['error'] as String?,
      model: json['model'] as String?,
    );
  }
}

class ChatSession {
  ChatSession({
    String? id,
    required this.title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? <ChatMessage>[];

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatSession copyWith({
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      messages: messages ?? List<ChatMessage>.from(this.messages),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? <dynamic>[];
    return ChatSession(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'مکالمه جدید',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      messages: rawMessages
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatRequest {
  const ChatRequest({
    required this.sessionId,
    required this.messages,
    required this.webSearch,
    this.expertDomain,
    this.fileUrls,
  });

  final String sessionId;
  final List<ChatRequestMessage> messages;
  final bool webSearch;
  final String?
      expertDomain; // psychology, psychiatry, real_estate, mechanics, talent_assessment
  final List<String>? fileUrls;

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'web_search': webSearch,
        'messages': messages.map((m) => m.toJson()).toList(),
        if (expertDomain != null) 'expert_domain': expertDomain,
        if (fileUrls != null && fileUrls!.isNotEmpty) 'file_urls': fileUrls,
      };
}

class ChatRequestMessage {
  const ChatRequestMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

sealed class ChatSseEvent {
  const ChatSseEvent();

  factory ChatSseEvent.fromEvent(String event, String data) {
    final normalizedEvent = event.trim().isEmpty ? 'token' : event.trim();
    switch (normalizedEvent) {
      case 'token':
        return ChatTokenEvent(_safeDecodeTokenText(data));
      case 'warn':
        return ChatWarnEvent(_safeDecodeMessage(data));
      case 'meta':
        return ChatMetaEvent(_safeDecodeMap(data));
      case 'done':
        return ChatDoneEvent(_safeDecodeMap(data));
      case 'typing':
        final dataMap = _safeDecodeMap(data);
        return ChatTypingEvent(
          dataMap['status']?.toString() ?? 'thinking',
          dataMap['message']?.toString() ?? '',
        );
      default:
        return ChatTokenEvent(data);
    }
  }
}

class ChatTokenEvent extends ChatSseEvent {
  const ChatTokenEvent(this.text);

  final String text;
}

class ChatWarnEvent extends ChatSseEvent {
  const ChatWarnEvent(this.message);

  final String message;
}

class ChatMetaEvent extends ChatSseEvent {
  const ChatMetaEvent(this.meta);

  final Map<String, dynamic> meta;
}

class ChatDoneEvent extends ChatSseEvent {
  ChatDoneEvent(Map<String, dynamic> meta)
      : latencyMs = (meta['latency_ms'] as num?)?.toInt(),
        model = meta['model']?.toString(),
        text = meta['text']?.toString() ?? '',
        suggestedFollowups = (meta['suggested_followups'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

  final int? latencyMs;
  final String? model;
  final String text;
  final List<String> suggestedFollowups;
}

class ChatTypingEvent extends ChatSseEvent {
  const ChatTypingEvent(this.status, this.message);

  final String status; // thinking, searching, generating
  final String message;
}

String _safeDecodeMessage(String data) {
  try {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) {
      return decoded['message']?.toString() ?? data;
    }
    return decoded.toString();
  } catch (_) {
    return data;
  }
}

Map<String, dynamic> _safeDecodeMap(String data) {
  if (data.isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'data': decoded};
  } catch (_) {
    throw const ApiException('پاسخ نامعتبر از سرور دریافت شد.');
  }
}

String _safeDecodeTokenText(String data) {
  if (data.isEmpty) return '';
  try {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) {
      final text = decoded['text'];
      if (text is String) {
        return text;
      }
      if (text is List) {
        return text.join('');
      }
      return decoded['token']?.toString() ?? data;
    }
    if (decoded is List) {
      return decoded.join('');
    }
    if (decoded is String) {
      return decoded;
    }
    return decoded.toString();
  } catch (_) {
    return data;
  }
}
