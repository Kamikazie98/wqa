class AgentTask {
  AgentTask({
    required this.id,
    required this.title,
    required this.status,
    required this.language,
    required this.outline,
    required this.resultText,
    required this.createdAt,
    required this.updatedAt,
    required this.lastError,
    this.brief,
    this.audience,
    this.tone,
    this.wordCount,
  });

  final int id;
  final String title;
  final String status;
  final String language;
  final List<String> outline;
  final String? resultText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;
  final String? brief;
  final String? audience;
  final String? tone;
  final int? wordCount;

  bool get hasResult => resultText != null && resultText!.trim().isNotEmpty;

  factory AgentTask.fromJson(Map<String, dynamic> json) {
    final rawOutline = json['outline'] as List<dynamic>? ?? <dynamic>[];
    return AgentTask(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'تسک بدون عنوان',
      status: json['status']?.toString() ?? 'unknown',
      language: json['language']?.toString() ?? 'fa',
      outline: rawOutline.map((item) => item.toString()).toList(),
      resultText: json['result_text'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      lastError: json['last_error'] as String?,
      brief: json['brief'] as String?,
      audience: json['audience'] as String?,
      tone: json['tone'] as String?,
      wordCount: (json['word_count'] as num?)?.toInt(),
    );
  }
}
