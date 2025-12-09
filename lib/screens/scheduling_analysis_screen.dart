import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/smart_scheduling_service.dart';

class SchedulingAnalysisScreen extends StatefulWidget {
  const SchedulingAnalysisScreen({super.key});

  @override
  State<SchedulingAnalysisScreen> createState() =>
      _SchedulingAnalysisScreenState();
}

class _SchedulingAnalysisScreenState extends State<SchedulingAnalysisScreen> {
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() => _isLoading = true);
    try {
      // This screen just displays the analysis from the service
      // The service is updated separately from the main app
      final schedulingService = context.read<SmartSchedulingService>();

      // If no current analysis exists, show empty state
      if (schedulingService.currentAnalysis == null) {
        setState(() =>
            _error = 'تجزیه‌ای دستیاب نیست. ابتدا برنامه را بروزرسانی کنید.');
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تجزیه زمان‌بندی'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAnalysis,
            tooltip: 'بروزرسانی',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('خطا: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAnalysis,
                        child: const Text('تلاش دوباره'),
                      ),
                    ],
                  ),
                )
              : Consumer<SmartSchedulingService>(
                  builder: (context, service, _) {
                    final analysis = service.currentAnalysis;

                    if (analysis == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bar_chart_outlined,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'تجزیه‌ای دستیاب نیست',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'روی دکمه بروزرسانی بزنید',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Health status
                            _buildHealthStatus(analysis),
                            const SizedBox(height: 24),

                            // Overall score
                            _buildOverallScore(analysis),
                            const SizedBox(height: 24),

                            // Recommendations
                            _buildRecommendations(analysis),
                            const SizedBox(height: 24),

                            // Improvements
                            _buildImprovements(analysis),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildHealthStatus(SchedulingAnalysis analysis) {
    final statusColors = {
      'optimal': Colors.green,
      'good': Colors.blue,
      'fair': Colors.orange,
      'poor': Colors.red,
    };

    final statusPersian = {
      'optimal': 'بهینه',
      'good': 'خوب',
      'fair': 'قابل قبول',
      'poor': 'ضعیف',
    };

    final color = statusColors[analysis.scheduleHealthStatus] ?? Colors.grey;
    final statusLabel = statusPersian[analysis.scheduleHealthStatus] ??
        analysis.scheduleHealthStatus;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'وضعیت برنامه',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(analysis.scheduleHealthStatus),
                    size: 48,
                    color: color,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'برنامه شما ${statusLabel.toLowerCase()} است',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallScore(SchedulingAnalysis analysis) {
    final score = analysis.overallProductivityScore;
    final scoreColor = _getScoreColor(score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'امتیاز بهره‌وری',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    backgroundColor: scoreColor.withOpacity(0.1),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: scoreColor,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      'از 100',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _getScoreInterpretation(score),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(SchedulingAnalysis analysis) {
    if (analysis.recommendations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'هیچ توصیه‌ای وجود ندارد',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'توصیه‌های برنامه',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...List.generate(
          analysis.recommendations.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRecommendationCard(analysis.recommendations[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(SchedulingRecommendation rec) {
    final scoreColor = _getScoreColor(rec.score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.taskTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rec.reason,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${rec.score.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'امتیاز',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (rec.factors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: rec.factors
                    .map(
                      (factor) => Chip(
                        label: Text(
                          factor,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: scoreColor.withOpacity(0.1),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: scoreColor),
                const SizedBox(width: 8),
                Text(
                  'زمان پیشنهادی: ${DateFormat('HH:mm').format(rec.recommendedTime)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovements(SchedulingAnalysis analysis) {
    if (analysis.improvements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'پیشنهادات بهبود',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: List.generate(
                analysis.improvements.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index < analysis.improvements.length - 1 ? 12 : 0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          analysis.improvements[index],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    return switch (status) {
      'optimal' => Icons.check_circle,
      'good' => Icons.thumb_up,
      'fair' => Icons.help,
      'poor' => Icons.warning,
      _ => Icons.help_outline,
    };
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _getScoreInterpretation(double score) {
    if (score >= 90) {
      return 'برنامه شما عالی است! فقط به انجام کارها ادامه دهید.';
    } else if (score >= 75) {
      return 'برنامه خوبی دارید. کمی بهبود می‌تونه کمک کنه.';
    } else if (score >= 60) {
      return 'برنامه شما قابل قبول است، اما مجال بهبود زیادی وجود دارد.';
    } else if (score >= 40) {
      return 'برنامه شما نیاز به تغییرات قابل توجهی دارد.';
    } else {
      return 'برنامه شما بسیار نیاز به بهبود دارد. توصیات زیر را دنبال کنید.';
    }
  }
}
