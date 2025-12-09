import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../services/url_launcher_service.dart';

class MarkdownText extends StatelessWidget {
  const MarkdownText({
    super.key,
    required this.data,
    this.textColor,
    this.textAlign,
    this.padding = EdgeInsets.zero,
    this.maxLines,
  });

  final String data;
  final Color? textColor;
  final TextAlign? textAlign;
  final EdgeInsets padding;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final prettyJson = _toPrettyJson(data);
    if (prettyJson != null) {
      return Padding(
        padding: padding,
        child: SelectableText(
          prettyJson,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
        ),
      );
    }

    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: textColor ?? theme.textTheme.bodyMedium?.color,
      height: 1.6,
    );

    final content = Padding(
      padding: padding,
      child: MarkdownBody(
        data: data,
        selectable: true,
        softLineBreak: true,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: baseStyle,
          strong: baseStyle?.copyWith(fontWeight: FontWeight.w700),
          a: baseStyle?.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          blockquote: baseStyle?.copyWith(
            color: textColor ?? theme.colorScheme.onSurface,
          ),
        ),
        builders: maxLines != null
            ? {
                'p': _LimitedLinesBuilder(maxLines!),
              }
            : const {},
        onTapLink: (text, href, _) {
          if (href != null && href.isNotEmpty) {
            UrlLauncherService.openUrl(href);
          }
        },
      ),
    );

    if (textAlign == null) return content;
    return Align(
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : textAlign == TextAlign.right
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child: content,
    );
  }
}

class _LimitedLinesBuilder extends MarkdownElementBuilder {
  _LimitedLinesBuilder(this.maxLines);

  final int maxLines;

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) => Text(
        text.text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: preferredStyle,
      );
}

String? _toPrettyJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic> || decoded is List<dynamic>) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    }
  } catch (_) {
    // ignore parsing errors
  }
  return null;
}
