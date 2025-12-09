
import '../models/user_models.dart';
import 'api_client.dart';
import 'goal_suggestion_service.dart';

class ApiService {
  final ApiClient _apiClient;
  final GoalSuggestionService _goalSuggestionService;

  ApiService(this._apiClient) : _goalSuggestionService = GoalSuggestionService(this);

  Future<List<Goal>> getGoalSuggestions() {
    return _goalSuggestionService.getGoalSuggestions();
  }

  // Methods from ApiClient that you want to expose
  Future<UserProfile> setupUserProfile(UserProfile userProfile) => _apiClient.setupUserProfile(userProfile);
  Future<UserProfile> getUserProfile() => _apiClient.getUserProfile();
  Future<UserProfile> updateUserProfile(UserProfile userProfile) => _apiClient.updateUserProfile(userProfile);

  Future<List<Group>> getGroups() async {
    // Mock data for now
    await Future.delayed(const Duration(seconds: 1));
    return [
      Group(id: '1', name: 'Family', description: 'Family group'),
      Group(id: '2', name: 'Friends', description: 'Friends group'),
    ];
  }
}

class Group {
  final String id;
  final String name;
  final String description;

  Group({required this.id, required this.name, required this.description});
}
