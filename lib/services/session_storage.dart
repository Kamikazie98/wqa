import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';

class SessionStorage {
  SessionStorage(this._prefs);

  static const _sessionsKey = 'chat.sessions';

  final SharedPreferences _prefs;

  List<ChatSession> loadSessions() {
    final raw = _prefs.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) {
      return <ChatSession>[];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => ChatSession.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <ChatSession>[];
    }
  }

  Future<void> saveSessions(List<ChatSession> sessions) async {
    final payload = sessions.map((s) => s.toJson()).toList();
    await _prefs.setString(_sessionsKey, jsonEncode(payload));
  }

  Future<void> clear() => _prefs.remove(_sessionsKey);
}
