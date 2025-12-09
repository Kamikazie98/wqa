
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/chat_models.dart';
import '../models/daily_program_models.dart';
import '../models/user_models.dart';
import 'exceptions.dart';

typedef TokenProvider = String? Function();

class ApiClient {
  ApiClient({required this.tokenProvider, http.Client? client})
      : _client = client ?? http.Client();

  static const _baseUrl = 'https://wqai.morvism.ir';

  final TokenProvider tokenProvider;
  final http.Client _client;

  Uri _uri(
    String path, {
    Map<String, dynamic>? query,
  }) {
    if (path.startsWith('https')) {
      return Uri.parse(path);
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalized');
    if (query == null || query.isEmpty) {
      return uri;
    }
    final queryParams = <String, String>{
      ...uri.queryParameters,
      ...query.map(
        (key, value) => MapEntry(key, value == null ? '' : value.toString()),
      ),
    };
    return uri.replace(queryParameters: queryParams);
  }

  Map<String, String> _headers({
    required bool authRequired,
    Map<String, String>? extraHeaders,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authRequired) {
      final token = tokenProvider();
      if (token == null) {
        throw const ApiException('برای این درخواست باید وارد شوید.');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.get(
      _uri(path, query: query),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.put(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.delete(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> postJsonRaw(
    String path,
    String rawBody, {
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
      body: rawBody,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.put(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool authRequired = true,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _client.delete(
      _uri(path),
      headers: _headers(authRequired: authRequired, extraHeaders: extraHeaders),
    );
    return _handleResponse(response);
  }

  Stream<ChatSseEvent> streamChat(ChatRequest request) async* {
    final httpRequest = http.Request('POST', _uri('/chat/stream'))
      ..headers.addAll(
        _headers(authRequired: true)..['Accept'] = 'text/event-stream',
      )
      ..body = jsonEncode(request.toJson());

    final streamedResponse = await _client.send(httpRequest);
    if (streamedResponse.statusCode >= 400) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw ApiException(
        _extractErrorMessage(errorBody) ?? 'ارتباط با سرور برقرار نشد.',
        statusCode: streamedResponse.statusCode,
      );
    }

    final stream = streamedResponse.stream.transform(utf8.decoder).transform(
          const LineSplitter(),
        );
    String? currentEvent;
    final buffer = StringBuffer();

    await for (final line in stream) {
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        buffer.writeln(line.substring(5).trim());
      } else if (line.trim().isEmpty) {
        if (buffer.isNotEmpty) {
          final data = buffer.toString().trim();
          yield ChatSseEvent.fromEvent(currentEvent ?? 'message', data);
          buffer.clear();
        }
        currentEvent = null;
      }
    }
    if (buffer.isNotEmpty) {
      yield ChatSseEvent.fromEvent(
          currentEvent ?? 'message', buffer.toString());
    }
  }

  Stream<ChatSseEvent> streamChatWithFiles(
    ChatRequest request,
    List<String> filePaths, {
    String path = '/chat/stream/form',
  }) async* {
    final payload = jsonEncode(request.toJson());
    final multipart = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(
        _headers(authRequired: true)..['Accept'] = 'text/event-stream',
      )
      ..fields['payload'] = payload;

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ApiException('فایل یافت نشد: $filePath');
      }
      multipart.files.add(await http.MultipartFile.fromPath('files', filePath));
    }

    final streamedResponse = await multipart.send();
    if (streamedResponse.statusCode >= 400) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw ApiException(
        _extractErrorMessage(errorBody) ?? 'در ارسال فایل/پیام خطا رخ داد.',
        statusCode: streamedResponse.statusCode,
      );
    }

    final stream = streamedResponse.stream.transform(utf8.decoder).transform(
          const LineSplitter(),
        );
    String? currentEvent;
    final buffer = StringBuffer();

    await for (final line in stream) {
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        buffer.writeln(line.substring(5).trim());
      } else if (line.trim().isEmpty) {
        if (buffer.isNotEmpty) {
          final data = buffer.toString().trim();
          yield ChatSseEvent.fromEvent(currentEvent ?? 'message', data);
          buffer.clear();
        }
        currentEvent = null;
      }
    }
    if (buffer.isNotEmpty) {
      yield ChatSseEvent.fromEvent(
          currentEvent ?? 'message', buffer.toString());
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) {
        return <String, dynamic>{};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    }

    final message = _extractErrorMessage(response.body) ??
        'خطای غیرمنتظره (${response.statusCode})';
    throw ApiException(message, statusCode: status);
  }

  String? _extractErrorMessage(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            body;
      }
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first.toString();
      }
    } catch (_) {
      // ignore json error
    }
    return body;
  }

