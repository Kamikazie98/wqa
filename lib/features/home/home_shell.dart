import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants/brand.dart';
import '../../controllers/auth_controller.dart';
import '../agents/agent_tasks_page.dart';
import '../chat/chat_page.dart';
import '../experts/experts_page.dart';
import '../instagram/content_calendar_page.dart';
import '../instagram/instagram_ideas_page.dart';
import '../research/deep_research_page.dart';
import '../tools/tools_page.dart';
import '../program/program_page.dart';
import '../settings/settings_page.dart';
import '../profile/profile_management_page.dart';
import '../messages/message_analysis_page.dart';
import '../messages/incoming_message_notifier.dart';
import '../search/search_history_page.dart';
import '../notifications/notification_dashboard_page.dart';
import '../notifications/important_notification_banner.dart';
import '../../screens/automation_screen.dart';
import 'app_drawer.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    ChatPage(),
    ToolsPage(),
    InstagramIdeasPage(),
    ContentCalendarPage(),
    DeepResearchPage(),
    AgentTasksPage(),
    ProgramPage(),
    ExpertsPage(),
    AutomationScreen(),
    MessageAnalysisPage(),
    SearchHistoryPage(),
    NotificationDashboardPage(),
    ProfileManagementPage(),
    SettingsPage(),
  ];

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: 'گفتگو',
      tooltip: 'صفحه چت و دستیار',
    ),
    NavigationDestination(
      icon: Icon(Icons.build_outlined),
      selectedIcon: Icon(Icons.build),
      label: 'ابزارها',
      tooltip: 'جعبه ابزار و اتوماسیون',
    ),
    NavigationDestination(
      icon: Icon(Icons.bolt_outlined),
      selectedIcon: Icon(Icons.bolt),
      label: 'ایده‌ها',
      tooltip: 'ایده‌های اینستاگرام',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: 'تقویم',
      tooltip: 'تقویم محتوایی',
    ),
    NavigationDestination(
      icon: Icon(Icons.psychology_alt_outlined),
      selectedIcon: Icon(Icons.psychology_alt),
      label: 'تحقیق',
      tooltip: 'تحقیق عمیق',
    ),
    NavigationDestination(
      icon: Icon(Icons.task_outlined),
      selectedIcon: Icon(Icons.task),
      label: 'وظایف',
      tooltip: 'کارهای ایجنت',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_today_outlined),
      selectedIcon: Icon(Icons.calendar_today),
      label: 'برنامه',
      tooltip: 'برنامه روزانه',
    ),
    NavigationDestination(
      icon: Icon(Icons.verified_user_outlined),
      selectedIcon: Icon(Icons.verified_user),
      label: 'متخصص‌ها',
      tooltip: 'کارشناس‌ها',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_suggest_outlined),
      selectedIcon: Icon(Icons.settings_suggest),
      label: 'اتوماسیون',
      tooltip: 'تنظیمات اتوماسیون دستیار',
    ),
    NavigationDestination(
      icon: Icon(Icons.mail_outline),
      selectedIcon: Icon(Icons.mail),
      label: 'پیام‌ها',
      tooltip: 'تجزیه و تحلیل پیام‌ها',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: 'جستجو',
      tooltip: 'تاریخچه جستجوها',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'اعلان‌ها',
      tooltip: 'تاریخچه اعلان‌ها',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'پروفایل',
      tooltip: 'مدیریت پروفایل',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'تنظیمات',
      tooltip: 'تنظیمات برنامه',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Profile چک شده است در app.dart، دیگر نیاز نیست
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        return Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'app_logo',
                  child: Image.asset(
                    Brand.logoPath,
                    height: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Brand.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'دستیار هوشمند',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (auth.phone != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        auth.phone!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  await auth.logout();
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('خروج'),
              ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
            child: _pages[_index],
          ),
          bottomNavigationBar: _NeonBottomBar(
            destinations: _destinations,
            index: _index,
            onChanged: (value) {
              setState(() => _index = value);
              HapticFeedback.lightImpact();
            },
          ),
          floatingActionButton: _buildFloatingNotifications(),
        );
      },
    );
  }

  /// بنرهای floating برای اعلان‌ها و پیام‌های مهم
  Widget _buildFloatingNotifications() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IncomingMessageNotifier(
          child: const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        ImportantNotificationBanner(
          onDismiss: () {
            // Handle dismiss
          },
        ),
      ],
    );
  }
}

class _NeonBottomBar extends StatelessWidget {
  const _NeonBottomBar({
    required this.destinations,
    required this.index,
    required this.onChanged,
  });

  final List<NavigationDestination> destinations;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF52FF7F);
    const dark = Color(0xFF0B0D10);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [accent, Color(0xFF46D76C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.35),
              blurRadius: 18,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              color: dark,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minWidth =
                    math.max(constraints.maxWidth, destinations.length * 80.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          _NeonItem(
                            destination: destinations[i],
                            selected: i == index,
                            onTap: () => onChanged(i),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NeonItem extends StatelessWidget {
  const _NeonItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF52FF7F);
    const pill = Color(0xFF11141B);
    final Widget icon = selected
        ? (destination.selectedIcon ?? destination.icon)
        : destination.icon;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: accent.withOpacity(0.15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 10,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? pill : pill.withOpacity(0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? accent.withOpacity(0.7) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : const Color(0xFF1A1E26),
                ),
                alignment: Alignment.center,
                child: IconTheme(
                  data: IconThemeData(
                    color: selected ? Colors.black : Colors.white70,
                  ),
                  child: icon,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          destination.label,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
