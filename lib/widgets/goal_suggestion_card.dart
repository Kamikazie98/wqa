
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/user_models.dart';
import '../services/local_nlp_processor.dart';

class GoalSuggestionCard extends StatelessWidget {
  final Goal suggestion;

  const GoalSuggestionCard({super.key, required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nlpProcessor = Provider.of<LocalNLPProcessor>(context, listen: false);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              suggestion.title,
              style: Theme.of(context).textTheme.headline6,
            ),
            const SizedBox(height: 8.0),
            Text(suggestion.description),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    nlpProcessor.recordGoalFeedback(suggestion.id, false);
                  },
                  child: Text(l10n.dislike),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () {
                    nlpProcessor.recordGoalFeedback(suggestion.id, true);
                  },
                  child: Text(l10n.like),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