  Future<List<Map<String, String>>> getSuggestedPrompts({
    String? category,
    String language = 'fa',
    int limit = 5,
  }) async {
    final query = <String, String>{
      if (category != null) 'category': category,
      'language': language,
      'limit': limit.toString(),
    };

    final response = await getJson(
      '/chat/suggested-prompts',
      query: query,
    );

    final prompts = response['prompts'] as List<dynamic>? ?? [];
    return prompts
        .map((item) => Map<String, String>.from(item as Map))
        .toList();
  }

  Future<UserProfile> setupUserProfile(UserProfile userProfile) async {
    final response = await postJson('/user/profile/setup', body: userProfile.toJson());
    return UserProfile.fromJson(response);
  }

  Future<UserProfile> getUserProfile() async {
    final response = await getJson('/user/profile');
    return UserProfile.fromJson(response);
  }

  Future<UserProfile> updateUserProfile(UserProfile userProfile) async {
    final response = await putJson('/user/profile/update', body: userProfile.toJson());
    return UserProfile.fromJson(response);
  }

  Future<UserGoal> createGoal(UserGoal goal) async {
    final response = await postJson('/user/goals', body: goal.toJson());
    return UserGoal.fromJson(response);
  }

  Future<List<UserGoal>> getGoals() async {
    final response = await getJson('/user/goals');
    return (response['goals'] as List<dynamic>)
        .map((g) => UserGoal.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<UserGoal> updateGoal(String goalId, Map<String, dynamic> data) async {
    final response = await putJson('/user/goals/$goalId', body: data);
    return UserGoal.fromJson(response);
  }

  Future<void> deleteGoal(String goalId) async {
    await deleteJson('/user/goals/$goalId');
  }

  Future<void> completeGoal(String goalId) async {
    await postJson('/user/goals/$goalId/complete');
  }

  Future<void> linkTaskToGoal(String goalId, String taskId) async {
    await postJson('/user/goals/$goalId/link-task', body: {'task_id': taskId});
  }

  Future<void> unlinkTaskFromGoal(String goalId, String taskId) async {
    await postJson('/user/goals/$goalId/unlink-task', body: {'task_id': taskId});
  }

  Future<GoalMilestone> addMilestone(String goalId, GoalMilestone milestone) async {
    final response = await postJson('/user/goals/$goalId/milestones', body: milestone.toJson());
    return GoalMilestone.fromJson(response);
  }

  Future<GoalMilestone> updateMilestone(String goalId, String milestoneId, Map<String, dynamic> data) async {
    final response = await putJson('/user/goals/$goalId/milestones/$milestoneId', body: data);
    return GoalMilestone.fromJson(response);
  }

  Future<List<Map<String, dynamic>>> getGoalProgressHistory(String goalId) async {
    final response = await getJson('/user/goals/$goalId/progress-history');
    return List<Map<String, dynamic>>.from(response['history']);
  }

  Future<Habit> createHabit(Habit habit) async {
    final response = await postJson('/habits', body: habit.toJson());
    return Habit.fromJson(response);
  }

  Future<List<Habit>> getHabits() async {
    final response = await getJson('/habits');
    return (response['habits'] as List<dynamic>)
        .map((h) => Habit.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  Future<Habit> getHabit(String habitId) async {
    final response = await getJson('/habits/$habitId');
    return Habit.fromJson(response);
  }

  Future<void> logHabitCompletion(String habitId, Map<String, dynamic> data) async {
    await postJson('/habits/$habitId/log', body: data);
  }

  Future<Habit> updateHabit(String habitId, Map<String, dynamic> data) async {
    final response = await putJson('/habits/$habitId', body: data);
    return Habit.fromJson(response);
  }

  Future<void> deleteHabit(String habitId) async {
    await deleteJson('/habits/$habitId');
  }

  Future<MoodSnapshot> recordMood(MoodSnapshot snapshot) async {
    final response = await postJson('/user/mood/snapshot', body: snapshot.toJson());
    return MoodSnapshot.fromJson(response);
  }

  Future<List<MoodSnapshot>> getMoodHistory() async {
    final response = await getJson('/user/mood/history');
    return (response['snapshots'] as List<dynamic>)
        .map((s) => MoodSnapshot.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<DailyProgram> generateDailyProgram(Map<String, dynamic> data) async {
    final response = await postJson('/user/program/generate', body: data);
    return DailyProgram.fromJson(response);
  }

  Future<DailyProgram> getProgramForDate(String date) async {
    final response = await getJson('/user/program/$date');
    return DailyProgram.fromJson(response);
  }

  Future<DailyProgram> getTodayProgram() async {
    final response = await getJson('/user/program/today');
    return DailyProgram.fromJson(response);
  }

  Future<void> completeActivity(String activityId, bool completed) async {
    await postJson('/user/program/activity/$activityId/complete', body: {'completed': completed});
  }

  Future<void> rescheduleActivity(String activityId, DateTime newTime) async {
    await putJson('/user/program/activity/$activityId/reschedule', body: {'new_time': newTime.toIso8601String()});
  }

  Future<Map<String, dynamic>> addCustomActivity(ProgramActivity activity) async {
    return await postJson('/user/program/activity/add', body: activity.toJson());
  }

  Future<void> deleteActivity(String activityId) async {
    await deleteJson('/user/program/activity/$activityId');
  }

  Future<SchedulingAnalysis> analyzeScheduling() async {
    final response = await postJson('/user/scheduling/analyze');
    return SchedulingAnalysis.fromJson(response);
  }

  Future<List<SchedulingRecommendation>> getSchedulingRecommendations() async {
    final response = await getJson('/user/scheduling/recommendations');
    return (response['recommendations'] as List<dynamic>)
        .map((r) => SchedulingRecommendation.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<UserTask> createTask(UserTask task) async {
    final response = await postJson('/tasks', body: task.toJson());
    return UserTask.fromJson(response);
  }

  Future<List<UserTask>> getTasks({String? status, String? category}) async {
    final query = <String, String>{};
    if (status != null) {
      query['status'] = status;
    }
    if (category != null) {
      query['category'] = category;
    }
    final response = await getJson('/tasks', query: query);
    return (response['tasks'] as List<dynamic>)
        .map((t) => UserTask.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<UserTask> getTask(String taskId) async {
    final response = await getJson('/tasks/$taskId');
    return UserTask.fromJson(response);
  }

  Future<UserTask> updateTask(String taskId, Map<String, dynamic> data) async {
    final response = await putJson('/tasks/$taskId', body: data);
    return UserTask.fromJson(response);
  }

  Future<void> deleteTask(String taskId) async {
    await deleteJson('/tasks/$taskId');
  }

  Future<void> completeTask(String taskId) async {
    await postJson('/tasks/$taskId/complete');
  }

  Future<UserTask> createRecurringTask(Map<String, dynamic> data) async {
    final response = await postJson('/tasks/recurring', body: data);
    return UserTask.fromJson(response);
  }

  void close() {
    _client.close();
  }

  Future<String> uploadFile(String filePath) async {
    final uri = _uri('/files/upload');
    final file = File(filePath);
    if (!await file.exists()) {
      throw const ApiException('فایل پیدا نشد.');
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(authRequired: true))
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          final url =
              decoded['url']?.toString() ?? decoded['file_url']?.toString();
          if (url != null && url.isNotEmpty) {
            return url;
          }
        }
      } catch (_) {
        // fall through to error
      }
      throw const ApiException('پاسخ نامعتبر از سرور برای آپلود فایل.');
    }
    final message = _extractErrorMessage(body) ?? 'آپلود فایل ناموفق بود';
    throw ApiException(message, statusCode: streamed.statusCode);
  }
}
