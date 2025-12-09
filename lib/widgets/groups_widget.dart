
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../controllers/groups_controller.dart';

class GroupsWidget extends ConsumerWidget {
  const GroupsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final groupsAsync = ref.watch(groupsControllerProvider);

    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return Center(child: Text(l10n.noGroupsYet));
        }
        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: const Icon(Icons.group),
                title: Text(group.name),
                subtitle: Text(group.description),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text(l10n.error(error.toString()))),
    );
  }
}
