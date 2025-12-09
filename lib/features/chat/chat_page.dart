import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../controllers/chat_controller.dart';
import '../../controllers/assistant_controller.dart';
import '../../models/assistant_models.dart';
import '../../services/action_executor.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../services/service_providers.dart';
import 'widgets/message_bubble.dart';
import 'widgets/session_sidebar.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Consumer<ChatController>(
          builder: (context, controller, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final currentCount = controller.activeSession.messages.length;
              if (currentCount != _lastMessageCount) {
                _lastMessageCount = currentCount;
                _scrollToBottom();
              }
            });
            return LayoutBuilder(
              builder: (context, constraints) {
                final showSidebar = constraints.maxWidth > 900;
                return Row(
                  children: [
                    if (showSidebar)
                      SizedBox(
                        width: 280,
                        child: const Card(
                          margin: EdgeInsets.all(12),
                          child: SessionSidebar(),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          if (!showSidebar)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _openSessionSheet(context),
                                icon: const Icon(Icons.menu),
                                label: const Text('جلسات'),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                ),
                              ),
                            ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.06),
                                        Colors.white.withOpacity(0.03),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: _ConversationList(
                                    controller: controller,
                                    scrollController: _scrollController,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _InputBar(
                            controller: controller,
                            textController: _messageController,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
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

  void _openSessionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SessionSidebar(scrollController: scrollController),
              ),
            );
          },
        );
      },
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.controller,
    required this.scrollController,
  });

  final ChatController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final messages = controller.activeSession.messages;
    if (messages.isEmpty) {
      return _EmptyState(controller: controller);
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      physics: const BouncingScrollPhysics(),
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
    );
  }
}

