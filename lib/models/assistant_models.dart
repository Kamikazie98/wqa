typedef JsonMap = Map<String, dynamic>;

enum SmartAction {
  reminder,
  followUp,
  sendMessage,
  call,
  openApp,
  openLink,
  openCamera,
  openGallery,
  calendarEvent,
  webSearch,
  note,
  modeSwitch,
  notificationTriage,
  memoryUpsert,
  routine,
  automation,
  suggestion,
  dailyBriefing,
}

SmartAction smartActionFromString(String raw) {
  switch (raw) {
    case 'reminder':
      return SmartAction.reminder;
    case 'follow_up':
    case 'followUp':
      return SmartAction.followUp;
    case 'send_message':
      return SmartAction.sendMessage;
    case 'call':
      return SmartAction.call;
    case 'open_app':
      return SmartAction.openApp;
    case 'open_link':
      return SmartAction.openLink;
    case 'open_camera':
      return SmartAction.openCamera;
    case 'open_gallery':
      return SmartAction.openGallery;
    case 'calendar_event':
      return SmartAction.calendarEvent;
    case 'web_search':
      return SmartAction.webSearch;
    case 'note':
      return SmartAction.note;
    case 'mode_switch':
      return SmartAction.modeSwitch;
    case 'notification_triage':
      return SmartAction.notificationTriage;
    case 'memory_upsert':
      return SmartAction.memoryUpsert;
    case 'routine':
      return SmartAction.routine;
    case 'automation':
      return SmartAction.automation;
    case 'daily_briefing':
      return SmartAction.dailyBriefing;
    case 'suggestion':
    default:
      return SmartAction.suggestion;
  }
}

String smartActionToString(SmartAction action) {
  switch (action) {
    case SmartAction.reminder:
      return 'reminder';
    case SmartAction.followUp:
      return 'follow_up';
    case SmartAction.sendMessage:
      return 'send_message';
    case SmartAction.call:
      return 'call';
    case SmartAction.openApp:
      return 'open_app';
    case SmartAction.openLink:
      return 'open_link';
    case SmartAction.openCamera:
      return 'open_camera';
    case SmartAction.openGallery:
      return 'open_gallery';
    case SmartAction.calendarEvent:
      return 'calendar_event';
    case SmartAction.webSearch:
      return 'web_search';
    case SmartAction.note:
      return 'note';
    case SmartAction.modeSwitch:
      return 'mode_switch';
    case SmartAction.notificationTriage:
      return 'notification_triage';
    case SmartAction.memoryUpsert:
      return 'memory_upsert';
    case SmartAction.routine:
      return 'routine';
    case SmartAction.automation:
      return 'automation';
    case SmartAction.dailyBriefing:
      return 'daily_briefing';
    case SmartAction.suggestion:
      return 'suggestion';
  }
}

class SmartIntentRequest {
  SmartIntentRequest({
    required this.text,
    required this.timezone,
    required this.now,
    this.mode = 'default',
    this.energy = 'normal',
    Map<String, dynamic>? context,
  }) : context = context ?? <String, dynamic>{};

  final String text;
  final String timezone;
  final DateTime now;
  final String mode;
  final String energy;
  final Map<String, dynamic> context;

  JsonMap toJson() {
    return <String, dynamic>{
      'text': text,
      'timezone': timezone,
      'now': now.toIso8601String(),
      'mode': mode,
      'energy': energy,
      'context': context,
    };
  }
}

class AssistantIntentResult {
  AssistantIntentResult({
    required this.action,
    required this.payload,
    this.rawText,
  });

  final SmartAction action;
  final JsonMap payload;
  final String? rawText;

  factory AssistantIntentResult.fromJson(JsonMap json) {
    final payload =
        (json['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return AssistantIntentResult(
      action: smartActionFromString(json['action']?.toString() ?? 'suggestion'),
      payload: payload,
      rawText: json['raw_text'] as String?,
    );
  }
}

class DailyBriefingRequest {
  DailyBriefingRequest({
    required this.timezone,
    required this.now,
    this.tasks = const <dynamic>[],
    this.messages = const <dynamic>[],
    this.energy = 'normal',
    this.sleep,
    Map<String, dynamic>? context,
  }) : context = context ?? <String, dynamic>{};

  final String timezone;
  final DateTime now;
  final List<dynamic> tasks;
  final List<dynamic> messages;
  final String energy;
  final String? sleep;
  final Map<String, dynamic> context;

