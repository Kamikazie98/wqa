import '../models/assistant_models.dart';
import 'api_client.dart';

class AssistantService {
  AssistantService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AssistantIntentResult> smartIntent(SmartIntentRequest request) async {
    final response = await _apiClient.postJson(
      '/assistant/intent',
      body: request.toJson(),
    );
    return AssistantIntentResult.fromJson(response);
  }

  Future<DailyBriefingResult> dailyBriefing(
      DailyBriefingRequest request) async {
    final response = await _apiClient.postJson(
      '/assistant/daily-briefing',
      body: request.toJson(),
    );
    return DailyBriefingResult.fromJson(response);
  }

  Future<NextActionResult> nextAction(NextActionRequest request) async {
    final response = await _apiClient.postJson(
      '/assistant/next-action',
      body: request.toJson(),
    );
    return NextActionResult.fromJson(response);
  }

  Future<ModeDecisionResult> decideMode(ModeDecisionRequest request) async {
    final response = await _apiClient.postJson(
      '/assistant/modes/decide',
      body: request.toJson(),
    );
    return ModeDecisionResult.fromJson(response);
  }

  Future<NotificationTriageResult> classifyNotifications(
    NotificationTriageRequest request,
  ) async {
    final response = await _apiClient.postJson(
      '/assistant/notifications/classify',
      body: request.toJson(),
    );
    return NotificationTriageResult.fromJson(response);
  }

  Future<InboxIntelResult> inboxIntel(InboxIntelRequest request) async {
    final response = await _apiClient.postJson(
      '/assistant/inbox/intel',
      body: request.toJson(),
    );
    return InboxIntelResult.fromJson(response);
  }

  Future<WeeklyScheduleResult> weeklySchedule(
      WeeklyScheduleRequest request) async {
    final response = await _apiClient.postJson(
      '/assistant/scheduler/weekly',
      body: request.toJson(),
    );
    return WeeklyScheduleResult.fromJson(response);
  }

  Future<MemoryUpsertResult> memoryUpsert(MemoryUpsertRequest request) async {
    final response = await _apiClient.postJson(
      '/assistant/memory/upsert',
      body: request.toJson(),
    );
    return MemoryUpsertResult.fromJson(response);
  }

  Future<MemorySearchResult> memorySearch(MemorySearchRequest request) async {
    final response = await _apiClient.postJson(
      '/assistant/memory/search',
      body: request.toJson(),
    );
    return MemorySearchResult.fromJson(response);
  }

  Future<SelfCarePlanResult> selfCarePlan(SelfCarePlanRequest request) async {
    final response = await _apiClient.postJson(
      '/assistant/selfcare/plan',
      body: request.toJson(),
    );
    return SelfCarePlanResult.fromJson(response);
  }
}
