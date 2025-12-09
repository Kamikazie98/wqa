import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/chat_controller.dart';
import '../chat/widgets/message_bubble.dart';

class ExpertsPage extends StatelessWidget {
  const ExpertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مشاوران تخصصی',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'با مشاوران تخصصی ما در حوزه‌های مختلف گفتگو کنید',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 24),
          _ExpertCard(
            title: 'روانشناسی و سلامت روان',
            subtitle:
                'مشاوره تخصصی در زمینه اختلالات روانی، درمان و سلامت روان',
            icon: Icons.psychology,
            color: const Color(0xFF9C27B0),
            domain: 'psychology',
            onTap: () => _startExpertChat(
                context, 'psychology', 'روانشناسی و سلامت روان'),
          ),
          const SizedBox(height: 16),
          _ExpertCard(
            title: 'مشاوره روان‌پزشکی',
            subtitle:
                'تحلیل علائم بالینی، دارودرمانی و برنامه مراقبت روانی توسط متخصص',
            icon: Icons.health_and_safety,
            color: const Color(0xFFE91E63),
            domain: 'psychiatry',
            onTap: () =>
                _startExpertChat(context, 'psychiatry', 'مشاوره روان‌پزشکی'),
          ),
          const SizedBox(height: 16),
          _ExpertCard(
            title: 'مشاوره املاک',
            subtitle: 'راهنمایی در خرید، فروش، اجاره و سرمایه‌گذاری املاک',
            icon: Icons.home,
            color: const Color(0xFF2196F3),
            domain: 'real_estate',
            onTap: () =>
                _startExpertChat(context, 'real_estate', 'مشاوره املاک'),
          ),
          const SizedBox(height: 16),
          _ExpertCard(
            title: 'مکانیک خودرو',
            subtitle: 'تشخیص و تعمیر مشکلات خودرو، نگهداری و سرویس',
            icon: Icons.build_circle,
            color: const Color(0xFFFF9800),
            domain: 'mechanics',
            onTap: () => _startExpertChat(context, 'mechanics', 'مکانیک خودرو'),
          ),
          const SizedBox(height: 16),
          _ExpertCard(
            title: 'مشاوره استعداد یابی',
            subtitle: 'شناسایی استعدادها، انتخاب شغل و برنامه‌ریزی مسیر شغلی',
            icon: Icons.emoji_events,
            color: const Color(0xFF4CAF50),
            domain: 'talent_assessment',
            onTap: () => _startExpertChat(
                context, 'talent_assessment', 'مشاوره استعداد یابی'),
          ),
        ],
      ),
    );
  }

  void _startExpertChat(BuildContext context, String domain, String title) {
    final chatController = context.read<ChatController>();
    // ذخیره سشن فعال برای بازگشت UX بهتر
    final previousSessionId = chatController.activeSession.id;
    // ایجاد session جدید با عنوان تخصصی
    chatController.createSession(title: title);
    // ذخیره domain برای استفاده در chat
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpertChatPage(
          domain: domain,
          expertTitle: title,
          previousSessionId: previousSessionId,
        ),
      ),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  const _ExpertCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.domain,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String domain;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 20, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpertChatPage extends StatefulWidget {
  const ExpertChatPage({
    super.key,
    required this.domain,
    required this.expertTitle,
    required this.previousSessionId,
  });

  final String domain;
  final String expertTitle;
  final String previousSessionId;

  @override
  State<ExpertChatPage> createState() => _ExpertChatPageState();
}

class _ExpertChatPageState extends State<ExpertChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void dispose() {
    final controller = context.read<ChatController>();
    if (controller.sessions.any((s) => s.id == widget.previousSessionId)) {
      controller.selectSession(widget.previousSessionId);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.expertTitle),
            Text(
              'مشاور تخصصی',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Consumer<ChatController>(
        builder: (context, controller, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final currentCount = controller.activeSession.messages.length;
            if (currentCount != _lastMessageCount) {
              _lastMessageCount = currentCount;
              _scrollToBottom();
            }
          });

          final messages = controller.activeSession.messages;
          return Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? _EmptyExpertState(
                        expertTitle: widget.expertTitle,
                        domain: widget.domain,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final isAssistantStream = controller.isStreaming &&
                              index == messages.length - 1 &&
                              messages[index].isAssistant;
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: MessageBubble(
                              message: messages[index],
                              isStreaming: isAssistantStream,
                            ),
                          );
                        },
                      ),
              ),
              _ExpertInputBar(
                controller: controller,
                textController: _messageController,
                domain: widget.domain,
              ),
            ],
          );
        },
      ),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}

