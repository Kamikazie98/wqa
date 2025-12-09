import 'package:flutter/material.dart';

import '../constants/brand.dart';
import '../services/url_launcher_service.dart';

class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, this.alignment = CrossAxisAlignment.center});

  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: alignment == CrossAxisAlignment.center
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  Brand.logoPath,
                  height: 48,
                  width: 48,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Brand.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: alignment == CrossAxisAlignment.center
              ? WrapAlignment.center
              : WrapAlignment.start,
          spacing: 12,
          runSpacing: 8,
          children: [
            _ActionChip(
              label: 'securecodehub.ir',
              icon: Icons.language,
              onTap: () => UrlLauncherService.openUrl(Brand.builderSite),
            ),
            _ActionChip(
              label: '@webdops',
              icon: Icons.alternate_email,
              onTap: () => UrlLauncherService.openUrl(Brand.instagram),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
