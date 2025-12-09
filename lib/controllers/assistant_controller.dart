import 'package:flutter/foundation.dart';

import '../models/assistant_models.dart';
import '../services/assistant_service.dart';

class AssistantController extends ChangeNotifier {
  AssistantController({required AssistantService assistantService})
      : _assistantService = assistantService;

  final AssistantService _assistantService;

  bool _isLoading = false;
  String? _error;
  AssistantIntentResult? _lastIntent;
  DailyBriefingResult? _lastBriefing;
  NextActionResult? _lastNextAction;
  ModeDecisionResult? _lastModeDecision;
  NotificationTriageResult? _lastNotificationTriage;
  InboxIntelResult? _lastInboxIntel;
  WeeklyScheduleResult? _lastWeeklyPlan;
  MemorySearchResult? _lastMemorySearch;

  bool get isLoading => _isLoading;
  String? get error => _error;
  AssistantIntentResult? get lastIntent => _lastIntent;
  DailyBriefingResult? get lastBriefing => _lastBriefing;
  NextActionResult? get lastNextAction => _lastNextAction;
  ModeDecisionResult? get lastModeDecision => _lastModeDecision;
  NotificationTriageResult? get lastNotificationTriage =>
      _lastNotificationTriage;
  InboxIntelResult? get lastInboxIntel => _lastInboxIntel;
  WeeklyScheduleResult? get lastWeeklyPlan => _lastWeeklyPlan;
  MemorySearchResult? get lastMemorySearch => _lastMemorySearch;

  Future<AssistantIntentResult?> detectIntent(
      SmartIntentRequest request) async {
    return _run<AssistantIntentResult>(
      action: () => _assistantService.smartIntent(request),
      onSuccess: (result) => _lastIntent = result,
    );
  }

  Future<DailyBriefingResult?> fetchDailyBriefing(
    DailyBriefingRequest request,
  ) async {
    return _run<DailyBriefingResult>(
      action: () => _assistantService.dailyBriefing(request),
      onSuccess: (result) => _lastBriefing = result,
    );
  }

  Future<NextActionResult?> fetchNextAction(NextActionRequest request) async {
    return _run<NextActionResult>(
      action: () => _assistantService.nextAction(request),
      onSuccess: (result) => _lastNextAction = result,
    );
  }

  Future<ModeDecisionResult?> decideMode(ModeDecisionRequest request) async {
    return _run<ModeDecisionResult>(
      action: () => _assistantService.decideMode(request),
      onSuccess: (result) => _lastModeDecision = result,
    );
  }

  Future<NotificationTriageResult?> classifyNotifications(
    NotificationTriageRequest request,
  ) async {
    return _run<NotificationTriageResult>(
      action: () => _assistantService.classifyNotifications(request),
      onSuccess: (result) => _lastNotificationTriage = result,
    );
  }

  Future<InboxIntelResult?> inboxIntel(InboxIntelRequest request) async {
    return _run<InboxIntelResult>(
      action: () => _assistantService.inboxIntel(request),
      onSuccess: (result) => _lastInboxIntel = result,
    );
  }

  Future<WeeklyScheduleResult?> weeklySchedule(
    WeeklyScheduleRequest request,
  ) async {
    return _run<WeeklyScheduleResult>(
      action: () => _assistantService.weeklySchedule(request),
      onSuccess: (result) => _lastWeeklyPlan = result,
    );
  }

  Future<MemoryUpsertResult?> upsertMemory(MemoryUpsertRequest request) async {
    return _run<MemoryUpsertResult>(
      action: () => _assistantService.memoryUpsert(request),
    );
  }

  Future<MemorySearchResult?> searchMemory(MemorySearchRequest request) async {
    return _run<MemorySearchResult>(
      action: () => _assistantService.memorySearch(request),
      onSuccess: (result) => _lastMemorySearch = result,
    );
  }

  Future<T?> _run<T>({
    required Future<T> Function() action,
    void Function(T result)? onSuccess,
  }) async {
    if (_isLoading) return null;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await action();
      onSuccess?.call(result);
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
