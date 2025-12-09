import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _pushNotifications = true;
  late bool _emailNotifications = false;
  late bool _soundEnabled = true;
  late bool _vibrationEnabled = true;
  late bool _darkTheme = true;
  late bool _persianLocale = true;
  late String _dataRetention = '30';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // بارگذاری تنظیمات ذخیره‌شده
    // مقدارهای پیش‌فرض در حال حاضر تنظیم شده‌اند
  }

  Future<void> _saveSettings() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تنظیمات ذخیره شد'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFF64D2FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === اعلان‌ها ===
          _buildSectionHeader('اعلان‌ها', neon),
          const SizedBox(height: 12),
          _buildToggleSetting(
            title: 'اعلان‌های پوش',
            subtitle: 'دریافت اعلان‌ها درون‌اپی',
            value: _pushNotifications,
            onChanged: (value) {
              setState(() => _pushNotifications = value);
              _saveSettings();
            },
            icon: Icons.notifications_active,
          ),
          const SizedBox(height: 8),
          _buildToggleSetting(
            title: 'اعلان‌های ایمیل',
            subtitle: 'دریافت ایمیل‌های خلاصه‌سازی',
            value: _emailNotifications,
            onChanged: (value) {
              setState(() => _emailNotifications = value);
              _saveSettings();
            },
            icon: Icons.email,
          ),
          const SizedBox(height: 8),
          _buildToggleSetting(
            title: 'صدا',
            subtitle: 'فعال‌سازی صدای اعلان‌ها',
            value: _soundEnabled,
            onChanged: (value) {
              setState(() => _soundEnabled = value);
              _saveSettings();
            },
            icon: Icons.volume_up,
          ),
          const SizedBox(height: 8),
          _buildToggleSetting(
            title: 'لرزش',
            subtitle: 'فعال‌سازی لرزش دستگاه',
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() => _vibrationEnabled = value);
              _saveSettings();
            },
            icon: Icons.vibration,
          ),
          const SizedBox(height: 20),

          // === نمایش ===
          _buildSectionHeader('نمایش', neon),
          const SizedBox(height: 12),
          _buildToggleSetting(
            title: 'تم تاریک',
            subtitle: 'استفاده از تم تاریک برنامه',
            value: _darkTheme,
            onChanged: (value) {
              setState(() => _darkTheme = value);
              _saveSettings();
            },
            icon: Icons.dark_mode,
          ),
          const SizedBox(height: 8),
          _buildToggleSetting(
            title: 'فارسی',
            subtitle: 'نمایش برنامه به زبان فارسی',
            value: _persianLocale,
            onChanged: (value) {
              setState(() => _persianLocale = value);
              _saveSettings();
            },
            icon: Icons.language,
          ),
          const SizedBox(height: 20),

          // === ذخیره‌سازی ===
          _buildSectionHeader('ذخیره‌سازی و داده‌ها', neon),
          const SizedBox(height: 12),
          _buildDropdownSetting(
            title: 'نگهداری داده‌ها',
            subtitle: 'مدت زمان نگهداری سابقه',
            value: _dataRetention,
            items: const {
              '7': '۷ روز',
              '14': '۱۴ روز',
              '30': '۳۰ روز',
              '60': '۶۰ روز',
              '90': '۹۰ روز',
              'unlimited': 'بی‌محدود',
            },
            onChanged: (value) {
              if (value != null) {
                setState(() => _dataRetention = value);
                _saveSettings();
              }
            },
            icon: Icons.storage,
          ),
          const SizedBox(height: 8),
          _buildActionSetting(
            title: 'پاک‌کردن حافظه نهان',
            subtitle: 'حذف فایل‌های موقت',
            icon: Icons.cleaning_services,
            onTap: () {
              _showConfirmDialog(
                'آیا می‌خواهید حافظه نهان پاک شود؟',
                'این کار اندازۀ برنامه را کاهش می‌دهد.',
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('حافظه نهان پاک شد')),
                  );
                  Navigator.pop(context);
                },
              );
            },
          ),
          const SizedBox(height: 8),
          _buildActionSetting(
            title: 'صادرات داده‌ها',
            subtitle: 'صادرات کل داده‌های شما',
            icon: Icons.download,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('داده‌ها در حال صادرات است...')),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildActionSetting(
            title: 'وارد‌کردن داده‌ها',
            subtitle: 'بازیابی از نسخۀ پشتیبان',
            icon: Icons.upload,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('درحال انتخاب فایل...')),
              );
            },
          ),
          const SizedBox(height: 20),

          // === امنیت ===
          _buildSectionHeader('امنیت و حریم‌خصوصی', neon),
          const SizedBox(height: 12),
          _buildActionSetting(
            title: 'تغییر رمز عبور',
            subtitle: 'به‌روزرسانی رمز عبور حساب شما',
            icon: Icons.lock,
            onTap: () {
              _showPasswordDialog();
            },
          ),
          const SizedBox(height: 8),
          _buildActionSetting(
            title: 'دو‌عاملی فعال‌سازی',
            subtitle: 'افزایش امنیت حساب',
            icon: Icons.security,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('فعال‌سازی دو‌عاملی در دست انجام است...')),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildActionSetting(
            title: 'خروج از تمام دستگاه‌ها',
            subtitle: 'پایان دادن به تمام جلسات فعال',
            icon: Icons.logout,
            onTap: () {
              _showConfirmDialog(
                'خروج از تمام دستگاه‌ها؟',
                'باید دوباره وارد شوید',
                () {
                  Navigator.pop(context);
                },
              );
            },
          ),
          const SizedBox(height: 20),

          // === حریم‌خصوصی ===
          _buildSectionHeader('حریم‌خصوصی', neon),
          const SizedBox(height: 12),
          _buildActionSetting(
            title: 'سیاست حریم‌خصوصی',
            subtitle: 'نحوۀ استفاده از داده‌ها',
            icon: Icons.privacy_tip,
            onTap: () {
              // باز کردن سیاست حریم‌خصوصی
            },
          ),
          const SizedBox(height: 8),
          _buildActionSetting(
            title: 'شرایط استفاده',
            subtitle: 'شرایط و ضوابط سرویس',
            icon: Icons.description,
            onTap: () {
              // باز کردن شرایط استفاده
            },
          ),
          const SizedBox(height: 8),
          _buildActionSetting(
            title: 'حذف حساب',
            subtitle: 'حذف دائمی حساب شما',
            icon: Icons.delete_forever,
            isDestructive: true,
            onTap: () {
              _showConfirmDialog(
                'حذف حساب؟',
                'این کار برگردان‌پذیر نیست. تمام داده‌ها حذف می‌شوند.',
                () {
                  Navigator.pop(context);
                },
              );
            },
          ),
          const SizedBox(height: 20),

          // === درباره ===
          _buildSectionHeader('درباره', neon),
          const SizedBox(height: 12),
          _buildInfoSetting(
            title: 'نسخه برنامه',
            value: 'v1.1.0',
            icon: Icons.info,
          ),
          const SizedBox(height: 8),
          _buildActionSetting(
            title: 'بررسی به‌روزرسانی‌ها',
            subtitle: 'دانلود نسخۀ جدید',
            icon: Icons.system_update,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('بررسی به‌روزرسانی‌ها...')),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildActionSetting(
            title: 'درباره WAIQ',
            subtitle: 'اطلاعات برنامه',
            icon: Icons.help,
            onTap: () {
              _showAboutDialog();
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSetting({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF64D2FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF64D2FF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF64D2FF),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String subtitle,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF64D2FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF64D2FF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            items: items.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: onChanged,
            underline: const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSetting({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : const Color(0xFF64D2FF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? Colors.red : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSetting({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF64D2FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF64D2FF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(
      String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: onConfirm,
            child: const Text(
              'تأیید',
              style: TextStyle(color: Color(0xFF64D2FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغییر رمز عبور'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'رمز عبور فعلی',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'رمز عبور جدید',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'تأیید رمز عبور',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('رمز عبور تغییر کرد')),
              );
            },
            child: const Text(
              'تأیید',
              style: TextStyle(color: Color(0xFF64D2FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'WAIQ',
      applicationVersion: 'v1.1.0',
      applicationLegalese: '© 2025 WAIQ. تمام حقوق محفوظ است.',
      children: [
        const SizedBox(height: 12),
        const Text(
          'WAIQ یک دستیار هوشمند هستی که برای کمک به مدیریت وقت و افزایش بهره‌وری طراحی شده است.',
        ),
      ],
    );
  }
}
