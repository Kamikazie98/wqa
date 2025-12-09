import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/user_profile_service.dart';

class ProfileManagementPage extends StatefulWidget {
  const ProfileManagementPage({super.key});

  @override
  State<ProfileManagementPage> createState() => _ProfileManagementPageState();
}

class _ProfileManagementPageState extends State<ProfileManagementPage> {
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _timezoneController;
  late TextEditingController _interestsController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _roleController = TextEditingController();
    _timezoneController = TextEditingController();
    _interestsController = TextEditingController();
    _loadProfileData();
  }

  void _loadProfileData() {
    final userService = context.read<UserProfileService>();
    final profile = userService.profile;
    if (profile != null) {
      _nameController.text = profile.name;
      _roleController.text = profile.role;
      _timezoneController.text = profile.timezone;
      _interestsController.text = profile.interests.join('، ');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _timezoneController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    try {
      final userService = context.read<UserProfileService>();
      final interests = _interestsController.text
          .split('، ')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await userService.updateProfile(
        name: _nameController.text,
        timezone: _timezoneController.text,
        interests: interests,
      );

      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پروفایل ذخیره شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFF64D2FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('پروفایل من'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: _isEditing
                  ? TextButton(
                      onPressed: _saveProfile,
                      child: const Text('ذخیره'),
                    )
                  : TextButton(
                      onPressed: () => setState(() => _isEditing = true),
                      child: const Text('ویرایش'),
                    ),
            ),
          ),
        ],
      ),
      body: Consumer<UserProfileService>(
        builder: (context, userService, child) {
          if (userService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userService.error != null) {
            return Center(child: Text('خطا: ${userService.error}'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // عکس پروفایل
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        neon.withOpacity(0.3),
                        const Color(0xFF7C5BFF).withOpacity(0.3),
                      ],
                    ),
                    border: Border.all(color: neon, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      userService.profile?.name[0].toUpperCase() ?? '؟',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: neon,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                label: 'نام',
                icon: Icons.person,
                enabled: _isEditing,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _roleController,
                label: 'نقش',
                icon: Icons.work,
                enabled: _isEditing,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _timezoneController,
                label: 'منطقۀ زمانی',
                icon: Icons.schedule,
                enabled: _isEditing,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _interestsController,
                label: 'علایق (جدا شده با ، )',
                icon: Icons.interests,
                enabled: _isEditing,
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('اطلاعات', neon),
              const SizedBox(height: 12),
              _buildInfoCard(
                'ایجاد‌شده در:',
                userService.profile?.createdAt.toString().split('.')[0] ?? '-',
                Icons.calendar_today,
                neon,
              ),
              const SizedBox(height: 8),
              _buildInfoCard(
                'آخرین بروزرسانی:',
                userService.profile?.updatedAt?.toString().split('.')[0] ?? '-',
                Icons.update,
                neon,
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF64D2FF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String? value,
    IconData icon,
    Color neon,
  ) {
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: neon.withOpacity(0.2),
            ),
            child: Center(child: Icon(icon, color: neon, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
