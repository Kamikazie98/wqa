import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Intelligent caching service for AI responses with learning capabilities
class SmartCacheService {
  SmartCacheService({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;
  static const _cachePrefix = 'smart_cache.';
  static const _frequencyPrefix = 'query_freq.';
  static const _maxCacheSize = 100;

  /// Cache AI response with frequency tracking
  Future<void> cacheResponse(
      String query, Map<String, dynamic> response) async {
    final key = _cachePrefix + _hashQuery(query);
    await _prefs.setString(key, jsonEncode(response));
    await _updateFrequency(query);
    await _cleanupOldCache();
  }

  /// Get cached response if available
  Map<String, dynamic>? getCachedResponse(String query) {
    final key = _cachePrefix + _hashQuery(query);
    final cached = _prefs.getString(key);
    if (cached != null) {
      return jsonDecode(cached) as Map<String, dynamic>;
    }
    return null;
  }

  /// Track query frequency for learning user patterns
  Future<void> _updateFrequency(String query) async {
    final key = _frequencyPrefix + _hashQuery(query);
    final current = _prefs.getInt(key) ?? 0;
    await _prefs.setInt(key, current + 1);
  }

  /// Get most frequent queries for proactive suggestions
  List<String> getMostFrequentQueries({int limit = 10}) {
    final frequencies = <String, int>{};
    final keys = _prefs.getKeys().where((k) => k.startsWith(_frequencyPrefix));

    for (final key in keys) {
      final query = key.replaceFirst(_frequencyPrefix, '');
      final freq = _prefs.getInt(key) ?? 0;
      frequencies[query] = freq;
    }

    final sorted = frequencies.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Clean up least used cache entries
  Future<void> _cleanupOldCache() async {
    final cacheKeys = _prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
    if (cacheKeys.length <= _maxCacheSize) return;

    final keysWithFreq = <String, int>{};
    for (final key in cacheKeys) {
      final query = key.replaceFirst(_cachePrefix, '');
      final freq = _prefs.getInt(_frequencyPrefix + query) ?? 0;
      keysWithFreq[key] = freq;
    }

    final sorted = keysWithFreq.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final toRemove = sorted.take(cacheKeys.length - _maxCacheSize);
    for (final entry in toRemove) {
      await _prefs.remove(entry.key);
    }
  }

  String _hashQuery(String query) {
    return query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  /// Clear all cache
  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where(
        (k) => k.startsWith(_cachePrefix) || k.startsWith(_frequencyPrefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
