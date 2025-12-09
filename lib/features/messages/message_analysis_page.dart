import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/message_reader_service.dart';

class MessageItem {
  final String id;
  final String sender;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String category;
  final String priority;

  MessageItem({
    required this.id,
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.isRead,
    required this.category,
    required this.priority,
  });

  MessageItem copyWith({bool? isRead}) {
    return MessageItem(
      id: id,
      sender: sender,
      body: body,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      category: category,
      priority: priority,
    );
  }
}

class MessageAnalysisPage extends StatefulWidget {
  const MessageAnalysisPage({super.key});

  @override
  State<MessageAnalysisPage> createState() => _MessageAnalysisPageState();
}

class _MessageAnalysisPageState extends State<MessageAnalysisPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  List<MessageItem> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messageReader = context.read<MessageReaderService>();
      final messages = await messageReader.getPendingMessages();

      // Convert Message model to MessageItem
      final items = messages.map((m) {
        return MessageItem(
          id: m.id,
          sender: m.senderName.isNotEmpty ? m.senderName : m.sender,
          body: m.body,
          timestamp: m.timestamp,
          isRead: m.isRead,
          category: _categorizeMessage(m.body),
          priority: m.priority.name,
        );
      }).toList();

      setState(() {
        _messages = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }

  String _categorizeMessage(String body) {
    final lower = body.toLowerCase();
    if (lower.contains('کد') ||
        lower.contains('تأیید') ||
        lower.contains('verify')) {
      return 'verification';
    }
    if (lower.contains('تراکنش') ||
        lower.contains('تومان') ||
        lower.contains('حساب')) {
      return 'financial';
    }
    if (lower.contains('سلام') ||
        lower.contains('دوست') ||
        lower.contains('میخوای')) {
      return 'social';
    }
    return 'other';
  }

  List<MessageItem> _getFilteredMessages() {
    var filtered = _messages;

    if (_selectedFilter != 'all') {
      if (_selectedFilter == 'important') {
        filtered = filtered.where((m) => m.priority == 'high').toList();
      } else if (_selectedFilter == 'unread') {
        filtered = filtered.where((m) => !m.isRead).toList();
      } else {
        filtered =
            filtered.where((m) => m.category == _selectedFilter).toList();
      }
    }

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((m) {
        return m.sender.toLowerCase().contains(query) ||
            m.body.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _markAsRead(MessageItem message) async {
    setState(() {
      final index = _messages.indexOf(message);
      if (index != -1) {
        _messages[index] = message.copyWith(isRead: true);
      }
    });
  }

  Future<void> _deleteMessage(MessageItem message) async {
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پیام حذف شد')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final neon = const Color(0xFF64D2FF);
    final filtered = _getFilteredMessages();

    return Scaffold(
      backgroundColor: const Color(0xFF070A13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: const Text('تحلیل پیام‌ها'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'جستجو در پیام‌ها',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: neon.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: neon.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: neon),
                    ),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'همه', neon),
                      const SizedBox(width: 8),
                      _buildFilterChip('important', 'مهم', neon),
                      const SizedBox(width: 8),
                      _buildFilterChip('unread', 'خوانده نشده', neon),
                      const SizedBox(width: 8),
                      _buildFilterChip('verification', 'تأیید', neon),
                      const SizedBox(width: 8),
                      _buildFilterChip('financial', 'مالی', neon),
                      const SizedBox(width: 8),
                      _buildFilterChip('social', 'اجتماعی', neon),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: neon),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'پیامی یافت نشد',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final message = filtered[index];
                          return _buildMessageCard(message, neon);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, Color neon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
      ),
      backgroundColor: const Color(0xFF0D1117),
      selectedColor: neon,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildMessageCard(MessageItem message, Color neon) {
    return Dismissible(
      key: Key(message.id),
      onDismissed: (direction) => _deleteMessage(message),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => _markAsRead(message),
        child: Card(
          color: const Color(0xFF0D1117),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: neon.withOpacity(message.isRead ? 0.1 : 0.5),
              width: message.isRead ? 0.5 : 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        message.sender,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: message.isRead
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: message.priority == 'high' ? Colors.red : neon,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        message.priority == 'high' ? 'مهم' : 'عادی',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message.body,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getTimeAgo(message.timestamp),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                    if (!message.isRead)
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: neon,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'هم‌اکنون';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    } else {
      return '${difference.inDays} روز پیش';
    }
  }
}
