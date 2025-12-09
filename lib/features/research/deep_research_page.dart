import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/research_models.dart';
import '../../services/api_client.dart';
import '../../services/exceptions.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/improved_button.dart';
import '../../widgets/skeleton_loader.dart';

class DeepResearchPage extends StatefulWidget {
  const DeepResearchPage({super.key});

  @override
  State<DeepResearchPage> createState() => _DeepResearchPageState();
}

class _DeepResearchPageState extends State<DeepResearchPage> {
  final _formKey = GlobalKey<FormState>();
  final _queryController = TextEditingController();
  final _audienceController = TextEditingController();
  String _depth = 'summary';
  String _language = 'fa';
  bool _includeOutline = true;
  bool _includeSources = true;
  bool _isLoading = false;
  DeepResearchResult? _result;

  @override
  void dispose() {
    _queryController.dispose();
    _audienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AnimatedCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          Icons.science_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'تحقیق عمیق',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _queryController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'موضوع تحقیق',
                      alignLabelWithHint: true,
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _audienceController,
                    decoration:
                        const InputDecoration(labelText: 'پرسونای مخاطب'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _depth,
                    decoration: const InputDecoration(labelText: 'عمق بررسی'),
                    items: const [
                      DropdownMenuItem(value: 'summary', child: Text('خلاصه')),
                      DropdownMenuItem(value: 'detailed', child: Text('جزئی')),
                      DropdownMenuItem(
                          value: 'comprehensive', child: Text('فراگیر')),
                    ],
                    onChanged: (value) =>
                        setState(() => _depth = value ?? 'summary'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _language,
                    decoration: const InputDecoration(labelText: 'زبان خروجی'),
                    items: const [
                      DropdownMenuItem(value: 'fa', child: Text('فارسی')),
                      DropdownMenuItem(value: 'en', child: Text('انگلیسی')),
                    ],
                    onChanged: (value) =>
                        setState(() => _language = value ?? 'fa'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _includeOutline,
                    title: const Text('تولید آوت‌لاین'),
                    subtitle: const Text('افزودن ساختار پیشنهادی به خروجی'),
                    onChanged: (value) =>
                        setState(() => _includeOutline = value),
                  ),
                  SwitchListTile(
                    value: _includeSources,
                    title: const Text('جمع‌آوری منابع'),
                    subtitle: const Text('استخراج لینک و رفرنس از گوگل'),
                    onChanged: (value) =>
                        setState(() => _includeSources = value),
                  ),
                  const SizedBox(height: 20),
                  ImprovedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    icon: Icons.science_outlined,
                    loading: _isLoading,
                    variant: ButtonVariant.elevated,
                    child: const Text('شروع تحقیق'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(itemCount: 3, itemHeight: 120),
            )
          else if (_result != null)
            _ResearchResultView(result: _result!),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final api = context.read<ApiClient>();
    try {
      final response = await api.postJson('/research/deep', body: {
        'query': _queryController.text.trim(),
        'depth': _depth,
        'audience': _audienceController.text.trim(),
        'language': _language,
        'include_outline': _includeOutline,
        'include_sources': _includeSources,
      });
      setState(() {
        _result = DeepResearchResult.fromJson(response);
      });
    } catch (error) {
      final message = error is ApiException
          ? error.message
          : 'اجرای تحقیق با خطا مواجه شد.';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _requiredValidator(String? value) =>
      (value == null || value.trim().isEmpty) ? 'این فیلد الزامی است.' : null;
}

class _ResearchResultView extends StatelessWidget {
  const _ResearchResultView({required this.result});

  final DeepResearchResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.summarize, color: colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'جمع‌بندی',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(result.summary.isEmpty ? 'بدون خلاصه' : result.summary),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                      icon: Icons.search, label: 'موضوع', value: result.query),
                  _InfoChip(
                      icon: Icons.layers_outlined,
                      label: 'عمق',
                      value: result.depth),
                ],
              ),
              if (result.rawText.isNotEmpty) ...[
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: result.rawText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('متن خام در کلیپ‌بورد ذخیره شد.')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('کپی متن خام'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (result.hasSections) ...[
          const SizedBox(height: 20),
          ...result.sections.map(
            (section) => AnimatedCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.article,
                            color: colorScheme.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          section.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(section.summary),
                  if (section.takeaways.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('نکات کلیدی',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    ...section.takeaways.map(
                      (item) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  ],
                  if (section.sources.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('منابع',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    ...section.sources.map(
                      (source) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.link, color: colorScheme.primary),
                        title: Text(source.title),
                        subtitle: Text(source.url),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: source.url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('לینک در کلیپ‌بورد ذخیره شد.')),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (result.hasOutline) ...[
          const SizedBox(height: 20),
          AnimatedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.list_alt, color: colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'آوت‌لاین پیشنهادی',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...result.outline.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (result.hasSources) ...[
          const SizedBox(height: 20),
          AnimatedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.feed_outlined,
                        color: colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'منابع کلی',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...result.sources.map(
                  (source) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading:
                        Icon(Icons.feed_outlined, color: colorScheme.primary),
                    title: Text(source.title),
                    subtitle: Text(source.url),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: source.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('لینک در کلیپ‌بورد ذخیره شد.')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label: $value'),
    );
  }
}
