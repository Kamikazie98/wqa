
import '../models/user_models.dart';
import 'api_client.dart';

class GoalSuggestionService {
  final ApiClient _apiClient;

  GoalSuggestionService(this._apiClient);

  Future<List<Goal>> getGoalSuggestions() async {
    // In a real application, this method would analyze user data
    // to generate personalized goal suggestions. For now, we'll
    // return a list of mock suggestions.
    final mockSuggestions = [
      Goal(
        id: 'goal_1',
        title: 'Read 12 books this year',
        description: 'Expand your knowledge and perspective by reading one book per month.',
      ),
      Goal(
        id: 'goal_2',
        title: 'Learn a new language',
        description: 'Challenge yourself and open up new cultural horizons by learning a new language.',
      ),
      Goal(
        id: 'goal_3',
        title: 'Start a side project',
        description: 'Turn your passion into a project and develop new skills.',
      ),
    ];

    return Future.delayed(const Duration(seconds: 2), () => mockSuggestions);
  }
}
