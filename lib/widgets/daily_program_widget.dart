import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/daily_program_models.dart';
import '../services/daily_program_service.dart';
import '../services/service_providers.dart';



/// Daily Program Display Widget
class DailyProgramWidget extends ConsumerWidget {
  const DailyProgramWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(todayProgramProvider);
    final programService = ref.watch(dailyProgramServiceProvider);

    return programAsync.when(
      data: (program) {
        if (program == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No program for today',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    // This is a simplified call, you might need more user data
                    await programService.generateDailyProgram(
                      profile: ref.read(userProfileProvider), // Example: get user profile
                      goals: ref.read(userGoalsProvider),     // Example: get user goals
                      habits: ref.read(userHabitsProvider),    // Example: get user habits
                      currentMood: 0.5, // Example: get current mood
                      currentEnergy: 0.7, // Example: get current energy
                      date: DateTime.now(),
                    );
                  },
                  child: const Text('Generate Program'),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Program Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Program',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date: ${DateFormat('yyyy/MM/dd').format(program.date)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            // Time Blocks
            Expanded(
              child: ListView.builder(
                itemCount: program.activities.length,
                itemBuilder: (context, index) {
                  final activity = program.activities[index];
                  return TimeBlockItem(
                    block: activity,
                    programId: program.id, // Assuming program has an id
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

/// Individual Time Block
class TimeBlockItem extends ConsumerWidget {
  final ProgramActivity block;
  final String programId;

  const TimeBlockItem({
    Key? key,
    required this.block,
    required this.programId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(block.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${DateFormat('HH:mm').format(block.startTime)} - ${block.endTime.difference(block.startTime).inMinutes} min',
              style: const TextStyle(fontSize: 12),
            ),
            if (block.description != null) ...[
              const SizedBox(height: 4),
              Text(
                block.description!,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        onTap: () {
          _showBlockOptions(context, ref);
        },
      ),
    );
  }

  void _showBlockOptions(BuildContext context, WidgetRef ref) {
    final programService = ref.watch(dailyProgramServiceProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('Complete'),
              onTap: () async {
                Navigator.pop(context);
                await programService.completeActivity(activityId: block.id, completed: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, ref);
              },
            ),
             ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Remove'),
              onTap: () async {
                Navigator.pop(context);
                await programService.removeActivity(block.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final programService = ref.read(dailyProgramServiceProvider);
    final _titleController = TextEditingController(text: block.title);
    final _descriptionController = TextEditingController(text: block.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await programService.editActivity(
                activityId: block.id,
                title: _titleController.text,
                description: _descriptionController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
