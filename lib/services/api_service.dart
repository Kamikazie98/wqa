
import '../models/user_models.dart';
import 'api_client.dart';
import 'goal_suggestion_service.dart';

class ApiService {
  final ApiClient _apiClient;
  late final GoalSuggestionService _goalSuggestionService;

  ApiService(this._apiClient) {
    _goalSuggestionService = GoalSuggestionService(_apiClient);
  }

  Future<List<Goal>> getGoalSuggestions() {
    return _goalSuggestionService.getGoalSuggestions();
  }

  // Methods from ApiClient that you want to expose
  Future<UserProfile> setupUserProfile(UserProfile userProfile) => _apiClient.setupUserProfile(userProfile);
  Future<UserProfile> getUserProfile() => _apiClient.getUserProfile();
  Future<UserProfile> updateUserProfile(UserProfile userProfile) => _apiClient.updateUserProfile(userProfile);
  Future<List<Habit>> getHabits() => _apiClient.getHabits();
  Future<List<UserGoal>> getGoals() => _apiClient.getGoals();

}
