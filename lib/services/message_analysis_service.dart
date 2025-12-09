
import 'package:flutter/material.dart';

import 'api_client.dart';

class MessageAnalysisService with ChangeNotifier {
  final ApiClient _api;
  bool _isLoading = false;
  String? _analysisResult;

  MessageAnalysisService(this._api);

  bool get isLoading => _isLoading;
  String? get analysisResult => _analysisResult;

  Future<void> analyzeMessage(String message) async {
    _isLoading = true;
    _analysisResult = null;
    notifyListeners();

    try {
      final response = await _api.postJson('/analyze-message', body: {'message': message});
      _analysisResult = response['analysis'];
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
