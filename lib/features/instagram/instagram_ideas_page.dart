import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/exceptions.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/improved_button.dart';
import '../../widgets/skeleton_loader.dart';

class InstagramIdeasPage extends StatefulWidget {
  const InstagramIdeasPage({super.key});

  @override
  State<InstagramIdeasPage> createState() => _InstagramIdeasPageState();
}

class _InstagramIdeasPageState extends State<InstagramIdeasPage> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _audienceController = TextEditingController();
  final _goalsController = TextEditingController();
  final _brandController = TextEditingController();
  final _toneController = TextEditingController();
  final _rulesController = TextEditingController();

  String _language = 'fa';
  bool _isLoading = false;
  List<Map<String, dynamic>> _ideas = <Map<String, dynamic>>[];

  @override
  void dispose() {
    _topicController.dispose();
    _audienceController.dispose();
    _goalsController.dispose();
    _brandController.dispose();
    _toneController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedCard(
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
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ایجاد ایده‌های اینستاگرامی',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _topicController,
                      decoration: const InputDecoration(
                        labelText: 'موضوع اصلی',
                      ),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _audienceController,
                      decoration: const InputDecoration(
                        labelText: 'پرسونای مخاطب',
                      ),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _goalsController,
                      decoration: const InputDecoration(
                        labelText: 'اهداف و نتایج مورد انتظار',
                        hintText:
                            'مثلاً افزایش فالوور، فروش، تعامل (لایک/کامنت/سیو)، آگاهی از برند و ...',
                      ),
                      maxLines: 2,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'برند / محصول / مزیت رقابتی',
                        hintText:
                            'کسب‌وکار، محصول و مزیت اصلی برند را به‌صورت کوتاه توضیح بده',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _toneController,
                      decoration: const InputDecoration(
                        labelText: 'لحن محتوا',
                        hintText:
                            'مثلاً صمیمی، رسمی، شوخ‌طبع، آموزشی، الهام‌بخش و ...',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rulesController,
                      decoration: const InputDecoration(
                        labelText: 'قوانین و محدودیت‌ها (چه کار بکنیم / نکنیم)',
                        hintText:
                            'مثلاً تبلیغ مستقیم نداشته باشد، از الفاظ منفی استفاده نکنیم، همیشه ارزش آموزشی داشته باشد و ...',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _language,
                      decoration: const InputDecoration(
                        labelText: 'زبان خروجی ایده‌ها',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'fa', child: Text('فارسی')),
                        DropdownMenuItem(value: 'en', child: Text('انگلیسی')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _language = value ?? 'fa';
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    ImprovedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      icon: Icons.auto_awesome,
                      loading: _isLoading,
                      variant: ButtonVariant.elevated,
                      child: const Text('تولید ایده'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonList(itemCount: 3, itemHeight: 200),
              )
            else if (_ideas.isNotEmpty) ...[
              Text(
                'ایده‌های پیشنهادی',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ..._ideas.asMap().entries.map(
                    (entry) => _IdeaCard(
                      data: entry.value,
                      index: entry.key,
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final api = context.read<ApiClient>();

    try {
      final enrichedGoals = '''
${_goalsController.text.trim()}
- برند / محصول / مزیت رقابتی: ${_brandController.text.trim()}
- لحن محتوا: ${_toneController.text.trim()}
- قوانین و محدودیت‌ها: ${_rulesController.text.trim()}
- خروجی ایده‌ها: برای هر ایده چند هوک پیشنهادی، توضیح «چرا جواب می‌دهد»، یک نمونه کپشن/اسکریپت ۳۰–۶۰ ثانیه‌ای، CTA پیشنهادی و چند راه درآمدزایی (محصول، خدمات، همکاری، آموزش و ...).
'''
          .trim();

      final response = await api.postJson(
        '/instagram/ideas',
        body: {
          'topic': _topicController.text.trim(),
          'audience': _audienceController.text.trim(),
          'goals': enrichedGoals,
          'language': _language,
        },
      );

      final ideas = (response['ideas'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) => Map<String, dynamic>.from(
              item as Map<String, dynamic>,
            ),
          )
          .toList();

      setState(() {
        _ideas = ideas;
      });
    } catch (error) {
      final message = error is ApiException
          ? error.message
          : 'دریافت ایده‌ها با خطا مواجه شد.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'این فیلد الزامی است.';
    }
    return null;
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    required this.data,
    required this.index,
  });

  final Map<String, dynamic> data;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final title = _resolveTitle(data, index);

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: color.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ItemRow(label: 'زاویه روایت', value: data['angle']),
          _ItemRow(label: 'دلیل اثرگذاری', value: data['why_it_works']),
          _ItemRow(label: 'نمونه محتوا', value: data['sample_content']),
          _ItemRow(label: 'درآمدزایی', value: data['monetization']),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final entry =
                    data.entries.map((e) => '${e.key}: ${e.value}').join('\n');
                Clipboard.setData(ClipboardData(text: entry));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('در کلیپ‌بورد ذخیره شد.'),
                  ),
                );
              },
              icon: Icon(Icons.copy, color: color.primary),
              label: const Text('کپی'),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveTitle(Map<String, dynamic> data, int index) {
    final candidates = [
      data['niche_name'],
      data['title'],
      data['idea_name'],
    ].map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty);
    final first = candidates.isNotEmpty ? candidates.first : null;
    return first ?? 'ایده ${index + 1}';
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.label,
    required this.value,
  });

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(value.toString()),
        ],
      ),
    );
  }
}
