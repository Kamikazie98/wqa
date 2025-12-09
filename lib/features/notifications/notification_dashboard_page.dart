import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/notification_summary_widget.dart';
import 'notification_history_page.dart';

class NotificationDashboardPage extends ConsumerStatefulWidget {
  const NotificationDashboardPage({super.key});

  @override
  ConsumerState<NotificationDashboardPage> createState() =>
      _NotificationDashboardPageState();
}

class _NotificationDashboardPageState
    extends ConsumerState<NotificationDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اعلان‌ها و پیام‌ها'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(
              icon: Icon(Icons.summarize),
              text: 'خلاصه',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'تاریخچه',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Summary Tab
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'خلاصه هوشمند',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'هوش‌مند رایانه‌ای می‌تواند اعلان‌ها و پیام‌های شما را تحلیل و خلاصه کند',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Notification Summary Widget with Error Boundary
                  const NotificationSummaryWidget(),
                ],
              ),
            ),
          ),
          // History Tab
          const NotificationHistoryPage(),
        ],
      ),
    );
  }
}
