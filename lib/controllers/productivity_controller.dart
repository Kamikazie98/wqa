
import 'package:riverpod/riverpod.dart';

import '../models/daily_program_models.dart';
import '../services/api_service.dart';
import '../services/service_providers.dart';

// Provider for the ProductivityController
final productivityControllerProvider = StateNotifierProvider<
    ProductivityController, AsyncValue<SchedulingAnalysis>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ProductivityController(apiService);
});

class ProductivityController
    extends StateNotifier<AsyncValue<SchedulingAnalysis>> {
  final ApiService _apiService;

  ProductivityController(this._apiService)
      : super(const AsyncValue.loading()) {
    analyzeScheduling();
  }

  Future<void> analyzeScheduling() async {
    try {
      state = const AsyncValue.loading();
      final analysis = await _apiService.analyzeScheduling();
      state = AsyncValue.data(analysis);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
