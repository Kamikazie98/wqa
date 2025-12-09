import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/exceptions.dart';
import '../services/session_storage.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required ApiClient apiClient,
    required SessionStorage storage,
  })  : _apiClient = apiClient,
        _storage = storage {
    _sessions = _storage.loadSessions();
    if (_sessions.isEmpty) {
      final session = ChatSession(title: 'مکالمه جدید');
      _sessions = <ChatSession>[session];
      _activeSessionId = session.id;
    } else {
      _activeSessionId = _sessions.first.id;
    }
  }

  final ApiClient _apiClient;
  final SessionStorage _storage;
  List<ChatSession> _sessions = <ChatSession>[];
  String? _activeSessionId;
  bool _isStreaming = false;
  bool _webSearchEnabled = false;
  String? _errorMessage;
  String? _statusMessage;
  String? _typingStatus;
  String? _typingMessage;

  List<ChatSession> get sessions => List<ChatSession>.unmodifiable(_sessions);
  ChatSession get activeSession => _ensureActiveSession();
  bool get isStreaming => _isStreaming;
  bool get webSearchEnabled => _webSearchEnabled;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  String? get typingStatus => _typingStatus;
  String? get typingMessage => _typingMessage;

  void setWebSearch(bool value) {
    _webSearchEnabled = value;
    notifyListeners();
  }

  Future<void> sendMessage(
    String input, {
    String? expertDomain,
    List<String>? fileUrls,
    List<String>? filePaths,
  }) async {
    final text = input.trim();
    if (text.isEmpty || _isStreaming) {
      return;
    }
    final session = _ensureActiveSession();
    final userMessage = ChatMessage(role: 'user', content: text);
    final assistantMessage = ChatMessage(role: 'assistant', content: '');
    final messagesForApi = <ChatMessage>[...session.messages, userMessage];
    final request = ChatRequest(
      sessionId: session.id,
      webSearch: expertDomain != null
          ? true
          : _webSearchEnabled, // برای expert همیشه فعال
      expertDomain: expertDomain,
      fileUrls: fileUrls?.where((url) => url.trim().isNotEmpty).toList(),
      messages: messagesForApi
          .map((m) => ChatRequestMessage(role: m.role, content: m.content))
          .toList(),
    );

    _updateSession(
      session.copyWith(
        messages: [...messagesForApi, assistantMessage],
      ),
    );

    _errorMessage = null;
    _statusMessage = null;
    _setStreaming(true);

    try {
      final files = filePaths?.where((p) => p.trim().isNotEmpty).toList() ?? [];
      final stream = files.isNotEmpty
          ? _apiClient.streamChatWithFiles(request, files)
          : _apiClient.streamChat(request);

      await for (final event in stream) {
        if (event is ChatTypingEvent) {
          _typingStatus = event.status;
          _typingMessage = event.message;
          notifyListeners();
        } else if (event is ChatTokenEvent) {
          _typingStatus = null;
          _typingMessage = null;
          _applyToken(session.id, assistantMessage.id, event.text);
        } else if (event is ChatWarnEvent) {
          _statusMessage = event.message;
          notifyListeners();
        } else if (event is ChatMetaEvent) {
          final filteredEntries = event.meta.entries.where(
            (entry) {
              final key = entry.key.toString().toLowerCase();
              return key != 'model' && key != 'provider';
            },
          );
          final info = filteredEntries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join(' • ');
          _statusMessage = info.isEmpty ? null : info;
          if (_statusMessage != null) {
            notifyListeners();
          }
        } else if (event is ChatDoneEvent) {
          if (event.text.isNotEmpty &&
              !_messageHasContent(session.id, assistantMessage.id)) {
            _applyToken(session.id, assistantMessage.id, event.text);
          }
          if (event.model != null) {
            _applyModel(session.id, assistantMessage.id, event.model);
          }
          final info = [
            if (event.latencyMs != null) 'زمان: ${event.latencyMs}ms',
          ].where((element) => element.isNotEmpty).join(' • ');
          _statusMessage = info.isEmpty ? null : info;
        }
      }
    } catch (error) {
      final message =
          error is ApiException ? error.message : 'خطای ناشناخته در پاسخ مدل.';
      _errorMessage = message;
      _replaceAssistantWithError(session.id, assistantMessage.id, message);
    } finally {
      await _persist();
      _setStreaming(false);
      notifyListeners();
    }
  }

  void selectSession(String sessionId) {
    if (_activeSessionId == sessionId) return;
    if (_sessions.any((session) => session.id == sessionId)) {
      _activeSessionId = sessionId;
      notifyListeners();
    }
  }

  void createSession({String? title}) {
    final session = ChatSession(title: title ?? 'مکالمه جدید');
    _sessions = <ChatSession>[session, ..._sessions];
    _activeSessionId = session.id;
    unawaited(_persist());
    notifyListeners();
  }

  void renameSession(String sessionId, String newTitle) {
    final index = _sessions.indexWhere((session) => session.id == sessionId);
    if (index == -1) return;
    final updated = _sessions[index].copyWith(title: newTitle.trim());
    _sessions[index] = updated;
    unawaited(_persist());
    notifyListeners();
  }

  void deleteSession(String sessionId) {
    _sessions.removeWhere((session) => session.id == sessionId);
    if (_sessions.isEmpty) {
      createSession();
    } else if (_activeSessionId == sessionId) {
      _activeSessionId = _sessions.first.id;
    }
    unawaited(_persist());
    notifyListeners();
  }

  void importSession(ChatSession session) {
    _sessions.insert(0, session);
    _activeSessionId = session.id;
    unawaited(_persist());
    notifyListeners();
  }

  ChatSession _ensureActiveSession() {
    if (_activeSessionId == null ||
        !_sessions.any((s) => s.id == _activeSessionId)) {
      if (_sessions.isEmpty) {
        createSession();
      } else {
        _activeSessionId = _sessions.first.id;
      }
    }
    return _sessions.firstWhere((session) => session.id == _activeSessionId);
  }

  void _setStreaming(bool value) {
    if (_isStreaming == value) return;
    _isStreaming = value;
    notifyListeners();
  }

  void _updateSession(ChatSession session) {
    final index = _sessions.indexWhere((element) => element.id == session.id);
    if (index == -1) {
      _sessions.insert(0, session);
    } else {
      _sessions[index] = session;
    }
    notifyListeners();
  }

  void _applyToken(String sessionId, String messageId, String token) {
    final sessionIndex =
        _sessions.indexWhere((session) => session.id == sessionId);
    if (sessionIndex == -1) return;
    final session = _sessions[sessionIndex];
    final messageIndex =
        session.messages.indexWhere((message) => message.id == messageId);
    if (messageIndex == -1) return;
    final target = session.messages[messageIndex];
    final updatedContent = '${target.content}$token';
    final updatedMessages = [...session.messages];
    updatedMessages[messageIndex] = target.copyWith(content: updatedContent);
    _sessions[sessionIndex] = session.copyWith(messages: updatedMessages);
    notifyListeners();
  }

  void _applyModel(String sessionId, String messageId, String? model) {
    if (model == null || model.trim().isEmpty) return;
    final sessionIndex =
        _sessions.indexWhere((session) => session.id == sessionId);
    if (sessionIndex == -1) return;
    final session = _sessions[sessionIndex];
    final messageIndex =
        session.messages.indexWhere((message) => message.id == messageId);
    if (messageIndex == -1) return;
    final target = session.messages[messageIndex];
    final updatedMessages = [...session.messages];
    updatedMessages[messageIndex] = target.copyWith(model: model);
    _sessions[sessionIndex] = session.copyWith(messages: updatedMessages);
    notifyListeners();
  }

  void _replaceAssistantWithError(
    String sessionId,
    String messageId,
    String error,
  ) {
    final sessionIndex =
        _sessions.indexWhere((session) => session.id == sessionId);
    if (sessionIndex == -1) return;
    final session = _sessions[sessionIndex];
    final messageIndex =
        session.messages.indexWhere((message) => message.id == messageId);
    if (messageIndex == -1) return;
    final updatedMessages = [...session.messages];
    updatedMessages[messageIndex] =
        updatedMessages[messageIndex].copyWith(error: error);
    _sessions[sessionIndex] = session.copyWith(messages: updatedMessages);
  }

  bool _messageHasContent(String sessionId, String messageId) {
    final sessionIndex =
        _sessions.indexWhere((session) => session.id == sessionId);
    if (sessionIndex == -1) return false;
    final session = _sessions[sessionIndex];
    final messageIndex =
        session.messages.indexWhere((message) => message.id == messageId);
    if (messageIndex == -1) return false;
    return session.messages[messageIndex].content.trim().isNotEmpty;
  }

  Future<void> sendExpertMessage(
    String input,
    String expertDomain, {
    List<String>? fileUrls,
    List<String>? filePaths,
  }) async {
    await sendMessage(
      input,
      expertDomain: expertDomain,
      fileUrls: fileUrls,
      filePaths: filePaths,
    );
  }

  Future<void> _persist() async {
    await _storage.saveSessions(_sessions);
  }
}