class _EmptyExpertState extends StatelessWidget {
  const _EmptyExpertState({
    required this.expertTitle,
    required this.domain,
  });

  final String expertTitle;
  final String domain;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'خوش آمدید به $expertTitle',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'من یک مشاور تخصصی هستم و آماده پاسخگویی به سوالات شما بر اساس آخرین اطلاعات علمی هستم.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpertInputBar extends StatefulWidget {
  const _ExpertInputBar({
    required this.controller,
    required this.textController,
    required this.domain,
  });

  final ChatController controller;
  final TextEditingController textController;
  final String domain;

  @override
  State<_ExpertInputBar> createState() => _ExpertInputBarState();
}

class _ExpertInputBarState extends State<_ExpertInputBar> {
  bool _isExpanded = false;
  final TextEditingController _fileUrlController = TextEditingController();
  final List<String> _fileUrls = <String>[];
  final List<String> _filePaths = <String>[];
  bool _uploadingFile = false;

  static const _maxFileSize = 10 * 1024 * 1024; // 10MB
  static const _allowedExtensions = <String>[
    'txt',
    'md',
    'pdf',
    'doc',
    'docx',
    'csv',
    'json',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  ];

  @override
  void dispose() {
    _fileUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.textController,
                  minLines: 1,
                  maxLines: _isExpanded ? 5 : 1,
                  decoration: InputDecoration(
                    hintText: 'سوال خود را بپرسید...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: widget.textController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              widget.textController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(),
                  onTap: () {
                    if (!_isExpanded) {
                      setState(() => _isExpanded = true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.controller.isStreaming ? null : _send,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: widget.controller.isStreaming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.black,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.attach_file, color: Colors.white70, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _fileUrlController,
                        decoration: const InputDecoration(
                          hintText: 'آدرس فایل یا لینک آپلود شده',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addFileUrl(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_link),
                      tooltip: 'افزودن لینک فایل',
                      onPressed: _addFileUrl,
                    ),
                    const SizedBox(width: 2),
                    _uploadingFile
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.folder_open),
                            tooltip: 'انتخاب فایل از گوشی',
                            onPressed: widget.controller.isStreaming
                                ? null
                                : _pickFile,
                          ),
                  ],
                ),
                if (_fileUrls.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _fileUrls
                        .map(
                          (url) => InputChip(
                            label: Text(
                              url,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => _removeFileUrl(url),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (_filePaths.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _filePaths
                        .map(
                          (path) => InputChip(
                            label: Text(
                              _fileName(path),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => _removeFilePath(path),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _send() {
    final text = widget.textController.text;
    if (text.trim().isEmpty) return;

    // استفاده از متد جدید sendExpertMessage
    widget.controller.sendExpertMessage(
      text,
      widget.domain,
      fileUrls: List<String>.from(_fileUrls),
      filePaths: List<String>.from(_filePaths),
    );
    widget.textController.clear();
    _fileUrlController.clear();
    _fileUrls.clear();
    _filePaths.clear();
    setState(() {
      _isExpanded = false;
    });
  }

  void _addFileUrl() {
    final value = _fileUrlController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _fileUrls.add(value);
      _fileUrlController.clear();
    });
  }

  void _removeFileUrl(String url) {
    setState(() {
      _fileUrls.remove(url);
    });
  }

  void _removeFilePath(String path) {
    setState(() {
      _filePaths.remove(path);
    });
  }

  Future<void> _pickFile() async {
    if (widget.controller.isStreaming) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final path = file.path;
      final ext = (file.extension ?? '').toLowerCase();
      if (path == null) {
        _showError('مسیر فایل در دسترس نیست.');
        return;
      }
      if (!_allowedExtensions.contains(ext)) {
        _showError('نوع فایل پشتیبانی نمی‌شود.');
        return;
      }
      if (file.size > _maxFileSize) {
        _showError('حجم فایل باید کمتر از ۱۰ مگابایت باشد.');
        return;
      }

      setState(() {
        _filePaths.add(path);
      });
    } catch (error) {
      _showError('بارگذاری فایل با خطا مواجه شد.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _fileName(String path) {
    final parts = path.split(RegExp(r'[\\\\/]'));
    return parts.isNotEmpty ? parts.last : path;
  }
}
