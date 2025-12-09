import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/assistant_models.dart';
import '../../services/api_client.dart';
import '../../services/assistant_service.dart';
import '../../services/automation_service.dart';
import '../../services/exceptions.dart';
import '../../services/native_bridge.dart';
import '../../services/notification_service.dart';
import '../../services/workmanager_service.dart';
import '../../services/url_launcher_service.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/improved_button.dart';
import '../../widgets/markdown_text.dart';
import '../../widgets/skeleton_loader.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  final _searchFormKey = GlobalKey<FormState>();
  final _scrapeFormKey = GlobalKey<FormState>();
  final _imageFormKey = GlobalKey<FormState>();

  final _searchController = TextEditingController();
  final _scrapeUrlController = TextEditingController();
  final _scrapePromptController = TextEditingController(text: 'خلاصه کن');
  final _imagePromptController = TextEditingController();
  final _imageModelController = TextEditingController();
  final _imageProviderController = TextEditingController();
  final _briefingNotesController = TextEditingController();
  final _nextMinutesController = TextEditingController(text: '15');
  final _nextTasksController = TextEditingController();
  final _modeTextController = TextEditingController();
  final _modeContextController = TextEditingController();
  final _inboxMessageController = TextEditingController();
  final _inboxChannelController = TextEditingController(text: 'whatsapp');
  final _triageInputController = TextEditingController(
    text:
        '[{"title":"مهلت ارسال فایل تا ساعت ۶","body":"امروز تا ۶ بعدازظهر باید فایل رو بفرستی"}]',
  );
  final _weeklyGoalsController = TextEditingController();
  final _weeklyEventsController = TextEditingController(text: '[]');
  final _memoryKeyController = TextEditingController();
  final _memoryFactsController = TextEditingController();
  final _memoryQueryController = TextEditingController();
  final _selfCareDurationController = TextEditingController(text: '14');
  final _autoModeContextController = TextEditingController(text: '{}');
  final _autoWeeklyGoalsController = TextEditingController();
  final _autoWeeklyEventsController = TextEditingController(text: '[]');
  List<Map<String, dynamic>> _usageStats = <Map<String, dynamic>>[];
  InboxIntelResult? _usageIntel;

  String _searchLanguage = 'fa';
  int _maxSources = 3;
  double _temperature = 0.0;

  bool _summarize = true;
  int _scrapeLimit = 2000;

  String _responseFormat = 'url';
  String _imageSize = '1024x1024';
  int _imageCount = 1;
  String _energy = 'normal';
  String _mode = 'default';
  String _triageMode = 'default';
  bool _autoNextEnabled = false;
  bool _autoModeEnabled = false;
  bool _autoWeeklyEnabled = false;
  bool _autoNotifTriageEnabled = false;
  bool _autoInboxIntelEnabled = false;
  bool _autoUsageIntelEnabled = false;

  bool _searchLoading = false;
  bool _scrapeLoading = false;
  bool _imageLoading = false;
  bool _savingToGallery = false;
  bool _briefingLoading = false;
  bool _nextActionLoading = false;
  bool _modeLoading = false;
  bool _inboxLoading = false;
  bool _triageLoading = false;
  bool _weeklyLoading = false;
  bool _memoryUpserting = false;
  bool _memorySearching = false;
  bool _selfCarePlanLoading = false;
  bool _calendarLoading = false;
  bool _wifiLoading = false;
  bool _usageLoading = false;

  Map<String, dynamic>? _searchResult;
  Map<String, dynamic>? _scrapeResult;
  List<_GeneratedImage> _images = <_GeneratedImage>[];
  DailyBriefingResult? _dailyBriefingResult;
  NextActionResult? _nextActionResult;
  ModeDecisionResult? _modeDecisionResult;
  InboxIntelResult? _inboxIntelResult;
  NotificationTriageResult? _triageResult;
  WeeklyScheduleResult? _weeklyResult;
  MemorySearchResult? _memorySearchResult;
  int? _memorySavedCount;
  SelfCarePlanResult? _selfCarePlanResult;
  String? _opsError;

  @override
  void dispose() {
    _searchController.dispose();
    _scrapeUrlController.dispose();
    _scrapePromptController.dispose();
    _imagePromptController.dispose();
    _imageModelController.dispose();
    _imageProviderController.dispose();
    _briefingNotesController.dispose();
    _nextMinutesController.dispose();
    _nextTasksController.dispose();
    _modeTextController.dispose();
    _modeContextController.dispose();
    _inboxMessageController.dispose();
    _inboxChannelController.dispose();
    _triageInputController.dispose();
    _weeklyGoalsController.dispose();
    _weeklyEventsController.dispose();
    _memoryKeyController.dispose();
    _memoryFactsController.dispose();
    _memoryQueryController.dispose();
    _selfCareDurationController.dispose();
    _autoModeContextController.dispose();
    _autoWeeklyGoalsController.dispose();
    _autoWeeklyEventsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final automation = context.read<AutomationService>();
      setState(() {
        _autoNextEnabled = automation.autoNextEnabled;
        _autoModeEnabled = automation.autoModeEnabled;
        _autoWeeklyEnabled = automation.autoWeeklyEnabled;
        _autoNotifTriageEnabled = automation.autoNotifTriageEnabled;
        _autoInboxIntelEnabled = automation.autoInboxIntelEnabled;
        _autoUsageIntelEnabled = automation.autoUsageIntelEnabled;
        _nextMinutesController.text = automation.availableMinutes.toString();
        _energy = automation.energy;
        _mode = automation.mode;
        _autoModeContextController.text = automation.modeContext;
        _autoWeeklyGoalsController.text = automation.weeklyGoals.join('\n');
        _autoWeeklyEventsController.text = jsonEncode(automation.weeklyEvents);
      });
      _loadCachedWeeklyPlan();
      _autoWeeklyGoalsController.addListener(_persistAutoWeeklyData);
      _autoWeeklyEventsController.addListener(_persistAutoWeeklyData);
    });
  }

  Future<void> _loadCachedWeeklyPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache.weekly_plan');
      if (cached == null || cached.isEmpty) return;
      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      setState(() {
        _weeklyResult = WeeklyScheduleResult.fromJson(decoded);
      });
    } catch (_) {
      // ignore cache read errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final neon = const Color(0xFF64D2FF);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF05060A),
            Color(0xFF0A0F1E),
            Color(0xFF11172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHero(neon),
            const SizedBox(height: 20),
            _buildWebSearchCard(neon),
            const SizedBox(height: 20),
            _buildWebScrapeCard(neon),
            const SizedBox(height: 20),
            _buildImageGenerationCard(neon),
            const SizedBox(height: 20),
            _buildDailyBriefingCard(neon),
            const SizedBox(height: 20),
            _buildNextActionCard(neon),
            const SizedBox(height: 20),
            _buildModeDecisionCard(neon),
            const SizedBox(height: 20),
            _buildInboxIntelCard(neon),
            const SizedBox(height: 20),
            _buildNotificationTriageCard(neon),
            const SizedBox(height: 20),
            _buildWeeklyScheduleCard(neon),
            const SizedBox(height: 20),
            _buildMemoryCard(neon),
            const SizedBox(height: 20),
            _buildAutomationCard(neon),
            const SizedBox(height: 20),
            _buildSensorsCard(neon),
            const SizedBox(height: 20),
            _buildUsageIntelCard(neon),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(Color neon) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              neon.withOpacity(0.25),
              Colors.white.withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: neon.withOpacity(0.35)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'بهترین همراه هوشمند',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'با استفاده از این ابزار می‌توانید تجربه‌ای سریع، دقیق و هوشمند از پردازش داده داشته باشید.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSearchCard(Color neon) {
    return AnimatedCard(
      child: Form(
        key: _searchFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: neon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.travel_explore, color: neon, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'وب سرچ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'پرسش یا کلمه کلیدی',
                hintText: 'مثلاً بهترین لپ‌تاپ ۱۴ اینچ',
              ),
              validator: _requiredValidator,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _searchLanguage,
                    decoration: const InputDecoration(labelText: 'زبان'),
                    items: const [
                      DropdownMenuItem(value: 'fa', child: Text('فارسی')),
                      DropdownMenuItem(value: 'en', child: Text('انگلیسی')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _searchLanguage = value ?? 'fa';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _maxSources,
                    decoration:
                        const InputDecoration(labelText: 'حداکثر منابع'),
                    items: List.generate(
                      5,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _maxSources = value ?? 3;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Temperature: ${_temperature.toStringAsFixed(1)}'),
                Slider(
                  activeColor: neon,
                  thumbColor: neon,
                  inactiveColor: Colors.white24,
                  value: _temperature,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  onChanged: (value) {
                    setState(() {
                      _temperature = value;
                    });
                  },
                ),
              ],
            ),
            ImprovedButton(
              onPressed: _searchLoading ? null : _handleWebSearch,
              icon: Icons.travel_explore,
              loading: _searchLoading,
              variant: ButtonVariant.elevated,
              child: const Text('جستجو'),
            ),
            const SizedBox(height: 16),
            if (_searchLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonList(itemCount: 2, itemHeight: 60),
              )
            else if (_searchResult != null)
              _WebSearchResult(result: _searchResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildWebScrapeCard(Color neon) {
    return AnimatedCard(
      child: Form(
        key: _scrapeFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: neon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.data_usage, color: neon, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'وب اسکرپ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _scrapeUrlController,
              decoration: const InputDecoration(
                labelText: 'آدرس صفحه',
                hintText: 'https://example.com/article',
              ),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('محدودیت کاراکتر: $_scrapeLimit'),
                      Slider(
                        activeColor: neon,
                        thumbColor: neon,
                        inactiveColor: Colors.white24,
                        value: _scrapeLimit.toDouble(),
                        min: 500,
                        max: 4000,
                        divisions: 7,
                        onChanged: (value) {
                          setState(() {
                            _scrapeLimit = value.round();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    value: _summarize,
                    title: const Text('خلاصه؟'),
                    subtitle: const Text('خلاصه متنی با پرامپت دلخواه'),
                    onChanged: (value) {
                      setState(() {
                        _summarize = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _scrapePromptController,
              decoration: const InputDecoration(
                labelText: 'پرامپت خلاصه (اختیاری)',
                hintText: 'یک خلاصه کوتاه بده',
              ),
            ),
            const SizedBox(height: 12),
            ImprovedButton(
              onPressed: _scrapeLoading ? null : _handleWebScrape,
              icon: Icons.data_usage,
              loading: _scrapeLoading,
              variant: ButtonVariant.elevated,
              child: const Text('دریافت محتوا'),
            ),
            const SizedBox(height: 16),
            if (_scrapeLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonLoader(height: 100),
              )
            else if (_scrapeResult != null)
              _WebScrapeResult(result: _scrapeResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGenerationCard(Color neon) {
    return AnimatedCard(
      child: Form(
        key: _imageFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: neon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.brush_outlined, color: neon, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تولید تصویر',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imagePromptController,
              decoration: const InputDecoration(
                labelText: 'پرامپت تصویر',
                hintText: 'A cozy workspace with neon lights',
              ),
              validator: _requiredValidator,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _responseFormat,
                    decoration: const InputDecoration(labelText: 'نوع پاسخ'),
                    items: const [
                      DropdownMenuItem(value: 'url', child: Text('URL')),
                      DropdownMenuItem(
                          value: 'b64_json', child: Text('Base64')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _responseFormat = value ?? 'url';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _imageSize,
                    decoration: const InputDecoration(labelText: 'سایز'),
                    items: const [
                      DropdownMenuItem(value: '1080x1920', child: Text('9:16')),
                      DropdownMenuItem(value: '1920x1080', child: Text('16:9')),
                      DropdownMenuItem(value: '1024x1024', child: Text('1:1')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _imageSize = value ?? '1024x1024';
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تعداد: $_imageCount'),
                Slider(
                  activeColor: neon,
                  thumbColor: neon,
                  inactiveColor: Colors.white24,
                  value: _imageCount.toDouble(),
                  min: 1,
                  max: 4,
                  divisions: 3,
                  label: '$_imageCount',
                  onChanged: (value) {
                    setState(() {
                      _imageCount = value.round();
                    });
                  },
                ),
              ],
            ),
            ImprovedButton(
              onPressed: _imageLoading ? null : _handleImageGeneration,
              icon: Icons.brush_outlined,
              loading: _imageLoading,
              variant: ButtonVariant.elevated,
              child: const Text('تولید تصویر'),
            ),
            const SizedBox(height: 16),
            if (_imageLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_images.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final item = _images[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Material(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: InkWell(
                        onTap: () => _showImagePreview(item),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image(
                                fit: BoxFit.cover,
                                image: item.provider,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('بارگذاری تصویر ناموفق بود.'),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in,
                                        size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'بزرگ‌نمایی',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _savingToGallery
                                    ? null
                                    : () => _saveToGallery(item),
                                icon: _savingToGallery
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.download, size: 16),
                                label: Text(
                                  _savingToGallery
                                      ? 'در حال ذخیره...'
                                      : 'ذخیره در گالری',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWebSearch() async {
    if (!_searchFormKey.currentState!.validate()) return;

    setState(() {
      _searchLoading = true;
    });

    final api = context.read<ApiClient>();

    try {
      final response = await api.postJson(
        '/tools/web-search',
        body: {
          'query': _searchController.text.trim(),
          'language': _searchLanguage,
          'max_sources': _maxSources,
          'temperature': double.parse(_temperature.toStringAsFixed(1)),
        },
      );
      setState(() {
        _searchResult = response;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _searchLoading = false;
        });
      }
    }
  }

  Future<void> _handleWebScrape() async {
    if (!_scrapeFormKey.currentState!.validate()) return;

    setState(() {
      _scrapeLoading = true;
    });

    final api = context.read<ApiClient>();

    try {
      final response = await api.postJson(
        '/tools/web-scrape',
        body: {
          'url': _scrapeUrlController.text.trim(),
          'limit': _scrapeLimit,
          'summarize': _summarize,
          'summary_prompt': _scrapePromptController.text.trim().isEmpty
              ? null
              : _scrapePromptController.text.trim(),
        },
      );
      setState(() {
        _scrapeResult = response;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _scrapeLoading = false;
        });
      }
    }
  }

  Future<void> _handleImageGeneration() async {
    if (!_imageFormKey.currentState!.validate()) return;

    setState(() {
      _imageLoading = true;
    });

    final api = context.read<ApiClient>();

    try {
      final response = await api.postJson(
        '/tools/image-generation',
        body: {
          'prompt': _imagePromptController.text.trim(),
          'model': _imageModelController.text.trim().isEmpty
              ? null
              : _imageModelController.text.trim(),
          'provider': _imageProviderController.text.trim().isEmpty
              ? null
              : _imageProviderController.text.trim(),
          'response_format': _responseFormat,
          'size': _imageSize,
          'n': _imageCount,
        },
      );

      final rawImages = response['images'] as List<dynamic>? ?? <dynamic>[];

      final parsed = rawImages
          .map((item) {
            final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
            final url = map['url']?.toString();
            final base64 = map['b64_json']?.toString();

            if (url != null && url.isNotEmpty) {
              return _GeneratedImage(url: url);
            }
            if (base64 != null && base64.isNotEmpty) {
              return _GeneratedImage(bytes: base64Decode(base64));
            }
            return const _GeneratedImage();
          })
          .where((img) => img.isValid)
          .toList();

      setState(() {
        _images = parsed;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _imageLoading = false;
        });
      }
    }
  }

  Future<void> _showImagePreview(_GeneratedImage image) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image(
                    image: image.provider,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('بارگذاری تصویر ناموفق بود.'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text(
                      'بستن',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _savingToGallery
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _saveToGallery(image);
                          },
                    icon: const Icon(Icons.download),
                    label: const Text('ذخیره در گالری'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveToGallery(_GeneratedImage image) async {
    if (_savingToGallery) return;

    setState(() {
      _savingToGallery = true;
    });

    try {
      final bytes = await image.bytesData();
      final fileName =
          'waiq_image_${DateTime.now().millisecondsSinceEpoch}.png';

      final result = await SaverGallery.saveImage(
        bytes,
        quality: 100,
        fileName: fileName,
        androidRelativePath: 'Pictures',
        skipIfExists: false,
      );

      final isSuccess = result.isSuccess;
      if (!mounted) return;

      final message = isSuccess
          ? 'تصویر با موفقیت در گالری ذخیره شد.'
          : 'ذخیره تصویر ناموفق بود. دوباره تلاش کنید.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _savingToGallery = false;
        });
      }
    }
  }

  Widget _buildDailyBriefingCard(Color neon) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.wb_twighlight,
            color: neon,
            title: 'خلاصه روز هوشمند',
            subtitle: '/assistant/daily-briefing',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _briefingNotesController,
            decoration: const InputDecoration(
              labelText: 'context / notes (اختیاری)',
              hintText: 'کارهای مهم، پیام‌های جدید، حس کلی...',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ImprovedButton(
              onPressed: _briefingLoading ? null : _runDailyBriefing,
              child: _briefingLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('دریافت خلاصه'),
            ),
          ),
          if (_dailyBriefingResult != null) ...[
            const SizedBox(height: 12),
            Text(
              'متن خلاصه',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            MarkdownText(
              data: _dailyBriefingResult!.payload.briefing.isEmpty
                  ? 'گزارش خالی بود.'
                  : _dailyBriefingResult!.payload.briefing,
            ),
            if (_dailyBriefingResult!.payload.highlights.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'هایلایت‌ها',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ..._dailyBriefingResult!.payload.highlights
                  .map((h) => Text('• $h')),
            ],
          ],
          if (_opsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _opsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextActionCard(Color neon) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.bolt,
            color: neon,
            title: 'الان چی انجام بدم؟',
            subtitle: '/assistant/next-action',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nextMinutesController,
                  decoration: const InputDecoration(
                    labelText: 'زمان آزاد (دقیقه)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _energy,
                  decoration: const InputDecoration(labelText: 'انرژی'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) =>
                      setState(() => _energy = value ?? 'normal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _mode,
                  decoration: const InputDecoration(labelText: 'مود'),
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('Default')),
                    DropdownMenuItem(value: 'work', child: Text('Work')),
                    DropdownMenuItem(value: 'home', child: Text('Home')),
                    DropdownMenuItem(value: 'focus', child: Text('Focus')),
                    DropdownMenuItem(value: 'travel', child: Text('Travel')),
                  ],
                  onChanged: (value) =>
                      setState(() => _mode = value ?? 'default'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nextTasksController,
            decoration: const InputDecoration(
              labelText: 'تسک‌ها (هر خط یک مورد)',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ImprovedButton(
              onPressed: _nextActionLoading ? null : _runNextAction,
              child: _nextActionLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('پیشنهاد بگیر'),
            ),
          ),
          if (_nextActionResult != null) ...[
            const SizedBox(height: 12),
            Text(
              'پیشنهاد اصلی: ${_nextActionResult!.suggested.title}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(_nextActionResult!.suggested.reason),
            if (_nextActionResult!.alternatives.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'گزینه‌های دیگر',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ..._nextActionResult!.alternatives.map(
                (alt) => Text('• ${alt.title} — ${alt.reason}'),
              ),
            ],
          ],
          if (_opsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _opsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeDecisionCard(Color neon) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.auto_mode,
            color: neon,
            title: 'حالت‌های هوشمند',
            subtitle: '/assistant/modes/decide',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modeTextController,
            decoration: const InputDecoration(
              labelText: 'توضیح وضعیت فعلی',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modeContextController,
            decoration: const InputDecoration(
              labelText: 'context (JSON اختیاری)',
              hintText: '{"wifi":"office","location":"tehran"}',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _energy,
                  decoration: const InputDecoration(labelText: 'انرژی'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) =>
                      setState(() => _energy = value ?? 'normal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _mode,
                  decoration: const InputDecoration(labelText: 'مود فعلی'),
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('Default')),
                    DropdownMenuItem(value: 'work', child: Text('Work')),
                    DropdownMenuItem(value: 'home', child: Text('Home')),
                    DropdownMenuItem(value: 'focus', child: Text('Focus')),
                    DropdownMenuItem(value: 'travel', child: Text('Travel')),
                    DropdownMenuItem(value: 'sleep', child: Text('Sleep')),
                  ],
                  onChanged: (value) =>
                      setState(() => _mode = value ?? 'default'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ImprovedButton(
              onPressed: _modeLoading ? null : _runModeDecision,
              child: _modeLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تشخیص مود'),
            ),
          ),
          if (_modeDecisionResult != null) ...[
            const SizedBox(height: 12),
            Text(
              'مود پیشنهادی: ${_modeDecisionResult!.mode}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(_modeDecisionResult!.reason),
            if (_modeDecisionResult!.triggers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'تریگرها:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ..._modeDecisionResult!.triggers.map((t) => Text('• $t')),
            ],
          ],
          if (_opsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _opsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInboxIntelCard(Color neon) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.mark_email_unread,
            color: neon,
            title: 'Inbox Intelligence',
            subtitle: '/assistant/inbox/intel',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inboxMessageController,
            decoration: const InputDecoration(
              labelText: 'متن پیام',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inboxChannelController,
            decoration: const InputDecoration(
              labelText: 'کانال (whatsapp / telegram / sms / email)',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ImprovedButton(
              onPressed: _inboxLoading ? null : _runInboxIntel,
              child: _inboxLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تحلیل پیام'),
            ),
          ),
          if (_inboxIntelResult != null) ...[
            const SizedBox(height: 12),
            Text(
              'خلاصه:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            MarkdownText(data: _inboxIntelResult!.summary),
            if (_inboxIntelResult!.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'اکشن‌های پیشنهادی',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ..._inboxIntelResult!.actions.map(
                (a) => Text(
                  '• ${a.type}: ${a.suggestedText}${a.when != null ? ' (${a.when})' : ''}',
                ),
              ),
            ],
          ],
          if (_opsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _opsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationTriageCard(Color neon) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.notifications_active,
            color: neon,
            title: 'مدیریت نوتیف هوشمند',
            subtitle: '/assistant/notifications/classify',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _triageInputController,
            decoration: const InputDecoration(
              labelText: 'لیست نوتیف (JSON array)',
              hintText: '[{\"title\":\"...\", \"body\":\"...\"}]',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _triageMode,
            decoration: const InputDecoration(labelText: 'مود'),
            items: const [
              DropdownMenuItem(value: 'default', child: Text('Default')),
              DropdownMenuItem(value: 'work', child: Text('Work')),
              DropdownMenuItem(value: 'home', child: Text('Home')),
              DropdownMenuItem(value: 'focus', child: Text('Focus')),
              DropdownMenuItem(value: 'travel', child: Text('Travel')),
            ],
            onChanged: (value) =>
                setState(() => _triageMode = value ?? 'default'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ImprovedButton(
              onPressed: _triageLoading ? null : _runNotificationTriage,
              child: _triageLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('طبقه‌بندی'),
            ),
          ),
          if (_triageResult != null) ...[
            const SizedBox(height: 12),
            ..._triageResult!.classified.map(
              (item) => Text(
                '• ${item.title} → ${item.category} (${item.suggestedAction})',
              ),
            ),
            if (_triageResult!.summary != null) ...[
              const SizedBox(height: 8),
              Text(_triageResult!.summary!),
            ],
          ],
          if (_opsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _opsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyScheduleCard(Color neon) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.calendar_month,
            color: neon,
            title: 'برنامه‌ریز هفتگی',
            subtitle: '/assistant/scheduler/weekly',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weeklyGoalsController,
            decoration: const InputDecoration(
              labelText: 'اهداف (هر خط یک هدف)',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weeklyEventsController,
            decoration: const InputDecoration(
              labelText: 'رویدادهای ثابت (JSON array)',
              hintText:
                  '[{\"title\":\"جلسه\",\"day\":\"monday\",\"start\":\"09:00\",\"end\":\"10:00\"}]',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ImprovedButton(
              onPressed: _calendarLoading ? null : _fetchCalendarBusy,
              child: _calendarLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('خواندن رویدادهای تقویم (۷ روز آینده)'),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ImprovedButton(
              onPressed: _weeklyLoading ? null : _runWeeklySchedule,
              child: _weeklyLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('برنامه بساز'),
            ),
          ),
          if (_weeklyResult != null) ...[
            const SizedBox(height: 12),
            ..._weeklyResult!.plan.map(
              (item) => Text(
                '• ${item.day} ${item.start}-${item.end}: ${item.title} (${item.reason})',
              ),
            ),
            if (_weeklyResult!.conflicts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'تداخل‌ها:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ..._weeklyResult!.conflicts.map((c) => Text('• $c')),
            ],
            const SizedBox(height: 8),
            ImprovedButton(
              onPressed: _rebuildWeeklyReminders,
              child: const Text('تولید یادآوری هفتگی'),
            ),
          ],
          if (_opsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _opsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemoryCard(Color neon) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.self_improvement,
            color: neon,
            title: 'خودمراقبتی',
            subtitle: '/assistant/self-care',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoryKeyController,
            decoration: const InputDecoration(
              labelText: 'نام پروفایل (مثلاً: من)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoryFactsController,
            decoration: const InputDecoration(
              labelText: 'ویژگی‌ها و عادت‌ها (هر خط یک مورد)',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _selfCareDurationController,
            decoration: const InputDecoration(
              labelText: 'طول برنامه (روز)',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ImprovedButton(
                  onPressed: _memoryUpserting ? null : _runMemoryUpsert,
                  child: _memoryUpserting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('ذخیره پروفایل'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ImprovedButton(
                  onPressed: _selfCarePlanLoading ? null : _runSelfCarePlan,
                  child: _selfCarePlanLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('دریافت برنامه پیشنهادی'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ImprovedButton(
              onPressed: _scheduleSelfCareReminders,
              child: const Text('فعال‌سازی یادآورها'),
            ),
          ),
          if (_memorySavedCount != null) ...[
            const SizedBox(height: 6),
            Text('تعداد ذخیره‌شده: $_memorySavedCount'),
          ],
          const Divider(height: 24),
          TextField(
            controller: _memoryQueryController,
            decoration: const InputDecoration(
              labelText: 'جستجوی پروفایل (نام)',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ImprovedButton(
              onPressed: _memorySearching ? null : _runMemorySearch,
              child: _memorySearching
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('یافتن پروفایل'),
            ),
          ),
          if (_memorySearchResult != null) ...[
            const SizedBox(height: 8),
            ..._memorySearchResult!.items
                .map((item) => Text('• ${item.key}: ${item.content}')),
          ],
          if (_selfCarePlanResult != null) ...[
            const SizedBox(height: 12),
            Text('برنامه پیشنهادی:',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            MarkdownText(data: _selfCarePlanResult!.summary),
            if (_selfCarePlanResult!.plan.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('برنامه روزانه:',
                  style: Theme.of(context).textTheme.titleMedium),
              ..._selfCarePlanResult!.plan.take(3).map((item) => Text(
                    '• روز ${item.day}: صبح: ${item.morning}, بعدازظهر: ${item.afternoon}, شام: ${item.evening}',
                  )),
              if (_selfCarePlanResult!.plan.length > 3)
                Text('... و ${_selfCarePlanResult!.plan.length - 3} روز دیگر'),
            ],
            if (_selfCarePlanResult!.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('اقدامات پیشنهادی:',
                  style: Theme.of(context).textTheme.titleMedium),
              ..._selfCarePlanResult!.actions
                  .map((a) => Text('• ${a.type}: ${a.suggestedText}')),
            ],
          ],
          if (_opsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _opsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutomationCard(Color neon) {
    final automation = context.read<AutomationService>();
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.sync,
            color: neon,
            title: 'اتوماسیون دستیار',
            subtitle: 'Next Action / Mode Check در پس‌زمینه',
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _autoNextEnabled,
            title: const Text('پیشنهاد خودکار “الان چی انجام بدم”'),
            subtitle: const Text('هر ساعت یک‌بار بر اساس زمان آزاد و انرژی'),
            onChanged: (value) async {
              setState(() => _autoNextEnabled = value);
              await automation.setAutoNextAction(
                enabled: value,
                minutes: int.tryParse(_nextMinutesController.text.trim()) ??
                    automation.availableMinutes,
                energy: _energy,
                mode: _mode,
              );
              setState(() => _opsError = null);
            },
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nextMinutesController,
                  decoration: const InputDecoration(
                    labelText: 'زمان آزاد پیش‌فرض (دقیقه)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final minutes = int.tryParse(value.trim());
                    if (minutes != null) {
                      automation.setAutoNextAction(
                        enabled: _autoNextEnabled,
                        minutes: minutes,
                        energy: _energy,
                        mode: _mode,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _energy,
                  decoration: const InputDecoration(labelText: 'انرژی پیش‌فرض'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) async {
                    setState(() => _energy = value ?? 'normal');
                    await automation.setAutoNextAction(
                      enabled: _autoNextEnabled,
                      energy: _energy,
                      mode: _mode,
                    );
                    setState(() => _opsError = null);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _mode,
            decoration: const InputDecoration(labelText: 'مود پیش‌فرض'),
            items: const [
              DropdownMenuItem(value: 'default', child: Text('Default')),
              DropdownMenuItem(value: 'work', child: Text('Work')),
              DropdownMenuItem(value: 'home', child: Text('Home')),
              DropdownMenuItem(value: 'focus', child: Text('Focus')),
              DropdownMenuItem(value: 'travel', child: Text('Travel')),
              DropdownMenuItem(value: 'sleep', child: Text('Sleep')),
            ],
            onChanged: (value) async {
              setState(() => _mode = value ?? 'default');
              await automation.setAutoNextAction(
                enabled: _autoNextEnabled,
                energy: _energy,
                mode: _mode,
              );
            },
          ),
          const Divider(height: 24),
          SwitchListTile(
            value: _autoModeEnabled,
            title: const Text('تشخیص خودکار مود'),
            subtitle: const Text('هر ۲ ساعت یک‌بار و با تغییر کانتکست'),
            onChanged: (value) async {
              setState(() => _autoModeEnabled = value);
              await automation.setAutoMode(
                enabled: value,
                energy: _energy,
                mode: _mode,
                contextJson: _autoModeContextController.text.trim(),
              );
              setState(() => _opsError = null);
            },
          ),
          TextField(
            controller: _autoModeContextController,
            decoration: const InputDecoration(
              labelText: 'context (JSON)',
              hintText: '{"wifi":"office","location":"tehran"}',
            ),
            onSubmitted: (value) async {
              await automation.setAutoMode(
                enabled: _autoModeEnabled,
                energy: _energy,
                mode: _mode,
                contextJson: value.trim(),
              );
            },
          ),
          const Divider(height: 24),
          SwitchListTile(
            value: _autoWeeklyEnabled,
            title: const Text('برنامه هفتگی خودکار'),
            subtitle:
                const Text('روزانه یک‌بار برنامه ۷ روز آینده ساخته می‌شود'),
            onChanged: (value) async {
              setState(() => _autoWeeklyEnabled = value);
              await automation.setAutoWeekly(
                enabled: value,
                goals: _lines(_autoWeeklyGoalsController.text),
                events: _decodeWeeklyEvents(_autoWeeklyEventsController.text),
              );
              setState(() => _opsError = null);
            },
          ),
          TextField(
            controller: _autoWeeklyGoalsController,
            decoration: const InputDecoration(
              labelText: 'اهداف خودکار (هر خط یک مورد)',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _autoWeeklyEventsController,
            decoration: const InputDecoration(
              labelText: 'رویدادهای ثابت (JSON)',
              hintText:
                  '[{"title":"جلسه","day":"monday","start":"09:00","end":"10:00"}]',
            ),
            maxLines: 3,
          ),
          const Divider(height: 24),
          SwitchListTile(
            value: _autoNotifTriageEnabled,
            title: const Text('طبقه‌بندی خودکار نوتیفیکیشن'),
            subtitle:
                const Text('هر ۳ ساعت یک‌بار نوتیف‌ها را دسته‌بندی می‌کند'),
            onChanged: (value) async {
              setState(() => _autoNotifTriageEnabled = value);
              await automation.setAutoNotifTriage(enabled: value);
              setState(() => _opsError = null);
            },
          ),
          const Divider(height: 24),
          SwitchListTile(
            value: _autoInboxIntelEnabled,
            title: const Text('تحلیل خودکار پیام‌ها'),
            subtitle:
                const Text('هر ۴ ساعت یک‌بار پیام‌های جدید را تحلیل می‌کند'),
            onChanged: (value) async {
              setState(() => _autoInboxIntelEnabled = value);
              await automation.setAutoInboxIntel(enabled: value);
              setState(() => _opsError = null);
            },
          ),
          const Divider(height: 24),
          SwitchListTile(
            value: _autoUsageIntelEnabled,
            title: const Text('گزارش خودکار مصرف اپ‌ها'),
            subtitle:
                const Text('روزانه یک‌بار گزارش استفاده از اپ‌ها را می‌دهد'),
            onChanged: (value) async {
              setState(() => _autoUsageIntelEnabled = value);
              await automation.setAutoUsageIntel(enabled: value);
              setState(() => _opsError = null);
            },
          ),
          if (_opsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _opsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSensorsCard(Color neon) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.wifi_tethering,
            color: neon,
            title: 'سنسورها',
            subtitle: 'دریافت SSID/WiFi برای مود هوشمند',
          ),
          const SizedBox(height: 8),
          ImprovedButton(
            onPressed: _wifiLoading ? null : _fetchWifiAndFillContext,
            child: _wifiLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('دریافت WiFi و اعمال در کانتکست مود'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageIntelCard(Color neon) {
    return AnimatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.bar_chart,
            color: neon,
            title: 'هوش مصرف اپ‌ها',
            subtitle: 'آخرین ۲۴ ساعت + خلاصه AI',
          ),
          const SizedBox(height: 12),
          ImprovedButton(
            onPressed: _usageLoading ? null : _runUsageIntel,
            child: _usageLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('تحلیل خودکار'),
          ),
          if (_usageStats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Top apps (دقیقه):',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._usageStats.map((item) {
              final name = (item['package']?.toString() ?? '').split('.').last;
              final minutes = (item['minutes'] as num?)?.toDouble() ?? 0;
              final maxMinutes = _usageStats
                  .map((e) => (e['minutes'] as num?)?.toDouble() ?? 0)
                  .fold<double>(0, (a, b) => a > b ? a : b);
              final ratio = maxMinutes == 0
                  ? 0.0
                  : (minutes / maxMinutes).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name — ${minutes.toStringAsFixed(0)} دقیقه'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                    ),
                  ],
                ),
              );
            }),
          ],
          if (_usageIntel != null) ...[
            const SizedBox(height: 12),
            Text('خلاصه:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            MarkdownText(data: _usageIntel!.summary),
            if (_usageIntel!.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('پیشنهادها:',
                  style: Theme.of(context).textTheme.titleMedium),
              ..._usageIntel!.actions.map((a) => Text(
                  '• ${a.type}: ${a.suggestedText}${a.when != null ? ' (${a.when})' : ''}')),
            ],
          ],
          if (_opsError != null) ...[
            const SizedBox(height: 8),
            Text(
              _opsError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Row _cardHeader({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
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
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _runDailyBriefing() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _briefingLoading = true;
      _opsError = null;
    });
    try {
      final now = DateTime.now();
      final contextMap = _decodeContext(_briefingNotesController.text);
      final result = await assistant.dailyBriefing(
        DailyBriefingRequest(
          timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
          now: now,
          context: contextMap,
        ),
      );
      setState(() => _dailyBriefingResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _briefingLoading = false);
    }
  }

  Future<void> _runNextAction() async {
    final assistant = context.read<AssistantService>();
    final minutes = int.tryParse(_nextMinutesController.text.trim());
    if (minutes == null || minutes <= 0) {
      setState(() => _opsError = 'زمان آزاد نامعتبر است');
      return;
    }
    setState(() {
      _nextActionLoading = true;
      _opsError = null;
    });
    try {
      final tasks = _lines(_nextTasksController.text);
      final result = await assistant.nextAction(
        NextActionRequest(
          availableMinutes: minutes,
          energy: _energy,
          mode: _mode,
          tasks: tasks,
        ),
      );
      setState(() => _nextActionResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _nextActionLoading = false);
    }
  }

  Future<void> _runModeDecision() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _modeLoading = true;
      _opsError = null;
    });
    try {
      final now = DateTime.now();
      final contextMap = _decodeContext(_modeContextController.text);
      final result = await assistant.decideMode(
        ModeDecisionRequest(
          text: _modeTextController.text.trim(),
          timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
          now: now,
          mode: _mode,
          energy: _energy,
          context: contextMap,
        ),
      );
      setState(() => _modeDecisionResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _modeLoading = false);
    }
  }

  Future<void> _runInboxIntel() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _inboxLoading = true;
      _opsError = null;
    });
    try {
      final result = await assistant.inboxIntel(
        InboxIntelRequest(
          message: _inboxMessageController.text.trim(),
          channel: _inboxChannelController.text.trim().isEmpty
              ? 'sms'
              : _inboxChannelController.text.trim(),
        ),
      );
      setState(() => _inboxIntelResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _inboxLoading = false);
    }
  }

  Future<void> _runNotificationTriage() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _triageLoading = true;
      _opsError = null;
    });
    try {
      final jsonList = jsonDecode(_triageInputController.text.trim());
      final items = List<Map<String, dynamic>>.from(
        (jsonList as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final now = DateTime.now();
      final result = await assistant.classifyNotifications(
        NotificationTriageRequest(
          notifications: items,
          mode: _triageMode,
          timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
        ),
      );
      setState(() => _triageResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _triageLoading = false);
    }
  }

  Future<void> _runWeeklySchedule() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _weeklyLoading = true;
      _opsError = null;
    });
    try {
      final goals = _lines(_weeklyGoalsController.text);
      final hardEventsJson = _weeklyEventsController.text.trim().isEmpty
          ? <dynamic>[]
          : jsonDecode(_weeklyEventsController.text.trim());
      final hardEvents = List<Map<String, dynamic>>.from(
        (hardEventsJson as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final now = DateTime.now();
      final result = await assistant.weeklySchedule(
        WeeklyScheduleRequest(
          goals: goals,
          hardEvents: hardEvents,
          timezone: now.timeZoneName.isEmpty ? 'Asia/Tehran' : now.timeZoneName,
          now: now,
          context: <String, dynamic>{
            'week_start': 'saturday',
            'week_end': 'friday',
            'locale': 'fa-IR',
          },
        ),
      );
      setState(() => _weeklyResult = result);
      await _saveWeeklyPlanToCache(result);
      await WorkmanagerService.scheduleWeeklyPlanReminders(result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _weeklyLoading = false);
    }
  }

  Future<void> _saveWeeklyPlanToCache(WeeklyScheduleResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache.weekly_plan', jsonEncode(result.toJson()));
      await prefs.setString(
        'cache.weekly_plan_updated_at',
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> _persistAutoWeeklyData() async {
    try {
      final automation = context.read<AutomationService>();
      await automation.saveWeeklyData(
        goals: _lines(_autoWeeklyGoalsController.text),
        events: _decodeWeeklyEvents(_autoWeeklyEventsController.text),
      );
    } catch (_) {
      // silent
    }
  }

  Future<void> _rebuildWeeklyReminders() async {
    final messenger = ScaffoldMessenger.of(context);
    WeeklyScheduleResult? result = _weeklyResult;
    if (result == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cache.weekly_plan');
        if (cached != null && cached.isNotEmpty) {
          result = WeeklyScheduleResult.fromJson(
              jsonDecode(cached) as Map<String, dynamic>);
        }
      } catch (_) {
        result = null;
      }
    }
    if (result == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('برنامه هفتگی پیدا نشد')),
      );
      return;
    }
    await WorkmanagerService.scheduleWeeklyPlanReminders(result);
    messenger.showSnackBar(
      const SnackBar(content: Text('یادآورها دوباره زمان‌بندی شد')),
    );
  }

  Future<void> _runMemoryUpsert() async {
    final assistant = context.read<AssistantService>();
    final facts = _lines(_memoryFactsController.text);
    if (_memoryKeyController.text.trim().isEmpty || facts.isEmpty) {
      setState(() => _opsError = 'کلید و حداقل یک Fact لازم است');
      return;
    }
    setState(() {
      _memoryUpserting = true;
      _opsError = null;
    });
    try {
      final result = await assistant.memoryUpsert(
        MemoryUpsertRequest(
          facts: facts,
          key: _memoryKeyController.text.trim(),
        ),
      );
      setState(() => _memorySavedCount = result.saved);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _memoryUpserting = false);
    }
  }

  Future<void> _runMemorySearch() async {
    final assistant = context.read<AssistantService>();
    if (_memoryQueryController.text.trim().isEmpty) {
      setState(() => _opsError = 'Query cannot be empty');
      return;
    }
    setState(() {
      _memorySearching = true;
      _opsError = null;
    });
    try {
      final result = await assistant.memorySearch(
        MemorySearchRequest(query: _memoryQueryController.text.trim()),
      );
      setState(() => _memorySearchResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _memorySearching = false);
    }
  }

  Future<void> _runSelfCarePlan() async {
    final assistant = context.read<AssistantService>();
    setState(() {
      _selfCarePlanLoading = true;
      _opsError = null;
    });
    try {
      final name = _memoryKeyController.text.trim();
      final traits = _lines(_memoryFactsController.text);
      final days = int.tryParse(_selfCareDurationController.text.trim()) ?? 14;

      final result = await assistant.selfCarePlan(
        SelfCarePlanRequest(
          name: name,
          traits: traits,
          durationDays: days,
        ),
      );
      setState(() => _selfCarePlanResult = result);
    } catch (e) {
      setState(() => _opsError = e.toString());
    } finally {
      setState(() => _selfCarePlanLoading = false);
    }
  }

  Future<void> _scheduleSelfCareReminders() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = _memoryKeyController.text.trim();
      if (name.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('ابتدا نام پروفایل را وارد کنید')),
        );
        return;
      }

      if (_selfCarePlanResult == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('ابتدا برنامه پیشنهادی را دریافت کنید')),
        );
        return;
      }

      final days = int.tryParse(_selfCareDurationController.text.trim()) ?? 14;
      final reminders = _selfCarePlanResult!.plan
          .map((item) => item.reminder)
          .where((r) => r.isNotEmpty)
          .toList();

      await WorkmanagerService.scheduleSelfCareReminders(
        profileName: name,
        reminders: reminders.isEmpty ? ['تمرین خودمراقبتی امروز'] : reminders,
        durationDays: days,
      );

      await context.read<NotificationService>().showLocalNow(
            title: 'خودمراقبتی فعال شد',
            body: '$days روز یادآور برای برنامه "$name" برنامه‌ریزی شد',
          );

      messenger.showSnackBar(
        const SnackBar(content: Text('یادآورهای خودمراقبتی فعال شدند')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('خطا در فعال‌سازی یادآورها: $e')),
      );
    }
  }

  Map<String, dynamic> _decodeContext(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (_) {
      return {'notes': raw};
    }
  }

  List<String> _lines(String raw) {
    return raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _decodeWeeklyEvents(String raw) {
    if (raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _fetchCalendarBusy() async {
    setState(() {
      _calendarLoading = true;
      _opsError = null;
    });
    try {
      final now = DateTime.now();
      final end = now.add(const Duration(days: 7));
      final events = await NativeBridge.getBusyEvents(start: now, end: end);
      if (events.isEmpty) {
        setState(() {
          _opsError = 'رویداد قابل خواندن یافت نشد (مجوز؟)';
        });
        return;
      }
      final mapped = events
          .map((e) => {
                'title': e['title'] ?? '',
                'day': DateTime.fromMillisecondsSinceEpoch(
                        (e['start'] as num).toInt())
                    .weekday,
                'start': DateTime.fromMillisecondsSinceEpoch(
                        (e['start'] as num).toInt())
                    .toIso8601String(),
                'end': DateTime.fromMillisecondsSinceEpoch(
                        (e['end'] as num).toInt())
                    .toIso8601String(),
              })
          .toList();
      _weeklyEventsController.text = jsonEncode(mapped);
    } catch (e) {
      setState(() => _opsError = 'خطا در خواندن تقویم: $e');
    } finally {
      setState(() => _calendarLoading = false);
    }
  }

  Future<void> _fetchWifiAndFillContext() async {
    setState(() {
      _wifiLoading = true;
      _opsError = null;
    });
    try {
      final ssid = await NativeBridge.getWifiSsid();
      if (ssid.isEmpty) {
        setState(() => _opsError = 'WiFi در دسترس نیست یا مجوز ندارد');
        return;
      }
      final ctx = _decodeContext(_autoModeContextController.text);
      ctx['wifi'] = ssid;
      _autoModeContextController.text = jsonEncode(ctx);
    } catch (e) {
      setState(() => _opsError = 'خطا در دریافت WiFi: $e');
    } finally {
      setState(() => _wifiLoading = false);
    }
  }

  Future<void> _runUsageIntel() async {
    setState(() {
      _usageLoading = true;
      _opsError = null;
    });
    try {
      final stats = await NativeBridge.getUsageStats();
      if (stats.isEmpty) {
        setState(() =>
            _opsError = 'داده‌ای از مصرف اپ یافت نشد (مجوز usage stats؟)');
        return;
      }
      setState(() => _usageStats = stats);
      final assistant = context.read<AssistantService>();
      final message = stats
          .take(10)
          .map((e) => '${e['package']}: ${e['minutes']} دقیقه')
          .join(' | ');
      final intel = await assistant.inboxIntel(
        InboxIntelRequest(
          message: 'مصرف اپ‌های ۲۴ ساعت اخیر: $message',
          channel: 'usage',
        ),
      );
      setState(() => _usageIntel = intel);
    } catch (e) {
      setState(() => _opsError = 'خطا: $e');
    } finally {
      setState(() => _usageLoading = false);
    }
  }

  void _showError(Object error) {
    final message = error is ApiException
        ? error.message
        : 'در برقراری ارتباط با سرور خطایی رخ داد.';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'این فیلد اجباری است.';
    }
    return null;
  }
}

class _WebSearchResult extends StatelessWidget {
  const _WebSearchResult({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final answer = result['answer']?.toString() ?? '';
    final sources = result['sources'] as List<dynamic>? ?? <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (answer.isNotEmpty) ...[
          Text(
            'پاسخ:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          MarkdownText(data: answer),
          const SizedBox(height: 12),
        ],
        if (sources.isNotEmpty) ...[
          Text(
            'منابع:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          ...sources.map(
            (item) {
              final map =
                  Map<String, dynamic>.from(item as Map<String, dynamic>);
              final title = map['title']?.toString() ?? '';
              final url = map['url']?.toString() ?? '';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  Icons.link,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(title.isEmpty ? 'منبع' : title),
                subtitle: Text(url),
                onTap:
                    url.isEmpty ? null : () => UrlLauncherService.openUrl(url),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _WebScrapeResult extends StatelessWidget {
  const _WebScrapeResult({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final summary = result['summary']?.toString() ?? '';
    final text = result['text']?.toString() ?? '';
    final title = result['title']?.toString() ?? '';
    final url = result['url']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
        ],
        if (url.isNotEmpty)
          TextButton.icon(
            onPressed: () => UrlLauncherService.openUrl(url),
            icon: const Icon(Icons.public),
            label: Text(
              url,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'خلاصه:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          MarkdownText(data: summary),
        ],
        if (text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'متن:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          MarkdownText(data: text, maxLines: 16),
        ],
      ],
    );
  }
}

class _GeneratedImage {
  const _GeneratedImage({this.url, this.bytes});

  final String? url;
  final Uint8List? bytes;

  bool get isValid => (url != null && url!.isNotEmpty) || bytes != null;

  ImageProvider get provider {
    if (url != null && url!.isNotEmpty) {
      return NetworkImage(url!);
    }
    return MemoryImage(bytes!);
  }

  Future<Uint8List> bytesData() async {
    if (bytes != null) return bytes!;
    if (url == null || url!.isEmpty) {
      throw const ApiException('هیچ داده‌ای برای تصویر موجود نیست.');
    }

    final response = await http.get(Uri.parse(url!));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'خطا در دریافت تصویر (کد: ${response.statusCode}).',
      );
    }
    return response.bodyBytes;
  }
}
