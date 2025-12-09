
import 'package:riverpod/riverpod.dart';

import '../models/user_models.dart';
import '../services/api_service.dart';
import '../services/service_providers.dart';

// Provider for the ActivityController
final activityControllerProvider = StateNotifierProvider<ActivityController, AsyncValue<List<Activity>>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ActivityController(apiService);
});

class ActivityController extends StateNotifier<AsyncValue<List<Activity>>> {
  final ApiService _apiService;

  ActivityController(this._apiService) : super(const AsyncValue.loading()) {
    getActivities();
  }

  Future<void> getActivities() async {
    try {
      state = const AsyncValue.loading();
      final activities = await _apiService.getActivities();
      state = AsyncValue.data(activities);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
