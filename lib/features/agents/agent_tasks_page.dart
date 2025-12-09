import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/agent_models.dart';
import '../../services/api_client.dart';
import '../../services/exceptions.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/improved_button.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/markdown_text.dart';

class AgentTasksPage extends StatefulWidget {
  const AgentTasksPage({super.key});

  @override
  State<AgentTasksPage> createState() => _AgentTasksPageState();
}

class _AgentTasksPageState extends State<AgentTasksPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _briefController = TextEditingController();
  final _audienceController = TextEditingController();
  final _toneController = TextEditingController();
  final _outlineController = TextEditingController();
  String _language = 'fa';
  int _wordCount = 1200;
  bool _includeResearch = true;
  bool _isSubmitting = false;
  bool _isLoadingTasks = false;
  bool _isLoadingDetail = false;
  List<AgentTask> _tasks = <AgentTask>[];
  AgentTask? _selectedTask;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _briefController.dispose();
    _audienceController.dispose();
    _toneController.dispose();
    _outlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        final children = [
          Expanded(
            flex: 1,
            child: _buildTaskForm(),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildTaskBoard(),
          ),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                )
              : Column(
                  children: [
                    _buildTaskForm(),
                    const SizedBox(height: 16),
                    _buildTaskBoard(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildTaskForm() {
    return AnimatedCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_task,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تعریف تسک جدید',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'عنوان محتوا'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _briefController,
              decoration: const InputDecoration(
                labelText: 'بریف / شرح انتظار',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _audienceController,
              decoration: const InputDecoration(labelText: 'مخاطب هدف'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _toneController,
              decoration:
                  const InputDecoration(labelText: 'تون نوشته (مثلاً دوستانه)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _outlineController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'آوت‌لاین پیشنهادی (هر خط یک بخش)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(labelText: 'زبان خروجی'),
              items: const [
                DropdownMenuItem(value: 'fa', child: Text('فارسی')),
                DropdownMenuItem(value: 'en', child: Text('انگلیسی')),
              ],
              onChanged: (value) => setState(() => _language = value ?? 'fa'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 400,
                    max: 3000,
                    divisions: 13,
                    label: '$_wordCount کلمه',
                    value: _wordCount.toDouble(),
                    onChanged: (value) =>
                        setState(() => _wordCount = value.round()),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '$_wordCount',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            SwitchListTile(
              value: _includeResearch,
              title: const Text('تحقیق تکمیلی'),
              subtitle:
                  const Text('ایجنت قبل از نگارش، تحقیق آنلاین انجام دهد.'),
              onChanged: (value) => setState(() => _includeResearch = value),
            ),
            const SizedBox(height: 20),
            ImprovedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              icon: Icons.add_task,
              loading: _isSubmitting,
              variant: ButtonVariant.elevated,
              child: const Text('ثبت تسک'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskBoard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.task_alt,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'تسک‌های من',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'به‌روزرسانی',
                    onPressed: _isLoadingTasks ? null : _fetchTasks,
                    icon: _isLoadingTasks
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoadingTasks)
                const SkeletonList(itemCount: 3, itemHeight: 60)
              else if (_tasks.isEmpty)
                const EmptyState(
                  icon: Icons.task_alt,
                  title: 'تسکی وجود ندارد',
                  message: 'برای شروع، یک تسک جدید تعریف کنید.',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    final isActive = _selectedTask?.id == task.id;
                    return AnimatedCard(
                      margin: EdgeInsets.zero,
                      elevation: isActive ? 2 : 0,
                      onTap: () => _loadTaskDetail(task.id),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  task.status,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(status: task.status),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedTask != null)
          AnimatedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedTask!.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    _StatusChip(status: _selectedTask!.status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 16, color: Theme.of(context).hintColor),
                    const SizedBox(width: 4),
                    Text(
                      'آخرین بروزرسانی: ${_formatDate(_selectedTask!.updatedAt)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
                if (_selectedTask!.outline.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'آوت‌لاین',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  ..._selectedTask!.outline.map(
                    (item) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                ],
                if (_selectedTask!.lastError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'خطا',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedTask!.lastError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                if (_isLoadingDetail)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_selectedTask!.hasResult) ...[
                  Text(
                    'خروجی نهایی',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  MarkdownText(
                    data: _selectedTask!.resultText!,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _selectedTask!.resultText!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('متن در کلیپ‌بورد ذخیره شد.')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('کپی متن'),
                    ),
                  ),
                ] else
                  const Text('این تسک هنوز خروجی تولید نکرده است.'),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final api = context.read<ApiClient>();
    final outline = _outlineController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    try {
      final response = await api.postJson('/agents/tasks', body: {
        'title': _titleController.text.trim(),
        'brief': _briefController.text.trim(),
        'audience': _audienceController.text.trim(),
        'tone': _toneController.text.trim(),
        'language': _language,
        'outline': outline,
        'word_count': _wordCount,
        'include_research': _includeResearch,
      });
      final created = AgentTask.fromJson(response);
      setState(() {
        _selectedTask = created;
        _titleController.clear();
        _briefController.clear();
        _audienceController.clear();
        _toneController.clear();
        _outlineController.clear();
        _wordCount = 1200;
        _includeResearch = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تسک با موفقیت ثبت شد.')),
        );
      }
      await _fetchTasks();
    } catch (error) {
      final message =
          error is ApiException ? error.message : 'ثبت تسک با خطا مواجه شد.';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoadingTasks = true);
    final api = context.read<ApiClient>();
    try {
      final response = await api.getJson('/agents/tasks');
      final items = (response['data'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => AgentTask.fromJson(
              Map<String, dynamic>.from(item as Map<String, dynamic>)))
          .toList();
      setState(() => _tasks = items);
    } catch (error) {
      final message = error is ApiException
          ? error.message
          : 'دریافت لیست تسک‌ها با خطا مواجه شد.';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
      }
    }
  }

  Future<void> _loadTaskDetail(int taskId) async {
    setState(() {
      _isLoadingDetail = true;
      if (_selectedTask == null || _selectedTask!.id != taskId) {
        _selectedTask = _tasks.firstWhere(
          (element) => element.id == taskId,
          orElse: () =>
              _selectedTask ??
              AgentTask(
                id: taskId,
                title: 'تسک',
                status: 'pending',
                language: 'fa',
                outline: const [],
                resultText: null,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                lastError: null,
              ),
        );
      }
    });
    final api = context.read<ApiClient>();
    try {
      final response = await api.getJson('/agents/tasks/$taskId');
      setState(() => _selectedTask = AgentTask.fromJson(response));
    } catch (error) {
      final message = error is ApiException
          ? error.message
          : 'دریافت جزئیات تسک با خطا مواجه شد.';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    }
  }

  String? _requiredValidator(String? value) =>
      (value == null || value.trim().isEmpty) ? 'این فیلد الزامی است.' : null;

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color? background;
    Color? foreground;
    switch (status) {
      case 'completed':
        background = Theme.of(context).colorScheme.primaryContainer;
        foreground = Theme.of(context).colorScheme.onPrimaryContainer;
        break;
      case 'failed':
        background = Theme.of(context).colorScheme.errorContainer;
        foreground = Theme.of(context).colorScheme.onErrorContainer;
        break;
      case 'in_progress':
        background = Theme.of(context).colorScheme.surfaceContainerHighest;
        foreground = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      default:
        background = Theme.of(context).colorScheme.surfaceContainerHighest;
        foreground = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return Chip(
      backgroundColor: background,
      label: Text(
        status,
        style: TextStyle(color: foreground),
      ),
    );
  }
}
