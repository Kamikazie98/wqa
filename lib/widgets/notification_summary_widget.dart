import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_summarizer_service.dart';
import '../services/service_providers.dart';

/// Wrapper widget to safely load and display notification summary
class NotificationSummaryWidget extends ConsumerWidget {
  const NotificationSummaryWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaySummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        // Check if summary is empty (totalNotifications == 0 and all lists are empty)
        if (summary == null ||
            (summary.totalNotifications == 0 &&
                summary.importantMessages.isEmpty &&
                summary.criticalAlerts.isEmpty &&
                summary.actionItems.isEmpty)) {
          return const _EmptyState();
        }
        return _SummaryContent(summary: summary);
      },
      loading: () => const _LoadingState(),
      error: (error, stackTrace) {
        print('Error loading summary: $error\n$stackTrace');
        return const _ErrorState();
      },
    );
  }
}

/// Display content when summary is loaded
class _SummaryContent extends StatelessWidget {
  final NotificationSummary summary;

  const _SummaryContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header with overall stats
          _SummaryHeader(summary: summary),
          const SizedBox(height: 16),

          // Critical alerts section
          if (summary.criticalAlerts.isNotEmpty)
            _CriticalAlertsSection(alerts: summary.criticalAlerts),

          if (summary.criticalAlerts.isNotEmpty) const SizedBox(height: 16),

          // Important messages section
          if (summary.importantMessages.isNotEmpty)
            _ImportantMessagesSection(
              messages: summary.importantMessages,
            ),

          if (summary.importantMessages.isNotEmpty) const SizedBox(height: 16),

          // Action items section
          if (summary.actionItems.isNotEmpty)
            _ActionItemsSection(items: summary.actionItems),

          if (summary.actionItems.isNotEmpty) const SizedBox(height: 16),

          // AI Summary section
          if (summary.aiGeneratedSummary != null &&
              summary.aiGeneratedSummary!.isNotEmpty)
            _AISummarySection(summary: summary.aiGeneratedSummary!),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Header showing overall statistics
class _SummaryHeader extends StatelessWidget {
  final NotificationSummary summary;

  const _SummaryHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'خلاصه اعلان‌های امروز',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${summary.totalNotifications} اعلان',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: 'خوانده شده',
                value: summary.readCount.toString(),
                icon: Icons.done,
              ),
              _StatItem(
                label: 'خوانده نشده',
                value: summary.unreadCount.toString(),
                icon: Icons.mail_outline,
              ),
              _StatItem(
                label: 'موارد عمل',
                value: summary.actionItems.length.toString(),
                icon: Icons.assignment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual stat item
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Critical alerts section
class _CriticalAlertsSection extends StatelessWidget {
  final List<CriticalAlert> alerts;

  const _CriticalAlertsSection({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              'اعلان‌های بحرانی (${alerts.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...alerts.map((alert) => _CriticalAlertCard(alert: alert)),
      ],
    );
  }
}

/// Individual critical alert card
class _CriticalAlertCard extends StatelessWidget {
  final CriticalAlert alert;

  const _CriticalAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(
          left: BorderSide(
            color: Colors.red.shade400,
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            alert.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade600,
            ),
          ),
          if (alert.action != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  alert.action!,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Important messages section
class _ImportantMessagesSection extends StatelessWidget {
  final List<ImportantMessage> messages;

  const _ImportantMessagesSection({required this.messages});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mail, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'پیام‌های مهم (${messages.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...messages.take(5).map((msg) => _MessageCard(message: msg)),
      ],
    );
  }
}

/// Individual message card
class _MessageCard extends StatelessWidget {
  final ImportantMessage message;

  const _MessageCard({required this.message});

  Color _getImportanceColor(String importance) {
    switch (importance) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow.shade600;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          left: BorderSide(
            color: _getImportanceColor(message.importance),
            width: 3,
          ),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  message.sender,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      _getImportanceColor(message.importance).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message.importance,
                  style: TextStyle(
                    fontSize: 10,
                    color: _getImportanceColor(message.importance),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.subject,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.preview,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (message.keywords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: message.keywords.take(3).map((keyword) {
                return Chip(
                  label: Text(keyword),
                  labelStyle: const TextStyle(fontSize: 10),
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Action items section
class _ActionItemsSection extends StatelessWidget {
  final List<ActionItem> items;

  const _ActionItemsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.checklist, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'موارد عمل (${items.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _ActionItemCard(item: item)),
      ],
    );
  }
}

/// Individual action item card
class _ActionItemCard extends StatelessWidget {
  final ActionItem item;

  const _ActionItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Chip(
                label: Text(item.priority),
                labelStyle: const TextStyle(fontSize: 10, color: Colors.white),
                backgroundColor: _getPriorityColor(item.priority),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          if (item.dueDate != null || item.assignee != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.dueDate != null) ...[
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    item.dueDate!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                ],
                if (item.assignee != null) ...[
                  const Icon(Icons.person, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    item.assignee!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

/// AI Generated Summary section
class _AISummarySection extends StatelessWidget {
  final String summary;

  const _AISummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              const Text(
                'خلاصه هوشمند',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading state
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'در حال تجزیه و تحلیل اعلان‌ها...',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

/// Error state
class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'خرابی در دریافت خلاصه اعلان‌ها',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'هیچ اعلانی در این مدت وجود ندارد',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
