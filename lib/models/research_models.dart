import 'dart:convert';

class ResearchSource {
  const ResearchSource({required this.title, required this.url});

  final String title;
  final String url;

  factory ResearchSource.fromJson(Map<String, dynamic> json) {
    return ResearchSource(
      title: json['title']?.toString() ?? 'منبع بدون عنوان',
      url: json['url']?.toString() ?? '',
    );
  }
}

class DeepResearchSection {
  DeepResearchSection({
    required this.title,
    required this.summary,
    required this.takeaways,
    required this.sources,
  });

  final String title;
  final String summary;
  final List<String> takeaways;
  final List<ResearchSource> sources;

  factory DeepResearchSection.fromJson(Map<String, dynamic> json) {
    final rawTakeaways = json['takeaways'] as List<dynamic>? ?? <dynamic>[];
    final rawSources = json['sources'] as List<dynamic>? ?? <dynamic>[];
    return DeepResearchSection(
      title: json['title']?.toString() ?? 'بخش بدون عنوان',
      summary: json['summary']?.toString() ?? '',
      takeaways: rawTakeaways.map((item) => item.toString()).toList(),
      sources: rawSources
          .map((item) => ResearchSource.fromJson(
                Map<String, dynamic>.from(item as Map<String, dynamic>),
              ))
          .toList(),
    );
  }
}

class DeepResearchResult {
  DeepResearchResult({
    required this.query,
    required this.depth,
    required this.summary,
    required this.sections,
    required this.outline,
    required this.sources,
    required this.rawText,
  });

  final String query;
  final String depth;
  final String summary;
  final List<DeepResearchSection> sections;
  final List<String> outline;
  final List<ResearchSource> sources;
  final String rawText;

  bool get hasSections => sections.isNotEmpty;
  bool get hasOutline => outline.isNotEmpty;
  bool get hasSources => sources.isNotEmpty;

  factory DeepResearchResult.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? <dynamic>[];
    final rawOutline = json['outline'] as List<dynamic>? ?? <dynamic>[];
    final rawSources = json['sources'] as List<dynamic>? ?? <dynamic>[];
    final rawSummary = json['summary']?.toString() ?? '';
    final parsedDump = _parseStructuredDump(
        json, rawSummary, rawSections, rawOutline, rawSources);

    return DeepResearchResult(
      query: json['query']?.toString() ?? '',
      depth: json['depth']?.toString() ?? '',
      summary: parsedDump['summary']?.toString() ?? rawSummary,
      sections: (parsedDump['sections'] as List<dynamic>? ?? rawSections)
          .map((item) => DeepResearchSection.fromJson(
                Map<String, dynamic>.from(item as Map<String, dynamic>),
              ))
          .toList(),
      outline: (parsedDump['outline'] as List<dynamic>? ?? rawOutline)
          .map((item) => item.toString())
          .toList(),
      sources: (parsedDump['sources'] as List<dynamic>? ?? rawSources)
          .map((item) => ResearchSource.fromJson(
                Map<String, dynamic>.from(item as Map<String, dynamic>),
              ))
          .toList(),
      rawText: json['raw_text']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _parseStructuredDump(
    Map<String, dynamic> json,
    String rawSummary,
    List<dynamic> rawSections,
    List<dynamic> rawOutline,
    List<dynamic> rawSources,
  ) {
    if (rawSections.isNotEmpty ||
        rawOutline.isNotEmpty ||
        rawSources.isNotEmpty) {
      return {
        'summary': rawSummary,
        'sections': rawSections,
        'outline': rawOutline,
        'sources': rawSources
      };
    }

    final rawText = json['raw_text']?.toString() ?? '';
    final candidate = _cleanDump(rawSummary).isNotEmpty
        ? _cleanDump(rawSummary)
        : _cleanDump(rawText);
    if (candidate.isEmpty || !_looksLikeDump(candidate)) {
      return {
        'summary': rawSummary,
        'sections': rawSections,
        'outline': rawOutline,
        'sources': rawSources
      };
    }

    final decoded = _tryDecode(candidate);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {
      'summary': rawSummary,
      'sections': rawSections,
      'outline': rawOutline,
      'sources': rawSources
    };
  }

  static bool _looksLikeDump(String text) {
    final t = text.trimLeft();
    return t.startsWith('{') || t.startsWith('[') || t.contains('"summary"');
  }

  static String _cleanDump(String text) {
    final fence = RegExp(r'```[a-zA-Z]*\\s*([\\s\\S]*?)```', multiLine: true);
    final match = fence.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim() ?? text;
    }
    return text.trim();
  }

  static Object? _tryDecode(String text) {
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}