  JsonMap toJson() {
    return <String, dynamic>{
      'timezone': timezone,
      'now': now.toIso8601String(),
      'tasks': tasks,
      'messages': messages,
      'energy': energy,
      if (sleep != null) 'sleep': sleep,
      'context': context,
    };
  }
}

class DailyBriefingPayload {
  DailyBriefingPayload({
    required this.briefing,
    this.highlights = const <String>[],
    this.nextActions = const <String>[],
    this.reminders = const <String>[],
    this.tone = 'friendly',
  });

  final String briefing;
  final List<String> highlights;
  final List<String> nextActions;
  final List<String> reminders;
  final String tone;

  factory DailyBriefingPayload.fromJson(JsonMap json) {
    return DailyBriefingPayload(
      briefing: json['briefing']?.toString() ?? '',
      highlights: List<String>.from(json['highlights'] as List? ?? <String>[]),
      nextActions:
          List<String>.from(json['next_actions'] as List? ?? <String>[]),
      reminders: List<String>.from(json['reminders'] as List? ?? <String>[]),
      tone: json['tone']?.toString() ?? 'friendly',
    );
  }
}

class DailyBriefingResult {
  DailyBriefingResult({
    required this.payload,
    this.rawText,
  });

  final DailyBriefingPayload payload;
  final String? rawText;

  factory DailyBriefingResult.fromJson(JsonMap json) {
    final payload =
        json['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return DailyBriefingResult(
      payload: DailyBriefingPayload.fromJson(payload),
      rawText: json['raw_text'] as String?,
    );
  }
}

class NextActionRequest {
  NextActionRequest({
    required this.availableMinutes,
    this.energy = 'normal',
    this.mode = 'default',
    this.tasks = const <dynamic>[],
    Map<String, dynamic>? context,
  }) : context = context ?? <String, dynamic>{};

  final int availableMinutes;
  final String energy;
  final String mode;
  final List<dynamic> tasks;
  final Map<String, dynamic> context;

  JsonMap toJson() {
    return <String, dynamic>{
      'available_minutes': availableMinutes,
      'energy': energy,
      'mode': mode,
      'tasks': tasks,
      'context': context,
    };
  }
}

class NextActionSuggestion {
  NextActionSuggestion({
    required this.title,
    required this.reason,
    this.durationEstimateMin,
  });

  final String title;
  final String reason;
  final int? durationEstimateMin;

  factory NextActionSuggestion.fromJson(JsonMap json) {
    return NextActionSuggestion(
      title: json['title']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      durationEstimateMin: json['duration_estimate_min'] as int?,
    );
  }
}

class NextActionResult {
  NextActionResult({
    required this.suggested,
    this.alternatives = const <NextActionSuggestion>[],
    this.rawText,
  });

  final NextActionSuggestion suggested;
  final List<NextActionSuggestion> alternatives;
  final String? rawText;

