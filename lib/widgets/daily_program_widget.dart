
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/program_service.dart';
import '../models/event.dart';

class DailyProgramWidget extends StatelessWidget {
  const DailyProgramWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final programService = Provider.of<ProgramService>(context);
    final events = programService.getTodayEvents();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.dailyProgram,
              style: Theme.of(context).textTheme.headline6,
            ),
            const SizedBox(height: 8),
            if (events.isEmpty)
              Text(l10n.noEvents)
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return ListTile(
                    title: Text(event.title),
                    subtitle: Text(event.time),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
