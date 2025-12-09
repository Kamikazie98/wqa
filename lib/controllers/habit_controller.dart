
import 'package:riverpod/riverpod.dart';

import '../models/user_models.dart';
import '../services/api_service.dart';
import '../services/service_providers.dart';

// Provider for the HabitController
final habitControllerProvider =
    StateNotifierProvider<HabitController, AsyncValue<List<Habit>>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return HabitController(apiService);
});

class HabitController extends StateNotifier<AsyncValue<List<Habit>>> {
  final ApiService _apiService;

  HabitController(this._apiService) : super(const AsyncValue.loading()) {
    getHabits();
  }

  Future<void> getHabits() async {
    try {
      state = const AsyncValue.loading();
      final habits = await _apiService.getHabits();
      state = AsyncValue.data(habits);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createHabit(Habit habit) async {
    try {
      await _apiService.createHabit(habit);
      getHabits(); // Refresh the list
    } catch (e) {
      // Handle error appropriately in the UI
    }
  }

  Future<void> logHabit(String habitId, bool completed) async {
    try {
      await _apiService.logHabitCompletion(habitId, {'completed': completed});
      getHabits(); // Refresh the list
    } catch (e) {
      // Handle error
    }
  }

  Future<void> deleteHabit(String habitId) async {
    try {
      await _apiService.deleteHabit(habitId);
      getHabits(); // Refresh the list
    } catch (e) {
      // Handle error
    }
  }
}
