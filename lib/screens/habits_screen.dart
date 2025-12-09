
import 'package:flutter/material.dart';

import '../widgets/habit_streak_widget.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Streaks'),
      ),
      body: const HabitStreakWidget(),
    );
  }
}
