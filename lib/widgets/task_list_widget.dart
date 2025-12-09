import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/user_models.dart';
import '../services/service_providers.dart';

/// Task List Widget with Real-time Updates
class TaskListWidget extends ConsumerWidget {
  final String? filterStatus;
  final String? filterCategory;

  const TaskListWidget({
    Key? key,
    this.filterStatus,
    this.filterCategory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final taskService = ref.watch(taskManagementServiceProvider);

    return tasksAsync.when(
      data: (tasks) {
        // Filter tasks
        var filteredTasks = tasks;
        if (filterStatus != null) {
          filteredTasks =
              filteredTasks.where((t) => t.status == filterStatus).toList();
        }
        if (filterCategory != null) {
          filteredTasks =
              filteredTasks.where((t) => t.category == filterCategory).toList();
        }

        if (filteredTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'هیچ کار یافت نشد',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredTasks.length,
          itemBuilder: (context, index) {
            final task = filteredTasks[index];
            return TaskListItem(task: task);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('خطا: $error'),
      ),
    );
  }
}

/// Individual Task List Item
class TaskListItem extends ConsumerWidget {
  final UserTask task;

  const TaskListItem({
    Key? key,
    required this.task,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskService = ref.watch(taskManagementServiceProvider);

    Color priorityColor() {
      switch (task.priority) {
        case 1:
        case 2:
          return Colors.red;
        case 3:
        case 4:
          return Colors.orange;
        case 5:
          return Colors.green;
        default:
          return Colors.blue;
      }
    }

    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.status == 'completed',
          onChanged: (value) async {
            if (value == true) {
              await taskService.completeTask(task.taskId);
            }
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration:
                task.status == 'completed' ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null) ...[
              const SizedBox(height: 4),
              Text(
                task.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (task.dueDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'موعد: ${DateFormat('yyyy/MM/dd HH:mm', 'fa_IR').format(task.dueDate!)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: priorityColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'اولویت: ${task.priority}',
            style: TextStyle(
              fontSize: 12,
              color: priorityColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {
          // Navigate to task details
        },
      ),
    );
  }
}

/// Task Statistics Widget
class TaskStatsWidget extends ConsumerWidget {
  const TaskStatsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(taskStatsStreamProvider);

    return statsAsync.when(
      data: (stats) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آمار کارها',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      label: 'کل',
                      value: stats.total.toString(),
                      color: Colors.blue,
                    ),
                    _StatItem(
                      label: 'تکمیل شده',
                      value: stats.completed.toString(),
                      color: Colors.green,
                    ),
                    _StatItem(
                      label: 'در حال انجام',
                      value: stats.inProgress.toString(),
                      color: Colors.orange,
                    ),
                    _StatItem(
                      label: 'معوق',
                      value: stats.overdue.toString(),
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: stats.completionRate / 100,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'درصد تکمیل: ${stats.completionRate.toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('خطا: $error')),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
