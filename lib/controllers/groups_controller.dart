
import 'package:riverpod/riverpod.dart';

import '../models/user_models.dart';
import '../services/api_service.dart';
import '../services/service_providers.dart';

// Provider for the GroupsController
final groupsControllerProvider = StateNotifierProvider<GroupsController, AsyncValue<List<Group>>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return GroupsController(apiService);
});

class GroupsController extends StateNotifier<AsyncValue<List<Group>>> {
  final ApiService _apiService;

  GroupsController(this._apiService) : super(const AsyncValue.loading()) {
    getGroups();
  }

  Future<void> getGroups() async {
    try {
      state = const AsyncValue.loading();
      final groups = await _apiService.getGroups();
      state = AsyncValue.data(groups);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
