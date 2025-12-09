
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/settings_service.dart';
import '../../widgets/settings_button.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsService = Provider.of<SettingsService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: ListView(
        children: [
          SettingsButton(
            title: l10n.clearCacheConfirmation,
            description: l10n.clearCacheDescription,
            icon: Icons.delete,
            onPressed: () async {
              await settingsService.clearCache();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.cacheCleared)),
              );
            },
          ),
          SettingsButton(
            title: l10n.exportData,
            description: l10n.exportDataDescription,
            icon: Icons.cloud_upload,
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.exportingData)),
              );
              await settingsService.exportData();
            },
          ),
          SettingsButton(
            title: l10n.importData,
            description: l10n.importDataDescription,
            icon: Icons.cloud_download,
            onPressed: () {
              settingsService.importData();
            },
          ),
        ],
      ),
    );
  }
}
