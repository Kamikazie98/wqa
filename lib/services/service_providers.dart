
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service.dart';
import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  // This is a placeholder. You should configure your ApiClient properly.
  return ApiClient(tokenProvider: () => null);
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiService(apiClient);
});
