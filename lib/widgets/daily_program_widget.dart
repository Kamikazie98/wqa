import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/daily_program_optimizer_service.dart';
import '../services/service_providers.dart';

/// Daily Program Display Widget
class DailyProgramWidget extends ConsumerWidget {
  const DailyProgramWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(todayProgramProvider);
    final programService = ref.watch(dailyProgramOptimizerServiceProvider);

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
                  'برنامه امروز موجود نیست',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await programService.generateDailyProgram(
                      date: DateTime.now(),
                    );
                  },
                  child: const Text('تولید برنامه'),
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
                    'برنامه امروز',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تاریخ: ${DateFormat('yyyy/MM/dd', 'fa_IR').format(program.date)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'تمرکز: ${program.focusArea}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'مدت زمان تخمینی: ${program.estimatedCompletionMinutes} دقیقه',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Time Blocks
            Expanded(
              child: ListView.builder(
                itemCount: program.timeBlocks.length,
                itemBuilder: (context, index) {
                  final block = program.timeBlocks[index];
                  return TimeBlockItem(
                    block: block,
                    programId: program.programId,
                  );
                },
              ),
            ),
            // Tips Section
            if (program.optimizationTips.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نکات بهتری برای امروز:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Text(program.optimizationTips),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('خطا: $error')),
    );
  }
}

/// Individual Time Block
class TimeBlockItem extends ConsumerWidget {
  final TimeBlock block;
  final String programId;

  const TimeBlockItem({
    Key? key,
    required this.block,
    required this.programId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programService = ref.watch(dailyProgramOptimizerServiceProvider);

    Color statusColor() {
      switch (block.status) {
        case 'completed':
          return Colors.green;
        case 'in_progress':
          return Colors.blue;
        case 'pending':
          return Colors.orange;
        case 'skipped':
          return Colors.grey;
        default:
          return Colors.grey;
      }
    }

    String statusLabel() {
      switch (block.status) {
        case 'completed':
          return 'تکمیل شده';
        case 'in_progress':
          return 'در حال انجام';
        case 'pending':
          return 'منتظر';
        case 'skipped':
          return 'صرف نظر شده';
        default:
          return 'نامشخص';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 4,
          color: statusColor(),
        ),
        title: Text(block.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${DateFormat('HH:mm', 'fa_IR').format(block.startTime)} - '
              '${block.durationMinutes} دقیقه',
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
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            statusLabel(),
            style: TextStyle(
              fontSize: 11,
              color: statusColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {
          _showBlockOptions(context, ref);
        },
      ),
    );
  }

  void _showBlockOptions(BuildContext context, WidgetRef ref) {
    final programService = ref.watch(dailyProgramOptimizerServiceProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('تکمیل'),
              onTap: () async {
                Navigator.pop(context);
                await programService.completeBlock(programId, block.blockId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('شروع'),
              onTap: () async {
                Navigator.pop(context);
                await programService.completeBlock(
                  programId,
                  block.blockId,
                  actualDurationMinutes: 0,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.skip_next),
              title: const Text('صرف نظر'),
              onTap: () async {
                Navigator.pop(context);
                await programService.skipBlock(programId, block.blockId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('ویرایش'),
              onTap: () {
                Navigator.pop(context);
                // Show edit dialog
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Daily Program Generator Widget
class DailyProgramGeneratorWidget extends ConsumerStatefulWidget {
  const DailyProgramGeneratorWidget({Key? key}) : super(key: key);

  @override
  ConsumerState<DailyProgramGeneratorWidget> createState() =>
      _DailyProgramGeneratorWidgetState();
}

class _DailyProgramGeneratorWidgetState
    extends ConsumerState<DailyProgramGeneratorWidget> {
  String? selectedMood;
  String? selectedEnergy;
  String? selectedFocus;

  @override
  Widget build(BuildContext context) {
    final programService = ref.watch(dailyProgramOptimizerServiceProvider);
    final optimizationStatus = ref.watch(
      StreamProvider((fRef) => programService.optimizationStatusStream),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تولید برنامه شخصی‌شده',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Mood Selection
              Text('روحیه شما امروز:',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['خیلی بد', 'بد', 'متوسط', 'خوب', 'عالی'].map((mood) {
                  return ChoiceChip(
                    label: Text(mood),
                    selected: selectedMood == mood,
                    onSelected: (selected) {
                      setState(() => selectedMood = selected ? mood : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Energy Selection
              Text('انرژی شما:', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['پایین', 'متوسط', 'بالا'].map((energy) {
                  return ChoiceChip(
                    label: Text(energy),
                    selected: selectedEnergy == energy,
                    onSelected: (selected) {
                      setState(() => selectedEnergy = selected ? energy : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Focus Area Selection
              Text('تمرکز برای امروز:',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['کار', 'سلامت', 'یادگیری', 'شخصی'].map((focus) {
                  return ChoiceChip(
                    label: Text(focus),
                    selected: selectedFocus == focus,
                    onSelected: (selected) {
                      setState(() => selectedFocus = selected ? focus : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Generate Button
              optimizationStatus.when(
                data: (status) {
                  final isGenerating = status.status == 'generating' ||
                      status.status == 'processing';

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isGenerating
                          ? null
                          : () async {
                              await programService.generateDailyProgram(
                                date: DateTime.now(),
                                moodLevel: selectedMood,
                                energyLevel: selectedEnergy,
                                focusArea: selectedFocus,
                              );
                            },
                      icon: isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        isGenerating ? 'در حال تولید...' : 'تولید برنامه',
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null,
                    child: Text('در حال بارگذاری...'),
                  ),
                ),
                error: (error, stack) => Center(child: Text('خطا: $error')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
