
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'api_client.dart';
import 'goal_suggestion_service.dart';
import 'local_nlp_processor.dart';
import 'notification_service.dart';

// Provider for SharedPreferences - assuming it's initialized elsewhere and provided.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final apiClientProvider = Provider<ApiClient>((ref) {
  // This is a placeholder. You should configure your ApiClient properly.
  return ApiClient(tokenProvider: () => null);
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiService(apiClient);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final localNLPProcessorProvider = Provider<LocalNLPProcessor>((ref) {
  return LocalNLPProcessor(); 
});

final goalSuggestionServiceProvider = Provider<GoalSuggestionService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final nlpProcessor = ref.watch(localNLPProcessorProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return GoalSuggestionService(apiClient, nlpProcessor, prefs, notificationService);
});