class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.controller});

  final ChatController controller;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  List<String> _suggestedPrompts = [
    'یک برنامه روزانه برای افزایش بهره‌وری بنویس',
    'راه‌های کاهش استرس را توضیح بده',
    'بهترین روش‌های یادگیری برنامه‌نویسی چیست؟',
    'یک دستور پخت ساده پیشنهاد بده',
    'راهنمای شروع کسب‌وکار آنلاین',
  ];
  bool _loadingPrompts = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestedPrompts();
  }

  Future<void> _loadSuggestedPrompts() async {
    if (_loadingPrompts) return;
    setState(() => _loadingPrompts = true);
    try {
      final api = context.read<ApiClient>();
      final prompts = await api.getSuggestedPrompts(limit: 5);
      if (mounted && prompts.isNotEmpty) {
        setState(() {
          _suggestedPrompts = prompts
              .map((p) => p['text'] ?? '')
              .where((text) => text.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      // fallback to static prompts - already set
    } finally {
      if (mounted) {
        setState(() => _loadingPrompts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'گفتگو را شروع کنید',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'سوالت را بپرس تا وایق با موتور چندمدلی پاسخ دهد.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 32),
          Text(
            'پیشنهادات سریع:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          if (_loadingPrompts)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else
            ..._suggestedPrompts.map((prompt) => _SuggestedPromptCard(
                  prompt: prompt,
                  onTap: () => widget.controller.sendMessage(prompt),
                )),
        ],
      ),
    );
  }
}

class _SuggestedPromptCard extends StatefulWidget {
  const _SuggestedPromptCard({
    required this.prompt,
    required this.onTap,
  });

  final String prompt;
  final VoidCallback onTap;

  @override
  State<_SuggestedPromptCard> createState() => _SuggestedPromptCardState();
}

class _SuggestedPromptCardState extends State<_SuggestedPromptCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) {
              _controller.reverse();
              widget.onTap();
            },
            onTapCancel: () => _controller.reverse(),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.prompt,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.textController,
  });

  final ChatController controller;
  final TextEditingController textController;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final TextEditingController _fileUrlController = TextEditingController();
  final List<String> _filePaths = <String>[];
  final List<String> _fileUrls = <String>[];
  bool _uploadingFile = false;
  bool _runningIntent = false;
  bool _isExpanded = false;
  bool _attachmentsOpen = false;
  stt.SpeechToText? _speech;
  bool _speechAvailable = false;
  bool _listening = false;
  late final NotificationService _notificationService;

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
  void initState() {
    super.initState();
    _notificationService = serviceProvider.get<NotificationService>();
  }

  @override
  void dispose() {
    _fileUrlController.dispose();
    _speech?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasAttachments = _fileUrls.isNotEmpty || _filePaths.isNotEmpty;
    final showAttachmentArea = _attachmentsOpen ||
        hasAttachments ||
        widget.controller.webSearchEnabled;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _SmartActionButton(
                  enabled: !_runningIntent &&
                      widget.textController.text.trim().isNotEmpty,
                  onTap: widget.controller.isStreaming ? null : _runIntent,
                  running: _runningIntent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.textController,
                    minLines: 1,
                    maxLines: _isExpanded ? 5 : 1,
                    decoration: InputDecoration(
                      hintText: 'پیام خود را اینجا بنویسید...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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
                IconButton(
                  icon: Icon(
                    _attachmentsOpen || hasAttachments
                        ? Icons.attach_file
                        : Icons.attach_file_outlined,
                    color: _attachmentsOpen || hasAttachments
                        ? colorScheme.primary
                        : Colors.white70,
                  ),
                  tooltip: 'پیوست‌ها',
                  onPressed: widget.controller.isStreaming
                      ? null
                      : () =>
                          setState(() => _attachmentsOpen = !_attachmentsOpen),
                ),
                IconButton(
                  icon: Icon(
                    _listening ? Icons.mic : Icons.mic_none,
                    color: _listening ? colorScheme.primary : Colors.white70,
                  ),
                  tooltip: _listening ? 'توقف ضبط' : 'ضبط صدا',
                  onPressed:
                      widget.controller.isStreaming ? null : _toggleSpeech,
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor:
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: showAttachmentArea
                  ? Column(
                      key: const ValueKey('attachments'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Divider(
                          color: Colors.white.withOpacity(0.06),
                          height: 12,
                          thickness: 1,
                        ),
                        Row(
                          children: [
                            Icon(Icons.link, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _fileUrlController,
                                decoration: const InputDecoration(
                                  hintText: 'آدرس فایل یا لینک را وارد کنید',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _addFileUrl(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_link),
                              tooltip: 'افزودن لینک',
                              onPressed: _addFileUrl,
                            ),
                            const SizedBox(width: 4),
                            _uploadingFile
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.folder_open),
                                    tooltip: 'انتخاب فایل',
                                    onPressed: widget.controller.isStreaming
                                        ? null
                                        : _pickFile,
                                  ),
                          ],
                        ),
                        if (hasAttachments) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ..._fileUrls.map(
                                (url) => InputChip(
                                  label: Text(
                                    url,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onDeleted: () => _removeFileUrl(url),
                                ),
                              ),
                              ..._filePaths.map(
                                (path) => InputChip(
                                  label: Text(
                                    _fileName(path),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onDeleted: () => _removeFilePath(path),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.travel_explore,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'جستجو در وب',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Switch.adaptive(
                              value: widget.controller.webSearchEnabled,
                              onChanged: widget.controller.isStreaming
                                  ? null
                                  : widget.controller.setWebSearch,
                            ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = widget.textController.text;
    if (text.trim().isEmpty) return;
    widget.controller.sendMessage(
      text,
      fileUrls: List<String>.from(_fileUrls),
      filePaths: List<String>.from(_filePaths),
    );
    widget.textController.clear();
    _fileUrlController.clear();
    _fileUrls.clear();
    _filePaths.clear();
    setState(() {
      _isExpanded = false;
      _attachmentsOpen = false;
    });
  }

  Future<void> _runIntent() async {
    final text = widget.textController.text.trim();
    if (text.isEmpty || _runningIntent) return;
    setState(() => _runningIntent = true);
    final assistant = context.read<AssistantController>();
    final executor = context.read<ActionExecutor>();
    try {
      final request = SmartIntentRequest(
        text: text,
        timezone: DateTime.now().timeZoneName.isEmpty
            ? 'Asia/Tehran'
            : DateTime.now().timeZoneName,
        now: DateTime.now(),
      );
      final intent = await assistant.detectIntent(request);
      if (intent == null) {
        if (!mounted) return;
        _notificationService.showLocalNow(
          title: 'خطا',
          body: 'نیت تشخیص داده نشد',
        );
        return;
      }
      await executor.execute(intent);
      if (!mounted) return;
      _notificationService.showLocalNow(
        title: 'عملیات هوشمند',
        body: 'عمل اجرا شد: ${intent.action.name}',
      );
    } catch (e) {
      if (!mounted) return;
      _notificationService.showLocalNow(
        title: 'خطا',
        body: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _runningIntent = false);
      }
    }
  }

  Future<void> _toggleSpeech() async {
    if (_listening) {
      await _speech?.stop();
      setState(() => _listening = false);
      return;
    }
    _speech ??= stt.SpeechToText();
    _speechAvailable = await _speech!.initialize(
      onError: (error) {
        if (!mounted) return;
        _notificationService.showLocalNow(
          title: 'خطای تشخیص صدا',
          body: error.errorMsg,
        );
      },
    );
    if (!_speechAvailable) {
      if (mounted) {
        _notificationService.showLocalNow(
          title: 'خطا',
          body: 'خدمات تشخیص گفتار در دسترس نیست',
        );
      }
      return;
    }
    setState(() => _listening = true);
    await _speech!.listen(
      localeId: 'fa-IR',
      listenMode: stt.ListenMode.dictation,
      pauseFor: const Duration(seconds: 2),
      onResult: (result) {
        widget.textController.text = result.recognizedWords;
        widget.textController.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.textController.text.length),
        );
        setState(() {});
        if (result.finalResult && mounted) {
          setState(() => _listening = false);
        }
      },
      listenFor: const Duration(seconds: 30),
      cancelOnError: true,
    );
  }

  void _addFileUrl() {
    final value = _fileUrlController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _attachmentsOpen = true;
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

  String _fileName(String path) {
    final parts = path.split(RegExp(r'[\\\\/]'));
    return parts.isNotEmpty ? parts.last : path;
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
        _showError('مسیر فایل نامعتبر است.');
        return;
      }
      if (!_allowedExtensions.contains(ext)) {
        _showError('نوع فایل پشتیبانی نمی‌شود.');
        return;
      }
      if (file.size > _maxFileSize) {
        _showError('حجم فایل بیشتر از حد مجاز (10MB) است.');
        return;
      }

      setState(() {
        _attachmentsOpen = true;
        _filePaths.add(path);
      });
    } catch (error) {
      _showError('خطا هنگام انتخاب فایل.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    _notificationService.showLocalNow(
      title: 'خطا',
      body: message,
    );
  }
}

class _SmartActionButton extends StatelessWidget {
  const _SmartActionButton({
    required this.enabled,
    required this.onTap,
    required this.running,
  });

  final bool enabled;
  final VoidCallback? onTap;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'اجرای عملیات هوشمند',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: enabled
                ? colorScheme.secondaryContainer
                : colorScheme.secondaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: running
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.bolt,
                  color: enabled
                      ? colorScheme.onSecondaryContainer
                      : Colors.white54,
                  size: 18,
                ),
        ),
      ),
    );
  }
}
