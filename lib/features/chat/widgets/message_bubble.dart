import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../models/chat_models.dart';
import '../../../widgets/markdown_text.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  final ChatMessage message;
  final bool isStreaming;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _caretController;

  @override
  void initState() {
    super.initState();
    _caretController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.15,
      upperBound: 1,
    );
    _toggleCaret();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    _toggleCaret();
  }

  @override
  void dispose() {
    _caretController.dispose();
    super.dispose();
  }

  bool get _isUser => widget.message.isUser;

  bool get _showTypingIndicator =>
      widget.isStreaming &&
      widget.message.isAssistant &&
      widget.message.content.isEmpty;

  bool get _showCaret =>
      widget.isStreaming &&
      widget.message.isAssistant &&
      widget.message.content.isNotEmpty;

  Color _textColor(ColorScheme colorScheme) {
    if (_isUser) return Colors.black.withOpacity(0.9);
    return Colors.white.withOpacity(0.95);
  }

  BoxDecoration _bubbleDecoration(ColorScheme colorScheme) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(_isUser ? 18 : 6),
      topRight: Radius.circular(_isUser ? 6 : 18),
      bottomLeft: const Radius.circular(18),
      bottomRight: const Radius.circular(18),
    );

    if (_isUser) {
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5AE8FF), Color(0xFF64D2FF)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      );
    }

    return BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: radius,
      border: Border.all(color: Colors.white.withOpacity(0.07)),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 12,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  void _toggleCaret() {
    if (_showCaret) {
      if (!_caretController.isAnimating) {
        _caretController.repeat(reverse: true);
      }
    } else {
      _caretController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = _textColor(colorScheme);
    final decoration = _bubbleDecoration(colorScheme);

    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: _isUser ? 48 : 0,
          right: _isUser ? 0 : 48,
        ),
        child: Row(
          mainAxisAlignment:
              _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!_isUser)
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            Flexible(
              child: GestureDetector(
                onLongPress: () => _showMessageActions(context),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 560),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: decoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_showTypingIndicator)
                          _TypingIndicator(color: textColor)
                        else
                          MarkdownText(
                            data: widget.message.content.isEmpty
                                ? '...'
                                : widget.message.content,
                            textColor: textColor,
                            textAlign:
                                _isUser ? TextAlign.right : TextAlign.left,
                          ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('HH:mm')
                                  .format(widget.message.createdAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: textColor.withOpacity(0.7)),
                            ),
                            if (widget.message.warning != null ||
                                widget.message.error != null)
                              Row(
                                children: [
                                  if (widget.message.warning != null) ...[
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.message.warning!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                  if (widget.message.error != null) ...[
                                    Icon(
                                      Icons.error_outline,
                                      size: 14,
                                      color: colorScheme.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.message.error!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.error,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                        if (_showCaret)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: FadeTransition(
                              opacity: _caretController,
                              child: Container(
                                width: 6,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: textColor.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.copy,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('کپی متن'),
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: widget.message.content),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('متن در کلیپ‌بورد کپی شد'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.share,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('اشتراک‌گذاری'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement share functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('قابلیت اشتراک‌گذاری به زودی اضافه می‌شود'),
                    ),
                  );
                },
              ),
              if (!_isUser)
                ListTile(
                  leading: Icon(
                    Icons.refresh,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('تولید مجدد'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement regenerate functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('قابلیت تولید مجدد به زودی اضافه می‌شود'),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.color});

  final Color color;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _dotAnimations = List.generate(
      3,
      (index) => CurvedAnimation(
        parent: _controller,
        curve: Interval(
          index * 0.15,
          0.6 + index * 0.15,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
            child: FadeTransition(
              opacity: _dotAnimations[index],
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
