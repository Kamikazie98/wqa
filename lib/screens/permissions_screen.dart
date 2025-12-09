
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/native_bridge.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool showRestrictedHint = false;
  bool notifGranted = false;
  bool locGranted = false;
  bool phoneGranted = false;
  bool smsGranted = false;
  bool micGranted = false;
  bool calendarGranted = false;

  bool notifListenerGranted = false;
  bool batteryOptimizeIgnored = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Widget _buildRestrictedSettingsHint() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Text(
        l10n.restrictedSettingsHint,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _refreshStatus() async {
    notifGranted = await Permission.notification.isGranted;
    locGranted = await Permission.locationWhenInUse.isGranted;
    phoneGranted = await Permission.phone.isGranted;
    smsGranted = await Permission.sms.isGranted;
    micGranted = await Permission.microphone.isGranted;
    calendarGranted = await Permission.calendar.isGranted;

    // These two are system permissions, they don't have a dialog
    notifListenerGranted = await NativeBridge.isNotificationListenerEnabled();
    batteryOptimizeIgnored =
        await Permission.ignoreBatteryOptimizations.isGranted;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openAndroidSettings(String action) async {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(action: action);
    await intent.launch();
  }

  Future<void> _openUsageAccessSettings() async {
    await _openAndroidSettings('android.settings.USAGE_ACCESS_SETTINGS');
  }

  Future<void> _openNotificationListenerSettings() async {
    await _openAndroidSettings(
        'android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS');
  }

  Future<void> _openBatterySettings() async {
    await _openAndroidSettings(
        'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS');
  }

  Widget _buildTile({
    required String title,
    required String description,
    required bool granted,
    required VoidCallback onPressed,
    bool isSystemPermission = false,
    IconData? icon,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: granted
                ? Colors.green.withOpacity(0.12)
                : Colors.red.withOpacity(0.08),
            child: Icon(
              icon ?? Icons.shield,
              color: granted ? Colors.green : Colors.red,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              description,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          trailing: granted
              ? const Icon(Icons.check_circle, color: Colors.green)
              : ElevatedButton(
                  onPressed: onPressed,
                  child: Text(
                      isSystemPermission ? l10n.openSettings : l10n.activate),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allRequiredGranted = notifGranted && locGranted;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (showRestrictedHint) _buildRestrictedSettingsHint(),
            // Professional Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.lock_person, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.permissionsTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.permissionsDescription,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshStatus,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    // *** Runtime permissions ***
                    Text(
                      l10n.mainPermissions,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTile(
                      title: l10n.notification,
                      description:
                          l10n.notificationDescription,
                      granted: notifGranted,
                      icon: Icons.notifications_active,
                      onPressed: () async {
                        await Permission.notification.request();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: l10n.location,
                      description:
                          l10n.locationDescription,
                      granted: locGranted,
                      icon: Icons.location_on,
                      onPressed: () async {
                        await Permission.locationWhenInUse.request();
                        // Also request background permission (if the system allows)
                        await Permission.locationAlways.request();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: l10n.phone,
                      description: l10n.phoneDescription,
                      granted: phoneGranted,
                      icon: Icons.phone,
                      onPressed: () async {
                        await Permission.phone.request();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: l10n.sms,
                      description: l10n.smsDescription,
                      granted: smsGranted,
                      icon: Icons.sms,
                      onPressed: () async {
                        await Permission.sms.request();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: l10n.microphone,
                      description: l10n.microphoneDescription,
                      granted: micGranted,
                      icon: Icons.mic,
                      onPressed: () async {
                        await Permission.microphone.request();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: l10n.calendar,
                      description: l10n.calendarDescription,
                      granted: calendarGranted,
                      icon: Icons.event,
                      onPressed: () async {
                        await Permission.calendar.request();
                        await _refreshStatus();
                      },
                    ),

                    const SizedBox(height: 24),
                    Text(
                      l10n.systemSettings,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildTile(
                      title: l10n.usageAccess,
                      description:
                          l10n.usageAccessDescription,
                      granted:
                          false, // This cannot be checked directly, the user must enable it themselves
                      icon: Icons.apps,
                      isSystemPermission: true,
                      onPressed: () async {
                        await _openUsageAccessSettings();
                      },
                    ),
                    _buildTile(
                      title: l10n.notificationListener,
                      description:
                          l10n.notificationListenerDescription,
                      granted: notifListenerGranted,
                      icon: Icons.notifications,
                      isSystemPermission: true,
                      onPressed: () async {
                        await _openNotificationListenerSettings();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: l10n.batteryOptimization,
                      description:
                          l10n.batteryOptimizationDescription,
                      granted: batteryOptimizeIgnored,
                      icon: Icons.battery_saver,
                      isSystemPermission: true,
                      onPressed: () async {
                        await _openBatterySettings();
                        await _refreshStatus();
                      },
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: allRequiredGranted
                          ? () {
                              // When the necessary permissions are OK, go to the main page
                              Navigator.pushReplacementNamed(context, '/');
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(l10n.continueToApp),
                    ),
                    const SizedBox(height: 8),
                    if (!allRequiredGranted)
                      Text(
                        l10n.permissionsRequiredMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
