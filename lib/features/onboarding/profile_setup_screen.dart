import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/user_profile_service.dart';
import '../../services/exceptions.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _interestsController = TextEditingController();

  String _timezone = 'Asia/Tehran';
  int _wakeUpTime = 6;
  int _sleepTime = 23;
  int _focusHours = 4;

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _setupProfile() async {
    final name = _nameController.text.trim();
    final role = _roleController.text.trim();
    final interestsStr = _interestsController.text.trim();

    if (name.isEmpty || role.isEmpty) {
      setState(() => _error = 'لطفاً نام و نقش را تکمیل کنید');
      return;
    }

    final interests = interestsStr.isEmpty
        ? <String>[]
        : interestsStr.split(',').map((e) => e.trim()).cast<String>().toList();

    setState(() => _isLoading = true);
    try {
      final userService = context.read<UserProfileService>();
      await userService.setupProfile(
        name: name,
        role: role,
        timezone: _timezone,
        interests: interests,
        wakeUpTime: _wakeUpTime.toString(),
        sleepTime: _sleepTime.toString(),
        focusHours: _focusHours.toString(),
      );

      if (!mounted) return;

      // پروفایل موفقانه ایجاد شد و service profile رو save کرده
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پروفایل شما ایجاد شد!')),
      );

      // مستقیم برو به home (بدون pop)
      // app.dart دوباره rebuild خواهد شد و HomeShell نمایش خواهد دهد
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      // اگر پروفایل قبلاً ایجاد شده، برو به home (مشکل نیست)
      if (e.message.contains('قبلاً')) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
        return;
      }

      // سایر خطاها رو نمایش بده
      setState(() => _error = e.message);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیم پروفایل'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'بیایید شناخت‌نامه شما را کامل کنیم',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'این اطلاعات ما را کمک می‌کند تا تجربه شخصی‌سازی شده‌ای برایتان بسازیم.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                  ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_error != null) const SizedBox(height: 16),

            // Name field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'نام و نام‌خانوادگی',
                hintText: 'مثلاً علی محمدی',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            // Role field
            TextField(
              controller: _roleController,
              decoration: InputDecoration(
                labelText: 'نقش یا حرفه',
                hintText: 'مثلاً مهندس نرم‌افزار',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.work),
              ),
            ),
            const SizedBox(height: 16),

            // Timezone
            DropdownButtonFormField<String>(
              value: _timezone,
              decoration: InputDecoration(
                labelText: 'منطقۀ زمانی',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.schedule),
              ),
              items: const [
                DropdownMenuItem(value: 'Asia/Tehran', child: Text('تهران')),
                DropdownMenuItem(value: 'Asia/Dubai', child: Text('دبی')),
                DropdownMenuItem(value: 'Europe/London', child: Text('لندن')),
                DropdownMenuItem(
                    value: 'America/New_York', child: Text('نیویورک')),
              ],
              onChanged: (val) =>
                  setState(() => _timezone = val ?? 'Asia/Tehran'),
            ),
            const SizedBox(height: 16),

            // Interests
            TextField(
              controller: _interestsController,
              decoration: InputDecoration(
                labelText: 'علایق (جدا شده با ، )',
                hintText: 'مثلاً هوش مصنوعی، پرتو، بلاک‌چین',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.interests),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Time settings
            Text(
              'زمان‌بندی روزانه',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildTimeSlider(
                      label: 'ساعت بیداری',
                      value: _wakeUpTime,
                      onChanged: (val) =>
                          setState(() => _wakeUpTime = val.toInt()),
                    ),
                    const SizedBox(height: 16),
                    _buildTimeSlider(
                      label: 'ساعت خواب',
                      value: _sleepTime,
                      onChanged: (val) =>
                          setState(() => _sleepTime = val.toInt()),
                    ),
                    const SizedBox(height: 16),
                    _buildFocusHoursSlider(
                      label: 'ساعات تمرکز روزانه',
                      value: _focusHours,
                      onChanged: (val) =>
                          setState(() => _focusHours = val.toInt()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Setup button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _setupProfile,
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(neon),
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isLoading ? 'درحال ثبت...' : 'شروع کنید'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: neon,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlider({
    required String label,
    required int value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 23,
                divisions: 23,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Text('$value:00',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildFocusHoursSlider({
    required String label,
    required int value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Text('$value ساعت',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
