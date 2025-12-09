import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/assistant_service.dart';
import '../services/automation_service.dart';
import '../models/assistant_models.dart';

/// Home screen widget for quick access to AI features
class QuickActionWidget extends StatefulWidget {
  const QuickActionWidget({super.key});

  @override
  State<QuickActionWidget> createState() => _QuickActionWidgetState();
}

class _QuickActionWidgetState extends State<QuickActionWidget> {
  NextActionResult? _nextAction;
  // Widget state tracking
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadQuickInfo();
  }

  Future<void> _loadQuickInfo() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final assistant = context.read<AssistantService>();
      final automation = context.read<AutomationService>();

      // Load next action suggestion
      final nextAction = await assistant.nextAction(
        NextActionRequest(
          availableMinutes: automation.availableMinutes,
          energy: automation.energy,
          mode: automation.mode,
        ),
      );

      if (mounted) {
        setState(() {
          _nextAction = nextAction;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF64D2FF).withOpacity(0.15),
            const Color(0xFF05060A).withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF64D2FF).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64D2FF).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _loading
            ? _buildLoadingState()
            : _nextAction != null
                ? _buildNextActionCard()
                : _buildEmptyState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64D2FF)),
        ),
      ),
    );
  }

  Widget _buildNextActionCard() {
    final suggestion = _nextAction!.suggested;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF64D2FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt,
                  color: Color(0xFF64D2FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'پیشنهاد هوشمند',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _loadQuickInfo,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            suggestion.reason,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (suggestion.durationEstimateMin != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: Color(0xFF64D2FF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${suggestion.durationEstimateMin} دقیقه',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 48,
            color: const Color(0xFF64D2FF).withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'هنوز پیشنهادی نداریم',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadQuickInfo,
            icon: const Icon(Icons.refresh),
            label: const Text('دریافت پیشنهاد'),
          ),
        ],
      ),
    );
  }
}
