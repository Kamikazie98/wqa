import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: const Text(
        'اگر سوییچ اعلان خاکستری است: Settings > Apps > (waiq) > ⋮ > Allow restricted settings را بزن، قفل صفحه را باز کن و تأیید کن. سپس به Settings > Notifications > Device & app notifications برگرد و سوییچ را روشن کن. در HyperOS/MIUI اگر هنوز خاکستری بود، Battery را روی No restrictions بگذار و MIUI/HyperOS optimization را یک بار خاموش/روشن کن.',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

    // این دو تا پرمیشن سیستمی هستن، دیالوگ ندارن
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
                      isSystemPermission ? "باز کردن تنظیمات" : "فعال‌سازی"),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allRequiredGranted = notifGranted && locGranted;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (showRestrictedHint) _buildRestrictedSettingsHint(),
            // Header حرفه‌ای
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.lock_person, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "مجوزهای Waiq",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "برای کارکرد هوشمند، چند دسترسی لازم داریم. هر مورد را می‌توانی جداگانه مدیریت کنی.",
                          style: TextStyle(fontSize: 13),
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
                      "مجوزهای اصلی (درون‌اپی)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTile(
                      title: "نوتیفیکیشن",
                      description:
                          "برای ارسال اعلان‌های هوشمند و بروزرسانی رویدادها.",
                      granted: notifGranted,
                      icon: Icons.notifications_active,
                      onPressed: () async {
                        await Permission.notification.request();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: "موقعیت مکانی",
                      description:
                          "برای تشخیص حالت‌ها، اتوماسیون مکانی و سرویس سنس.",
                      granted: locGranted,
                      icon: Icons.location_on,
                      onPressed: () async {
                        await Permission.locationWhenInUse.request();
                        // درخواست پس‌زمینه هم (اگه سیستم اجازه بده)
                        await Permission.locationAlways.request();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: "تماس‌ها (Phone)",
                      description: "برای اجرای اتوماسیون‌های مربوط به تماس.",
                      granted: phoneGranted,
                      icon: Icons.phone,
                      onPressed: () async {
                        await Permission.phone.request();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: "پیامک (SMS)",
                      description: "برای ارسال/خواندن SMS در اتوماسیون‌ها.",
                      granted: smsGranted,
                      icon: Icons.sms,
                      onPressed: () async {
                        await Permission.sms.request();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: "میکروفون",
                      description: "برای دستیار صوتی و تعامل‌های مبتنی بر صدا.",
                      granted: micGranted,
                      icon: Icons.mic,
                      onPressed: () async {
                        await Permission.microphone.request();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: "تقویم",
                      description: "برای خواندن و مدیریت رویدادهای تقویم.",
                      granted: calendarGranted,
                      icon: Icons.event,
                      onPressed: () async {
                        await Permission.calendar.request();
                        await _refreshStatus();
                      },
                    ),

                    const SizedBox(height: 24),
                    Text(
                      "تنظیمات سیستمی (از تنظیمات اندروید)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildTile(
                      title: "Usage Access (خواندن اپ‌های در حال استفاده)",
                      description:
                          "برای فهمیدن اینکه الان کدام اپ در foreground است. بعد از باز شدن صفحه، Waiq را پیدا کن و Allow را فعال کن.",
                      granted:
                          false, // اینجا مستقیماً قابل‌چک‌کردن نیست، کاربر باید خودش فعال کند
                      icon: Icons.apps,
                      isSystemPermission: true,
                      onPressed: () async {
                        await _openUsageAccessSettings();
                      },
                    ),
                    _buildTile(
                      title: "Notification Listener",
                      description:
                          "این اجازه برای دریافت و تحلیل اطلاعات نوتیفیکیشن‌های دستگاه لازم است. برای فعال‌کردن: ۱) به Settings > Apps > (waiq) > Permissions > Allow restricted settings برو، ۲) سپس به Settings > Notifications > Device & app notifications برو و گزینه مربوطه را فعال کن. اگر روی گوشی‌های HyperOS/MIUI هستی، مطمئن شو Battery کنترل‌کننده No restrictions باشد و MIUI/HyperOS بهینه‌سازی غیرفعال است.",
                      granted: notifListenerGranted,
                      icon: Icons.notifications,
                      isSystemPermission: true,
                      onPressed: () async {
                        await _openNotificationListenerSettings();
                        await _refreshStatus();
                      },
                    ),
                    _buildTile(
                      title: "Battery Optimization",
                      description:
                          "برای جلوگیری از بستن خودکار Waiq در پس‌زمینه. در صفحه باز شده، اپ را روی \"No restrictions\" بگذار.",
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
                              // وقتی پرمیشن‌های ضروری اوکی شد، برو به صفحه اصلی
                              Navigator.pushReplacementNamed(context, '/');
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("ادامه به برنامه"),
                    ),
                    const SizedBox(height: 8),
                    if (!allRequiredGranted)
                      const Text(
                        "برای ادامه حداقل نوتیفیکیشن و موقعیت مکانی باید فعال باشند.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
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
