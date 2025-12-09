import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/analytics_service.dart';

/// Analytics dashboard page showing productivity insights
class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  int _selectedDays = 7;

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<AnalyticsService>();
    final productivityScore = analytics.calculateProductivityScore();
    final insights = analytics.getInsights();
    final aiStats = analytics.getAIAccuracyStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('آمار و تحلیل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportData(analytics),
            tooltip: 'خروجی داده‌ها',
          ),
        ],
      ),
      body: Container(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProductivityScoreCard(productivityScore),
              const SizedBox(height: 16),
              _buildInsightsCard(insights),
              const SizedBox(height: 16),
              _buildUsageChartCard(analytics),
              const SizedBox(height: 16),
              _buildActionTypesCard(analytics),
              const SizedBox(height: 16),
              _buildAIAccuracyCard(aiStats),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductivityScoreCard(int score) {
    final color = _getScoreColor(score);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: color, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'امتیاز بهره‌وری',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const Text(
                      'از 100',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getScoreDescription(score),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard(List<String> insights) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFF64D2FF)),
                SizedBox(width: 12),
                Text(
                  'بینش‌های هوشمند',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (insights.isEmpty)
              const Text(
                'هنوز داده کافی برای تحلیل وجود ندارد.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...insights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          insight,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageChartCard(AnalyticsService analytics) {
    final usageData = analytics.getUsageForLastNDays(_selectedDays);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, color: Color(0xFF64D2FF)),
                    SizedBox(width: 12),
                    Text(
                      'فعالیت روزانه',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 روز')),
                    ButtonSegment(value: 14, label: Text('14 روز')),
                    ButtonSegment(value: 30, label: Text('30 روز')),
                  ],
                  selected: {_selectedDays},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() => _selectedDays = newSelection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: _buildBarChart(usageData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'هنوز داده‌ای وجود ندارد',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data
                .map((d) => (d['total'] as int).toDouble())
                .reduce((a, b) => a > b ? a : b) *
            1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= data.length) return const Text('');
                final date = data[value.toInt()]['date'] as String;
                final day = date.split('-').last;
                return Text(
                  day,
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final dayData = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (dayData['total'] as int).toDouble(),
                color: const Color(0xFF64D2FF),
                width: _selectedDays <= 7 ? 20 : 10,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionTypesCard(AnalyticsService analytics) {
    final actionsByType = analytics.getActionsByType();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart, color: Color(0xFF64D2FF)),
                SizedBox(width: 12),
                Text(
                  'توزیع اقدامات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (actionsByType.isEmpty)
              const Text(
                'هنوز اقدامی ثبت نشده است.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...actionsByType.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildActionTypeRow(entry.key, entry.value),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTypeRow(String type, int count) {
    final total = context.read<AnalyticsService>().getTotalActionsCount();
    final percentage = total > 0 ? (count / total * 100).toInt() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _translateActionType(type),
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              '$count ($percentage%)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey.withOpacity(0.2),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF64D2FF)),
        ),
      ],
    );
  }

  Widget _buildAIAccuracyCard(Map<String, dynamic> stats) {
    final accuracyRate = (stats['accuracy_rate'] as double) * 100;
    final avgConfidence = (stats['avg_confidence'] as double) * 100;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: Color(0xFF64D2FF)),
                SizedBox(width: 12),
                Text(
                  'عملکرد هوش مصنوعی',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow('کل پیش‌بینی‌ها', '${stats['total_predictions']}'),
            _buildStatRow('پیش‌بینی‌های موفق', '${stats['successful']}'),
            _buildStatRow('نرخ دقت', '${accuracyRate.toInt()}%'),
            _buildStatRow('میانگین اطمینان', '${avgConfidence.toInt()}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFF8BC34A);
    if (score >= 40) return const Color(0xFFFFC107);
    return const Color(0xFFFF9800);
  }

  String _getScoreDescription(int score) {
    if (score >= 80) return 'عالی! شما در سطح بالایی از بهره‌وری هستید.';
    if (score >= 60) return 'خوب! می‌توانید با استفاده بیشتر بهبود یابید.';
    if (score >= 40)
      return 'معمولی. سعی کنید از ویژگی‌های بیشتری استفاده کنید.';
    return 'شروع کنید! استفاده مداوم نتایج بهتری دارد.';
  }

  String _translateActionType(String type) {
    const translations = {
      'reminder': 'یادآوری',
      'calendar_event': 'رویداد تقویم',
      'web_search': 'جستجوی وب',
      'call': 'تماس',
      'message': 'پیام',
      'note': 'یادداشت',
      'suggestion': 'پیشنهاد',
    };

    return translations[type] ?? type;
  }

  void _exportData(AnalyticsService analytics) {
    analytics.exportData();
    // In real app, save to file or share
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('داده‌ها آماده خروجی است')),
    );
  }
}
