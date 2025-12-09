
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/habit_controller.dart';
import '../models/user_models.dart';

class HabitStreakWidget extends ConsumerWidget {
  const HabitStreakWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitControllerProvider);

    return habitsAsync.when(
      data: (habits) {
        if (habits.isEmpty) {
          return const Center(child: Text('No habits tracked yet.'));
        }
        return ListView.builder(
          itemCount: habits.length,
          itemBuilder: (context, index) {
            final habit = habits[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text(habit.name),
                subtitle: Text(habit.description ?? ''),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Streak'),
                    Text(
                      '${habit.currentStreak}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
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
