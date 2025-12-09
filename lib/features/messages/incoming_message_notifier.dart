import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/message_reader_service.dart';
import '../../models/message_models.dart';

/// ویجت برای دریافت و نمایش پیام‌های جدید
class IncomingMessageNotifier extends StatefulWidget {
  final Widget child;

  const IncomingMessageNotifier({
    super.key,
    required this.child,
  });

  @override
  State<IncomingMessageNotifier> createState() =>
      _IncomingMessageNotifierState();
}

class _IncomingMessageNotifierState extends State<IncomingMessageNotifier>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isVisible = false;
  Message? _newMessage;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    // تنظیم listener برای پیام‌های جدید
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messageService =
          Provider.of<MessageReaderService>(context, listen: false);
      messageService.messageStream.listen((message) {
        _showNewMessageBanner(message);
      });
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _showNewMessageBanner(Message message) {
    if (!mounted) return;
    setState(() {
      _newMessage = message;
      _isVisible = true;
    });
    _slideController.forward();

    // خودکار بسته شدن بعد از ۵ ثانیه
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _hideBanner();
    });
  }

  void _hideBanner() {
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isVisible && _newMessage != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildMessageBanner(),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBanner() {
    if (_newMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF64D2FF).withOpacity(0.9),
            const Color(0xFF64D2FF).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64D2FF).withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _hideBanner();
            // Navigate to message details
            Navigator.pushNamed(
              context,
              '/messages',
              arguments: _newMessage,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.mail_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'پیام جدید از ${_newMessage!.sender}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _newMessage!.body,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _hideBanner,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
