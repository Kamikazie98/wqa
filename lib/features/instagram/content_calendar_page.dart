import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/exceptions.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/improved_button.dart';
import '../../widgets/expandable_section.dart';
import '../../widgets/skeleton_loader.dart';

class ContentCalendarPage extends StatefulWidget {
  const ContentCalendarPage({super.key});

  @override
  State<ContentCalendarPage> createState() => _ContentCalendarPageState();
}

class _ContentCalendarPageState extends State<ContentCalendarPage> {
  final _formKey = GlobalKey<FormState>();
  final _ideaController = TextEditingController();
  final _pillarsController = TextEditingController();
  final _brandController = TextEditingController();
  final _toneController = TextEditingController();
  final _ctaController = TextEditingController();
  final _rulesController = TextEditingController();

  int _weeks = 4;
  int _postsPerWeek = 3;
  bool _includeReels = true;
  String _language = 'fa';
  bool _isLoading = false;
  List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];

  @override
  void dispose() {
    _ideaController.dispose();
    _pillarsController.dispose();
    _brandController.dispose();
    _toneController.dispose();
    _ctaController.dispose();
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
                            Icons.calendar_view_week,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'تقویم محتوایی اینستاگرام',
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

                    // ایده اصلی
                    TextFormField(
                      controller: _ideaController,
                      decoration: const InputDecoration(
                        labelText: 'ایده اصلی / توضیح کسب‌وکار',
                      ),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),

                    // مدت و تعداد پست
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _weeks.toString(),
                            decoration: const InputDecoration(
                              labelText: 'مدت (هفته)',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _weeks = int.tryParse(value) ?? 4;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _postsPerWeek.toString(),
                            decoration: const InputDecoration(
                              labelText: 'تعداد پست در هفته',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _postsPerWeek = int.tryParse(value) ?? 3;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ستون‌های محتوایی
                    TextFormField(
                      controller: _pillarsController,
                      decoration: const InputDecoration(
                        labelText:
                            'ستون‌های محتوایی / دسته‌بندی‌ها (مثلاً آموزشی، پشت‌صحنه، سرگرمی، فروش)',
                      ),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),

                    // بخش قابل گسترش: جزئیات برند، لحن، CTA، قوانین، ریلز، زبان
                    ExpandableSection(
                      title: 'جزئیات برند و قوانین',
                      icon: Icons.tune,
                      initiallyExpanded: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _brandController,
                            decoration: const InputDecoration(
                              labelText: 'برند / محصول / مخاطب هدف',
                              hintText:
                                  'کسب‌وکار، محصول و مخاطب هدف را به‌صورت کوتاه توضیح بده',
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
                            controller: _ctaController,
                            decoration: const InputDecoration(
                              labelText: 'CTA اصلی / هدف هر محتوا',
                              hintText:
                                  'مثلاً افزایش فالوور، فروش، ذخیره، کامنت، کلیک روی لینک و ...',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _rulesController,
                            decoration: const InputDecoration(
                              labelText:
                                  'قوانین و محدودیت‌ها (چه کار بکنیم / نکنیم)',
                              hintText:
                                  'مثلاً روی قیمت مستقیم تأکید نکنیم، از ایموجی زیاد استفاده نکنیم، همیشه از برند منشن کنیم و ...',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            value: _includeReels,
                            onChanged: (value) {
                              setState(() {
                                _includeReels = value;
                              });
                            },
                            title: const Text('ریلز هم تولید شود'),
                          ),
                          DropdownButtonFormField<String>(
                            value: _language,
                            decoration:
                                const InputDecoration(labelText: 'زبان'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'fa', child: Text('فارسی')),
                              DropdownMenuItem(
                                  value: 'en', child: Text('انگلیسی')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _language = value ?? 'fa';
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    ImprovedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      icon: Icons.calendar_view_week,
                      loading: _isLoading,
                      variant: ButtonVariant.elevated,
                      child: const Text('ساخت تقویم'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonList(itemCount: 4, itemHeight: 150),
              )
            else if (_entries.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'برنامه پیشنهادی',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ..._entries.map(
                    (entry) => _CalendarCard(data: entry),
                  ),
                ],
              ),
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
      final enrichedIdea = '''
${_ideaController.text.trim()}
- برند / محصول / مخاطب هدف: ${_brandController.text.trim()}
- لحن محتوا: ${_toneController.text.trim()}
- CTA اصلی: ${_ctaController.text.trim()}
- قوانین و محدودیت‌ها: ${_rulesController.text.trim()}
- برنامه‌ریزی: برای ${_weeks} هفته و هر هفته ${_postsPerWeek} پست؛ ترکیب ${_includeReels ? 'Reel/Carousel' : 'Carousel'}؛ برای هر روز hook، format، outline سه‌بولتی، CTA و notes/hashtag را مشخص کن.
'''
          .trim();

      final response = await api.postJson(
        '/instagram/content-calendar',
        body: {
          'idea': enrichedIdea,
          'duration_weeks': _weeks,
          'posts_per_week': _postsPerWeek,
          'pillars': _pillarsController.text
              .split(',')
              .map((pillar) => pillar.trim())
              .where((pillar) => pillar.isNotEmpty)
              .toList(),
          'include_reels': _includeReels,
          'language': _language,
        },
      );

      final entries = _extractEntries(response);
      setState(() {
        _entries = entries;
      });
    } catch (error) {
      final message = error is ApiException
          ? error.message
          : 'تولید تقویم با خطا مواجه شد.';
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

// --------- Parsing Helpers ---------

List<Map<String, dynamic>> _extractEntries(
  Map<String, dynamic> response,
) {
  final direct = (response['entries'] as List<dynamic>? ?? <dynamic>[])
      .map(
        (item) => Map<String, dynamic>.from(
          item as Map<String, dynamic>,
        ),
      )
      .toList();

  if (direct.isNotEmpty) return direct;

  final rawText = response['raw_text']?.toString() ?? '';
  if (rawText.isEmpty) return <Map<String, dynamic>>[];

  final cleaned = _cleanFence(rawText);
  final decoded = _tryDecode(cleaned);

  if (decoded is Map<String, dynamic>) {
    final parsedEntries = decoded['entries'] as List<dynamic>? ?? <dynamic>[];
    return parsedEntries
        .map(
          (item) => Map<String, dynamic>.from(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  if (decoded is List) {
    return decoded
        .map(
          (item) => Map<String, dynamic>.from(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  return <Map<String, dynamic>>[];
}

String _cleanFence(String text) {
  final fence = RegExp(r'```[a-zA-Z]*\s*([\s\S]*?)```', multiLine: true);
  final match = fence.firstMatch(text);
  if (match != null && match.groupCount >= 1) {
    return (match.group(1) ?? text).trim();
  }
  return text.trim();
}

Object? _tryDecode(String text) {
  if (text.isEmpty) return null;
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}

// --------- UI Widgets ---------

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data['day']?.toString() ?? '',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Field(label: 'هوک', value: data['hook']),
          _Field(label: 'فرمت', value: data['format']),
          _Field(label: 'Outline', value: data['outline']),
          _Field(label: 'CTA', value: data['cta']),
          _Field(label: 'نکات', value: data['notes']),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text: data.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('در کلیپ‌بورد ذخیره شد.'),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('کپی'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(value.toString()),
        ],
      ),
    );
  }
}
