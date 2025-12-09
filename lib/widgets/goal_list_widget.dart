
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/user_models.dart';
import '../services/service_providers.dart';
import 'empty_state.dart';

/// Goal List Widget with Real-time Updates
class GoalListWidget extends ConsumerWidget {
  final String? filterStatus;

  const GoalListWidget({
    Key? key,
    this.filterStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final goalsAsync = ref.watch(goalsStreamProvider);

    return goalsAsync.when(
      data: (goals) {
        // Filter goals
        var filteredGoals = goals;
        if (filterStatus != null) {
          filteredGoals = filteredGoals
              .where((g) => g.status.toJson() == filterStatus)
              .toList();
        }

        if (filteredGoals.isEmpty) {
          return EmptyState(
            icon: Icons.flag,
            title: l10n.noGoalsFound,
            message: '',
          );
        }

        return ListView.builder(
          itemCount: filteredGoals.length,
          itemBuilder: (context, index) {
            final goal = filteredGoals[index];
            return GoalListItem(goal: goal);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(l10n.error(error.toString()))),
    );
  }
}

/// Individual Goal List Item with Progress
class GoalListItem extends ConsumerWidget {
  final UserGoal goal;

  const GoalListItem({
    Key? key,
    required this.goal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final goalService = ref.watch(goalManagementServiceProvider);
    final milestonesAsync = ref.watch(
      FutureProvider((fRef) => goalService.getMilestones(goal.goalId)),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        title: Text(goal.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.progress(goal.progressPercentage.toStringAsFixed(1)),
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  l10n.deadline(DateFormat('yyyy/MM/dd', l10n.localeName).format(goal.deadline)),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progressPercentage / 100,
                minHeight: 6,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (goal.description != null) ...[
                  Text(
                    l10n.description,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(goal.description!),
                  const SizedBox(height: 16),
                ],
                Text(
                  l10n.milestones,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                milestonesAsync.when(
                  data: (milestones) {
                    if (milestones.isEmpty) {
                      return Text(l10n.noMilestones);
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: milestones.length,
                      itemBuilder: (context, index) {
                        final milestone = milestones[index];
                        return CheckboxListTile(
                          value: milestone.status == 'completed',
                          onChanged: (value) async {
                            await goalService.updateMilestone(
                              goal.goalId,
                              milestone.milestoneId,
                              status: value == true ? 'completed' : 'pending',
                            );
                          },
                          title: Text(milestone.title),
                          subtitle: Text(
                            l10n.deadline(DateFormat('yyyy/MM/dd', l10n.localeName).format(milestone.targetDate)),
                          ),
                          contentPadding: EdgeInsets.zero,
                        );
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Text(l10n.error(error.toString())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Goal Statistics Dashboard
class GoalStatsWidget extends ConsumerWidget {
  const GoalStatsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(
      FutureProvider((fRef) {
        final goalService = ref.watch(goalManagementServiceProvider);
        return goalService.getGoalStats();
      }),
    );

    return statsAsync.when(
      data: (stats) {
        if (stats == null) {
          return Center(child: Text(l10n.noDataAvailable));
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.goalStats,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _GoalStatCard(
                      label: l10n.totalGoals,
                      value: stats.totalGoals,
                      color: Colors.blue,
                    ),
                    _GoalStatCard(
                      label: l10n.active,
                      value: stats.activeGoals,
                      color: Colors.green,
                    ),
                    _GoalStatCard(
                      label: l10n.completed,
                      value: stats.completedGoals,
                      color: Colors.purple,
                    ),
                    _GoalStatCard(
                      label: l10n.onTrack,
                      value: stats.onTrackGoals,
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.averageProgress,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${stats.averageProgress.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.atRisk,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      stats.atRiskGoals.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(l10n.error(error.toString()))),
    );
  }
}

class _GoalStatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _GoalStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
