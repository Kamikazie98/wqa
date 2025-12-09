import '../../screens/permissions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationHistoryPage extends StatefulWidget {
  const NotificationHistoryPage({super.key});

  @override
  State<NotificationHistoryPage> createState() =>
      _NotificationHistoryPageState();
}

class _NotificationHistoryPageState extends State<NotificationHistoryPage>
    with WidgetsBindingObserver {
  static const _notifChannel = MethodChannel('waiq/notifications');

  final TextEditingController _searchController = TextEditingController();
  List<NotificationItem> _notifications = [];
  List<NotificationItem> _filteredNotifications = [];
  String _selectedFilter = 'all'; // all, unread, reminder, app, system
  bool _showPermissionsMessage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotifications();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    print('==============================');
    print('[NotificationHistory] _loadNotifications CALLED');

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      print('[NotificationHistory] SharedPreferences keys: $keys');

      final notifJson = prefs.getString('notif.buffer');
      print('[NotificationHistory] Raw JSON from prefs (notif.buffer): $notifJson');

      if (notifJson == null || notifJson.isEmpty) {
        print('[NotificationHistory] notif.buffer is null/empty');
        setState(() {
          _notifications = [];
          _filteredNotifications = [];
          _showPermissionsMessage = true; // یعنی یا دسترسی نیست یا هنوز چیزی ذخیره نشده
        });
        return;
      }

      if (notifJson == '[]') {
        print('[NotificationHistory] notif.buffer is [] (empty list)');
        setState(() {
          _notifications = [];
          _filteredNotifications = [];
          _showPermissionsMessage = false; // فقط لیست خالی
        });
        return;
      }

      final List<dynamic> decoded = jsonDecode(notifJson);
      print('[NotificationHistory] Decoded list length: ${decoded.length}');

      if (decoded.isEmpty) {
        setState(() {
          _notifications = [];
          _filteredNotifications = [];
          _showPermissionsMessage = false;
        });
        return;
      }

      final list = decoded.map((item) {
        final Map<String, dynamic> map =
            Map<String, dynamic>.from(item as Map);
        print('[NotificationHistory] Mapping item: $map');

        return NotificationItem(
          id: map['id'] ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          title: map['title'] ?? 'بدون عنوان',
          message: map['body'] ?? map['text'] ?? 'بدون متن',
          type: _categorizeNotification(
            map['category'] ?? '',
            map['pkg'] ?? '',
          ),
          timestamp: map['ts'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  int.tryParse(map['ts'].toString()) ?? 0,
                )
              : DateTime.now(),
          isRead: false,
          icon: _getIconForType(map['category'] ?? ''),
          actionText: 'مشاهده',
          packageName: map['pkg']?.toString() ?? '',
        );
      }).toList();

      setState(() {
        _showPermissionsMessage = false;
        _notifications = list.reversed.toList();
        _filterNotifications();
      });

      print('[NotificationHistory] _notifications length: ${_notifications.length}');
      print('[NotificationHistory] _filteredNotifications length: ${_filteredNotifications.length}');
    } catch (e) {
      print('[NotificationHistory] ERROR in _loadNotifications: $e');
      setState(() {
        _notifications = [];
        _filteredNotifications = [];
        _showPermissionsMessage = true;
      });
    }

    print('==============================');
  }

  String _categorizeNotification(String category, String packageName) {
    if (category.contains('call')) return 'call';
    if (category.contains('msg') || category.contains('message')) return 'message';
    if (category.contains('email')) return 'email';
    if (packageName.contains('telegram')) return 'app';
    if (packageName.contains('whatsapp')) return 'app';
    return 'app';
  }

  IconData _getIconForType(String category) {
    if (category.contains('call')) return Icons.phone;
    if (category.contains('msg') || category.contains('message')) return Icons.mail;
    if (category.contains('email')) return Icons.email;
    return Icons.notifications;
  }

  void _loadMockNotifications() {
    setState(() {
      _notifications = [
        NotificationItem(
          id: '1',
          title: 'یادآوری برنامه',
          message: 'برنامۀ ۹ صبح شما شروع می‌شود',
          type: 'reminder',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isRead: false,
          icon: Icons.schedule,
          actionText: 'مشاهده',
          packageName: 'mock.reminder',
        ),
        NotificationItem(
          id: '2',
          title: 'پیام جدید',
          message: 'شما یک پیام جدید از رضا دریافت کردید',
          type: 'app',
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
          isRead: false,
          icon: Icons.mail,
          actionText: 'باز کردن',
          packageName: 'com.example.messaging',
        ),
      ];
      _filteredNotifications = _notifications;
    });
  }

  void _filterNotifications() {
    setState(() {
      var filtered = _notifications;

      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'unread') {
          filtered = filtered.where((item) => !item.isRead).toList();
        } else {
          filtered =
              filtered.where((item) => item.type == _selectedFilter).toList();
        }
      }

      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        filtered = filtered
            .where((item) =>
                item.title.toLowerCase().contains(query) ||
                item.message.toLowerCase().contains(query))
            .toList();
      }

      _filteredNotifications = filtered;
    });
  }

  Future<void> _markAsRead(String id) async {
    setState(() {
      final index = _notifications.indexWhere((item) => item.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _filterNotifications();
      }
    });
  }

  Future<void> _deleteNotification(String id) async {
    setState(() {
      _notifications.removeWhere((item) => item.id == id);
      _filteredNotifications.removeWhere((item) => item.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('اعلان حذف شد')),
    );
  }

  Future<void> _clearAllNotifications() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاک‌کردن تمام اعلان‌ها'),
        content: const Text('آیا می‌خواهید تمام اعلان‌ها حذف شوند؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _notifications.clear();
                _filteredNotifications.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تمام اعلان‌ها حذف شدند')),
              );
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openApp(String packageName) async {
    if (packageName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('امکان بازکردن برنامه مربوطه نیست')),
      );
      return;
    }
    try {
      await _notifChannel.invokeMethod('openApp', {'package': packageName});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بازکردن برنامه: $e')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFF64D2FF);
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تاریخچۀ اعلان‌ها'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: TextButton(
                  onPressed: _clearAllNotifications,
                  child: const Text(
                    'پاک‌کردن',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // === خلاصه ===
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: neon.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: neon.withOpacity(0.3)),
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
                    child: Center(
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: neon,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'اعلان خوانده‌نشده',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'شما $unreadCount اعلان خوانده‌نشده دارید',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        for (var i = 0; i < _notifications.length; i++) {
                          if (!_notifications[i].isRead) {
                            _notifications[i] =
                                _notifications[i].copyWith(isRead: true);
                          }
                        }
                        _filterNotifications();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: neon,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text(
                      'علامت‌گذاری',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else if (!_showPermissionsMessage)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.withOpacity(0.2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'همه را خوانده‌اید',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'هیچ اعلان خوانده‌نشده‌ای نیست',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // === جستجو ===
          if (!_showPermissionsMessage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _filterNotifications(),
                  decoration: const InputDecoration(
                    hintText: 'جستجو در اعلان‌ها...',
                    prefixIcon: Icon(Icons.search, color: neon),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),

          // === فیلترها ===
          if (!_showPermissionsMessage)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildFilterChip('تمام', 'all', neon),
                  const SizedBox(width: 8),
                  _buildFilterChip('خوانده‌نشده', 'unread', neon),
                  const SizedBox(width: 8),
                  _buildFilterChip('یادآوری', 'reminder', neon),
                  const SizedBox(width: 8),
                  _buildFilterChip('برنامه', 'app', neon),
                  const SizedBox(width: 8),
                  _buildFilterChip('سیستم', 'system', neon),
                ],
              ),
            ),

          // === لیست اعلان‌ها ===
          Expanded(
            child: _showPermissionsMessage
                ? _buildPermissionsMessage(neon)
                : _filteredNotifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 48,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _notifications.isEmpty
                                  ? 'اعلانی وجود ندارد'
                                  : 'اعلان مطابقی یافت نشد',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredNotifications.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final notification = _filteredNotifications[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildNotificationCard(notification, neon),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsMessage(Color neon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'تاریخچه اعلان‌ها خالی است',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'برای نمایش اعلان‌های دستگاه در این بخش، باید دسترسی لازم را به برنامه بدهید.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.security),
              label: const Text('رفتن به تنظیمات دسترسی'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PermissionsScreen()),
                ).then((_) => _loadNotifications());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: neon,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color neon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFilter = value);
        _filterNotifications();
      },
      backgroundColor: Colors.transparent,
      selectedColor: neon,
      side: BorderSide(
        color: isSelected ? neon : Colors.white.withOpacity(0.2),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification, Color neon) {
    final typeColors = {
      'reminder': const Color(0xFF64D2FF),
      'app': const Color(0xFF7C5BFF),
      'system': Colors.orange,
    };

    final color = typeColors[notification.type] ?? neon;

    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          _markAsRead(notification.id);
        }
      },
      child: Dismissible(
        key: Key(notification.id),
        onDismissed: (_) => _deleteNotification(notification.id),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Icon(
            Icons.delete,
            color: Colors.red,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead
                  ? Colors.white.withOpacity(0.1)
                  : color.withOpacity(0.3),
              width: notification.isRead ? 1 : 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.2),
                    ),
                    child: Center(
                      child: Icon(
                        notification.icon,
                        color: color,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                notification.type,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTimeAgo(notification.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                notification.message,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (notification.actionText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: () {
                      _openApp(notification.packageName);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(
                      notification.actionText,
                      style: TextStyle(color: color),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'الآن';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} دقیقه پیش';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ساعت پیش';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} روز پیش';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  final bool isRead;
  final IconData icon;
  final String actionText;
  final String packageName;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
    required this.icon,
    required this.actionText,
    required this.packageName,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final iconMap = {
      'reminder': Icons.schedule,
      'app': Icons.mail,
      'system': Icons.system_update,
      'check': Icons.check_circle,
      'warning': Icons.battery_alert,
      'file': Icons.description,
      'person': Icons.person_add,
      'goal': Icons.flag,
    };

    DateTime ts;
    if (json['timestamp'] != null) {
      ts = DateTime.parse(json['timestamp'].toString());
    } else if (json['ts'] != null) {
      ts = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(json['ts'].toString()) ?? 0,
      );
    } else {
      ts = DateTime.now();
    }

    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ??
          json['body']?.toString() ??
          '',
      type: json['type']?.toString() ?? 'app',
      timestamp: ts,
      isRead: json['isRead'] as bool? ?? false,
      icon: iconMap[json['type']?.toString()] ?? Icons.notifications,
      actionText: json['actionText']?.toString() ?? 'مشاهده',
      packageName: json['pkg']?.toString() ?? '',
    );
  }

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    DateTime? timestamp,
    bool? isRead,
    IconData? icon,
    String? actionText,
    String? packageName,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      icon: icon ?? this.icon,
      actionText: actionText ?? this.actionText,
      packageName: packageName ?? this.packageName,
    );
  }
}
