
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import '../models/user_models.dart';
import 'api_client.dart';
import 'local_nlp_processor.dart';
import 'notification_service.dart';

class GoalSuggestionService {
  final ApiClient _apiClient;
  final LocalNLPProcessor _nlpProcessor;
  final SharedPreferences _prefs;
  final NotificationService _notificationService;

  GoalSuggestionService(this._apiClient, this._nlpProcessor, this._prefs, this._notificationService);

  Future<List<Goal>> getGoalSuggestions() async {
    try {
      // 1. Attempt to fetch fresh suggestions from the API first.
      print('Attempting to fetch goal suggestions from API...');
      final userProfile = await _apiClient.getUserProfile();
      final habits = await _apiClient.getHabits();
      final goals = await _apiClient.getGoals();

      // 2. Construct a prompt for the AI, including user feedback.
      final feedback = _nlpProcessor.getGoalFeedback();
      final prompt = """
      Based on the following user data and feedback, generate 3 personalized goal suggestions.
      The user's interests are: ${userProfile.interests.join(', ')}.
      The user's current habits are: ${habits.map((h) => h.name).join(', ')}.
      The user's current goals are: ${goals.map((g) => g.title).join(', ')}.
      User feedback on previous suggestions: $feedback

      Return the suggestions as a JSON array of objects, where each object has an "id", "title", and "description".
      For example:
      [
        {"id": "read_more", "title": "Read More Books", "description": "Based on your interest in learning, try reading one book a month."},
        {"id": "learn_instrument", "title": "Learn an Instrument", "description": "Challenge yourself by learning to play the guitar."}
      ]
      """;

      final request = ChatRequest(
        messages: [ChatMessage(role: 'user', content: prompt)],
        model: 'gpt-4',
      );

      // 3. Call the chat API and process the response.
      final stream = _apiClient.streamChat(request);
      String fullResponse = '';
      await for (final event in stream) {
        if (event.type == 'message' && event.data is String) {
          fullResponse += event.data;
        }
      }

      // 4. Extract, parse, and return the suggestions.
      final jsonResponse = _extractJson(fullResponse);
      final List<dynamic> suggestionsJson = jsonDecode(jsonResponse);
      final suggestions = suggestionsJson.map((json) => Goal(
        id: json['id'],
        title: json['title'],
        description: json['description'],
      )).toList();

      // 5. If suggestions were fetched, cache them and notify the user.
      if (suggestions.isNotEmpty) {
        print('API call successful. Caching new suggestions.');
        _cacheSuggestions(suggestions);
        _notificationService.showLocalNow(
          title: 'New Goal Suggestions',
          body: 'We have some new goal suggestions for you!',
        );
      }
      
      return suggestions;

    } catch (e) {
      // If the API call fails (e.g., offline), fall back to local mechanisms.
      print('Error fetching goal suggestions from API: $e');

      // Fallback 1: Try to load suggestions from the cache.
      final cachedSuggestions = _getCachedSuggestions();
      if (cachedSuggestions.isNotEmpty) {
        print('Returning suggestions from cache.');
        return cachedSuggestions;
      }

      // Fallback 2: If cache is empty, generate generic local suggestions.
      print('Cache is empty. Generating generic local suggestions as a fallback.');
      return _generateLocalSuggestions();
    }
  }

  String _extractJson(String text) {
    final startIndex = text.indexOf('[');
    final endIndex = text.lastIndexOf(']');
    if (startIndex != -1 && endIndex != -1) {
      return text.substring(startIndex, endIndex + 1);
    }
    return '[]'; // Return an empty JSON array on failure.
  }

  void _cacheSuggestions(List<Goal> suggestions) {
    final suggestionsList = suggestions.map((s) => {
      'id': s.id,
      'title': s.title,
      'description': s.description,
    }).toList();
    _prefs.setString('goal_suggestions', jsonEncode(suggestionsList));
  }

  List<Goal> _getCachedSuggestions() {
    final suggestionsString = _prefs.getString('goal_suggestions');
    if (suggestionsString != null) {
      try {
        final List<dynamic> suggestionsJson = jsonDecode(suggestionsString);
        return suggestionsJson.map((json) => Goal(
          id: json['id'],
          title: json['title'],
          description: json['description'],
        )).toList();
      } catch (e) {
        print('Error decoding cached suggestions: $e');
        return [];
      }
    }
    return [];
  }

  List<Goal> _generateLocalSuggestions() {
    // As a final fallback, provide a few generic, high-value suggestions.
    return [
      Goal(
        id: 'local_walk_daily',
        title: 'Go for a Daily Walk',
        description: 'Improve your physical and mental health with a short daily walk.',
      ),
      Goal(
        id: 'local_read_more',
        title: 'Read for 15 Minutes a Day',
        description: 'Expand your knowledge and relax by reading every day.',
      ),
      Goal(
        id: 'local_mindfulness',
        title: 'Practice Mindfulness for 5 Minutes',
        description: 'Reduce stress and improve focus with a brief daily mindfulness session.',
      ),
    ];
  }
}
