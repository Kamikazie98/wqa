import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// دکمه بهبود یافته با haptic feedback و animations
class ImprovedButton extends StatefulWidget {
  const ImprovedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.variant = ButtonVariant.elevated,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final ButtonVariant variant;
  final bool loading;

  @override
  State<ImprovedButton> createState() => _ImprovedButtonState();
}

enum ButtonVariant { elevated, filled, outlined, text }

class _ImprovedButtonState extends State<ImprovedButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.loading) {
      HapticFeedback.lightImpact();
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
      widget.onPressed?.call();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  Widget _buildButton() {
    final child = widget.loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18),
                const SizedBox(width: 8),
              ],
              widget.child,
            ],
          );

    Widget button;
    switch (widget.variant) {
      case ButtonVariant.elevated:
        button = ElevatedButton(
          onPressed: widget.loading ? null : widget.onPressed,
          child: child,
        );
        break;
      case ButtonVariant.filled:
        button = FilledButton(
          onPressed: widget.loading ? null : widget.onPressed,
          child: child,
        );
        break;
      case ButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: widget.loading ? null : widget.onPressed,
          child: child,
        );
        break;
      case ButtonVariant.text:
        button = TextButton(
          onPressed: widget.loading ? null : widget.onPressed,
          child: child,
        );
        break;
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: button,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: _buildButton(),
    );
  }
}
