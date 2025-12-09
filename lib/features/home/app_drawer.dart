import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/brand.dart';
import '../../services/url_launcher_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF05060A),
              Color(0xFF0A0F1E),
              Color(0xFF11172A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Image.asset(
                      Brand.logoPath,
                      height: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      Brand.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _DrawerTile(
                      icon: Icons.language,
                      title: 'وب‌سایت',
                      subtitle: Brand.builderSite,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        UrlLauncherService.openUrl(Brand.builderSite);
                        Navigator.of(context).pop();
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.camera_alt_outlined,
                      title: 'اینستاگرام',
                      subtitle: Brand.instagram,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        UrlLauncherService.openUrl(Brand.instagram);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'امن و محافظت شده',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
