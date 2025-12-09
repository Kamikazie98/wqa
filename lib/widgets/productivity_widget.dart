
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/productivity_controller.dart';

class ProductivityWidget extends ConsumerWidget {
  const ProductivityWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productivityAsync = ref.watch(productivityControllerProvider);

    return productivityAsync.when(
      data: (analysis) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productivity Analysis',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Overall Score:'),
                    Text(
                      analysis.overallProductivityScore.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Schedule Health:'),
                    Text(
                      analysis.scheduleHealthStatus,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Improvements:'),
                for (final improvement in analysis.improvements)
                  Text('- $improvement'),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
