import 'package:flutter/material.dart';

/// Widget to display AI confidence score with visual indicator
class ConfidenceIndicator extends StatelessWidget {
  const ConfidenceIndicator({
    super.key,
    required this.confidence,
    this.showLabel = true,
    this.showPercentage = true,
    this.size = IndicatorSize.medium,
  });

  final double confidence; // 0.0 to 1.0
  final bool showLabel;
  final bool showPercentage;
  final IndicatorSize size;

  @override
  Widget build(BuildContext context) {
    final level = _getConfidenceLevel();
    final color = _getConfidenceColor();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIndicatorBar(color),
        if (showLabel || showPercentage) const SizedBox(width: 8),
        if (showLabel || showPercentage)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLabel)
                Text(
                  level,
                  style: TextStyle(
                    color: color,
                    fontSize: _getFontSize(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (showPercentage)
                Text(
                  '${(confidence * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: _getFontSize() - 2,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildIndicatorBar(Color color) {
    final barHeight = size == IndicatorSize.small
        ? 20.0
        : size == IndicatorSize.medium
            ? 30.0
            : 40.0;

    final barWidth = size == IndicatorSize.small
        ? 60.0
        : size == IndicatorSize.medium
            ? 80.0
            : 100.0;

    return Container(
      width: barWidth,
      height: barHeight,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(barHeight / 2),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: confidence,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.7),
                    color,
                  ],
                ),
                borderRadius: BorderRadius.circular(barHeight / 2),
              ),
            ),
          ),
          Center(
            child: Text(
              '${(confidence * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: _getFontSize() - 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getConfidenceLevel() {
    if (confidence >= 0.9) return 'بسیار بالا';
    if (confidence >= 0.75) return 'بالا';
    if (confidence >= 0.6) return 'متوسط';
    if (confidence >= 0.4) return 'پایین';
    return 'بسیار پایین';
  }

  Color _getConfidenceColor() {
    if (confidence >= 0.9) return const Color(0xFF4CAF50);
    if (confidence >= 0.75) return const Color(0xFF8BC34A);
    if (confidence >= 0.6) return const Color(0xFFFFC107);
    if (confidence >= 0.4) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  double _getFontSize() {
    switch (size) {
      case IndicatorSize.small:
        return 10;
      case IndicatorSize.medium:
        return 12;
      case IndicatorSize.large:
        return 14;
    }
  }
}

enum IndicatorSize { small, medium, large }

/// Widget to show detailed confidence breakdown
class ConfidenceBreakdown extends StatelessWidget {
  const ConfidenceBreakdown({
    super.key,
    required this.breakdown,
  });

  final Map<String, double> breakdown;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'تحلیل اطمینان',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...breakdown.entries.map((entry) => _buildFactorRow(
                  context,
                  _getFactorLabel(entry.key),
                  entry.value,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFactorRow(BuildContext context, String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _getColorForValue(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(_getColorForValue(value)),
          ),
        ],
      ),
    );
  }

  String _getFactorLabel(String key) {
    const labels = {
      'input_clarity': 'وضوح درخواست',
      'pattern_match': 'تطابق الگو',
      'context_score': 'اطلاعات زمینه',
      'response_completeness': 'کامل بودن پاسخ',
      'historical_accuracy': 'دقت تاریخی',
    };

    return labels[key] ?? key;
  }

  Color _getColorForValue(double value) {
    if (value >= 0.75) return const Color(0xFF4CAF50);
    if (value >= 0.5) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }
}
