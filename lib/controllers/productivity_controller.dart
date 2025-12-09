
import 'package:flutter/material.dart';
import '../models/user_models.dart';
import '../services/goal_suggestion_service.dart';

class ProductivityController extends ChangeNotifier {
  final GoalSuggestionService _goalSuggestionService;

  ProductivityController(this._goalSuggestionService) {
    fetchGoalSuggestions();
  }

  List<Goal> _goalSuggestions = [];
  List<Goal> get goalSuggestions => _goalSuggestions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchGoalSuggestions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _goalSuggestions = await _goalSuggestionService.getGoalSuggestions();
    } catch (e) {
      // Handle error
      print(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
