
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/activity_controller.dart';
import '../models/user_models.dart';

class ActivityNotificationWidget extends ConsumerWidget {
  const ActivityNotificationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activityControllerProvider);

    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) {
          return const Center(child: Text('No new activities.'));
        }
        return ListView.builder(
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: Icon(activity.getIcon()),
                title: Text(activity.title),
                subtitle: Text(activity.subtitle),
                trailing: Text(
                  activity.time,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

extension on Activity {
  IconData getIcon() {
    switch (type) {
      case 'event_start':
        return Icons.event;
      case 'event_end':
        return Icons.event_available;
      case 'goal_achieved':
        return Icons.flag;
      default:
        return Icons.notifications;
    }
  }
}