  factory NextActionResult.fromJson(JsonMap json) {
    final payload =
        (json['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final alternatives =
        payload['alternatives'] as List<dynamic>? ?? <dynamic>[];
    return NextActionResult(
      suggested: NextActionSuggestion.fromJson(
        payload['suggested'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      alternatives: alternatives
          .map((item) => NextActionSuggestion.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      rawText: json['raw_text'] as String?,
    );
  }
}

class ModeDecisionRequest {
  ModeDecisionRequest({
    required this.text,
    required this.timezone,
    required this.now,
    this.mode = 'default',
    this.energy = 'normal',
    Map<String, dynamic>? context,
  }) : context = context ?? <String, dynamic>{};

  final String text;
  final String timezone;
  final DateTime now;
  final String mode;
  final String energy;
  final Map<String, dynamic> context;

  JsonMap toJson() {
    return <String, dynamic>{
      'text': text,
      'timezone': timezone,
      'now': now.toIso8601String(),
      'mode': mode,
      'energy': energy,
      'context': context,
    };
  }
}

class ModeDecisionResult {
  ModeDecisionResult({
    required this.mode,
    required this.reason,
    this.triggers = const <String>[],
    this.rawText,
  });

  final String mode;
  final String reason;
  final List<String> triggers;
  final String? rawText;

  factory ModeDecisionResult.fromJson(JsonMap json) {
    final payload =
        json['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return ModeDecisionResult(
      mode: payload['mode']?.toString() ?? 'default',
      reason: payload['reason']?.toString() ?? '',
      triggers: List<String>.from(payload['triggers'] as List? ?? <String>[]),
      rawText: json['raw_text'] as String?,
    );
  }
}

class NotificationTriageRequest {
  NotificationTriageRequest({
    required this.notifications,
    required this.mode,
    required this.timezone,
    Map<String, dynamic>? context,
  }) : context = context ?? <String, dynamic>{};

  final List<JsonMap> notifications;
  final String mode;
  final String timezone;
  final Map<String, dynamic> context;

  JsonMap toJson() {
    return <String, dynamic>{
      'notifications': notifications,
      'mode': mode,
      'timezone': timezone,
      'context': context,
    };
  }
}

class ClassifiedNotification {
  ClassifiedNotification({
    required this.title,
    required this.category,
    required this.suggestedAction,
  });

  final String title;
  final String category;
  final String suggestedAction;

  factory ClassifiedNotification.fromJson(JsonMap json) {
    return ClassifiedNotification(
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'normal',
      suggestedAction: json['suggested_action']?.toString() ?? '',
    );
  }
}

class NotificationTriageResult {
  NotificationTriageResult({
    required this.classified,
    this.summary,
    this.rawText,
  });

  final List<ClassifiedNotification> classified;
  final String? summary;
  final String? rawText;

  factory NotificationTriageResult.fromJson(JsonMap json) {
    final payload =
        json['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final classified = payload['classified'] as List<dynamic>? ?? <dynamic>[];
    return NotificationTriageResult(
      classified: classified
          .map((item) => ClassifiedNotification.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      summary: payload['summary']?.toString(),
      rawText: json['raw_text'] as String?,
    );
  }
}

class InboxIntelRequest {
  InboxIntelRequest({
    required this.message,
    required this.channel,
    Map<String, dynamic>? context,
  }) : context = context ?? <String, dynamic>{};

  final String message;
  final String channel;
  final Map<String, dynamic> context;

  JsonMap toJson() {
    return <String, dynamic>{
      'message': message,
      'channel': channel,
      'context': context,
    };
  }
}

class InboxIntelAction {
  InboxIntelAction({
    required this.type,
    required this.suggestedText,
    this.when,
  });

  final String type;
  final String suggestedText;
  final String? when;

  factory InboxIntelAction.fromJson(JsonMap json) {
    return InboxIntelAction(
      type: json['type']?.toString() ?? '',
      suggestedText: json['suggested_text']?.toString() ?? '',
      when: json['when']?.toString(),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'type': type,
      'suggested_text': suggestedText,
      if (when != null) 'when': when,
    };
  }
}

class InboxIntelResult {
  InboxIntelResult({
    required this.summary,
    this.actions = const <InboxIntelAction>[],
    this.rawText,
  });

  final String summary;
  final List<InboxIntelAction> actions;
  final String? rawText;

  factory InboxIntelResult.fromJson(JsonMap json) {
    final payload =
        json['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final actions = payload['actions'] as List<dynamic>? ?? <dynamic>[];
    return InboxIntelResult(
      summary: payload['summary']?.toString() ?? '',
      actions: actions
          .map((item) => InboxIntelAction.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      rawText: json['raw_text'] as String?,
    );
  }
}

class WeeklyScheduleRequest {
  WeeklyScheduleRequest({
    required this.goals,
    required this.hardEvents,
    required this.timezone,
    required this.now,
    Map<String, dynamic>? context,
  }) : context = context ?? <String, dynamic>{};

  final List<String> goals;
  final List<JsonMap> hardEvents;
  final String timezone;
  final DateTime now;
  final Map<String, dynamic> context;

  JsonMap toJson() {
    return <String, dynamic>{
      'goals': goals,
      'hard_events': hardEvents,
      'timezone': timezone,
      'now': now.toIso8601String(),
      'context': context,
    };
  }
}

class WeeklyPlanItem {
  WeeklyPlanItem({
    required this.title,
    required this.day,
    required this.start,
    required this.end,
    required this.reason,
  });

  final String title;
  final String day;
  final String start;
  final String end;
  final String reason;

  factory WeeklyPlanItem.fromJson(JsonMap json) {
    return WeeklyPlanItem(
      title: json['title']?.toString() ?? '',
      day: json['day']?.toString() ?? '',
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'title': title,
      'day': day,
      'start': start,
      'end': end,
      'reason': reason,
    };
  }
}

class WeeklyScheduleResult {
  WeeklyScheduleResult({
    required this.plan,
    this.conflicts = const <String>[],
    this.notes,
    this.rawText,
  });

  final List<WeeklyPlanItem> plan;
  final List<String> conflicts;
  final String? notes;
  final String? rawText;

  factory WeeklyScheduleResult.fromJson(JsonMap json) {
    final payload =
        json['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final plan = payload['plan'] as List<dynamic>? ?? <dynamic>[];
    return WeeklyScheduleResult(
      plan: plan
          .map((item) => WeeklyPlanItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      conflicts: List<String>.from(payload['conflicts'] as List? ?? <String>[]),
      notes: payload['notes']?.toString(),
      rawText: json['raw_text'] as String?,
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'payload': <String, dynamic>{
        'plan': plan.map((e) => e.toJson()).toList(),
        'conflicts': conflicts,
        if (notes != null) 'notes': notes,
      },
      if (rawText != null) 'raw_text': rawText,
    };
  }
}

class MemoryUpsertRequest {
  MemoryUpsertRequest({
    required this.facts,
    required this.key,
  });

  final List<String> facts;
  final String key;

  JsonMap toJson() {
    return <String, dynamic>{
      'facts': facts,
      'key': key,
    };
  }
}

class MemoryUpsertResult {
  MemoryUpsertResult({required this.saved});

  final int saved;

  factory MemoryUpsertResult.fromJson(JsonMap json) {
    return MemoryUpsertResult(
      saved: json['saved'] as int? ?? 0,
    );
  }
}

class MemorySearchRequest {
  MemorySearchRequest({
    required this.query,
    this.limit = 5,
  });

  final String query;
  final int limit;

  JsonMap toJson() {
    return <String, dynamic>{
      'query': query,
      'limit': limit,
    };
  }
}

class MemoryItem {
  MemoryItem({
    required this.id,
    required this.key,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String key;
  final String content;
  final DateTime createdAt;

  factory MemoryItem.fromJson(JsonMap json) {
    return MemoryItem(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class MemorySearchResult {
  MemorySearchResult({this.items = const <MemoryItem>[]});

  final List<MemoryItem> items;

  factory MemorySearchResult.fromJson(JsonMap json) {
    final items = json['items'] as List<dynamic>? ?? <dynamic>[];
    return MemorySearchResult(
      items: items
          .map((item) => MemoryItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }
}

class SelfCarePlanRequest {
  SelfCarePlanRequest({
    required this.name,
    required this.traits,
    required this.durationDays,
    Map<String, dynamic>? context,
  }) : context = context ?? <String, dynamic>{};

  final String name;
  final List<String> traits;
  final int durationDays;
  final Map<String, dynamic> context;

  JsonMap toJson() {
    return <String, dynamic>{
      'name': name,
      'traits': traits,
      'duration_days': durationDays,
      'context': context,
    };
  }
}

class SelfCarePlanItem {
  SelfCarePlanItem({
    required this.day,
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.reminder,
  });

  final int day;
  final String morning;
  final String afternoon;
  final String evening;
  final String reminder;

  factory SelfCarePlanItem.fromJson(JsonMap json) {
    return SelfCarePlanItem(
      day: (json['day'] as num?)?.toInt() ?? 0,
      morning: json['morning']?.toString() ?? '',
      afternoon: json['afternoon']?.toString() ?? '',
      evening: json['evening']?.toString() ?? '',
      reminder: json['reminder']?.toString() ?? '',
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'day': day,
      'morning': morning,
      'afternoon': afternoon,
      'evening': evening,
      'reminder': reminder,
    };
  }
}

class SelfCarePlanResult {
  SelfCarePlanResult({
    required this.profileName,
    required this.summary,
    required this.plan,
    this.actions = const <InboxIntelAction>[],
  });

  final String profileName;
  final String summary;
  final List<SelfCarePlanItem> plan;
  final List<InboxIntelAction> actions;

  factory SelfCarePlanResult.fromJson(JsonMap json) {
    final payload =
        json['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final plan = payload['plan'] as List<dynamic>? ?? <dynamic>[];
    final actions = payload['actions'] as List<dynamic>? ?? <dynamic>[];
    return SelfCarePlanResult(
      profileName: payload['profile_name']?.toString() ?? 'Plan',
      summary: payload['summary']?.toString() ?? '',
      plan: plan
          .map((item) =>
              SelfCarePlanItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      actions: actions
          .map((item) =>
              InboxIntelAction.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'profile_name': profileName,
      'summary': summary,
      'plan': plan.map((item) => item.toJson()).toList(),
      'actions': actions.map((item) => item.toJson()).toList(),
    };
  }
}
