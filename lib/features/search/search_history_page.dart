import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SearchHistoryPage extends StatefulWidget {
  const SearchHistoryPage({super.key});

  @override
  State<SearchHistoryPage> createState() => _SearchHistoryPageState();
}

class _SearchHistoryPageState extends State<SearchHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchHistoryItem> _searchHistory = [];
  List<SearchHistoryItem> _filteredHistory = [];
  String _selectedFilter = 'all'; // all, web, files, people, articles

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('search.history') ?? '[]';
      final historyList = jsonDecode(historyJson) as List<dynamic>;

      final loaded = historyList
          .map((item) {
            try {
              final map = item as Map<String, dynamic>;
              return SearchHistoryItem(
                id: map['id'] ?? '',
                query: map['query'] ?? '',
                type: map['type'] ?? 'web',
                timestamp: DateTime.parse(
                    map['timestamp'] ?? DateTime.now().toIso8601String()),
                icon: _getIconForType(map['type'] ?? 'web'),
                resultCount: map['resultCount'] ?? 0,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<SearchHistoryItem>()
          .toList();

      if (loaded.isEmpty) {
        // اگر تاریخچه خالی است، mock data نمایش نمی‌دهیم
        setState(() {
          _searchHistory = [];
          _filteredHistory = [];
        });
      } else {
        // مرتب‌سازی براساس تاریخ (جدیدترین اول)
        loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        setState(() {
          _searchHistory = loaded;
          _filteredHistory = loaded;
        });
      }
    } catch (e) {
      // در صورت خطا، تاریخچه خالی باقی می‌ماند
      setState(() {
        _searchHistory = [];
        _filteredHistory = [];
      });
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'articles':
        return Icons.article;
      case 'web':
      default:
        return Icons.language;
    }
  }

  void _filterHistory() {
    setState(() {
      var filtered = _searchHistory;

      if (_selectedFilter != 'all') {
        filtered =
            filtered.where((item) => item.type == _selectedFilter).toList();
      }

      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        filtered = filtered
            .where((item) => item.query.toLowerCase().contains(query))
            .toList();
      }

      _filteredHistory = filtered;
    });
  }

  Future<void> _deleteHistoryItem(String id) async {
    try {
      setState(() {
        _searchHistory.removeWhere((item) => item.id == id);
        _filteredHistory.removeWhere((item) => item.id == id);
      });

      // ذخیره تاریخچه به‌روز‌شده
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _searchHistory
            .map((item) => {
                  'id': item.id,
                  'query': item.query,
                  'type': item.type,
                  'timestamp': item.timestamp.toIso8601String(),
                  'resultCount': item.resultCount,
                })
            .toList(),
      );
      await prefs.setString('search.history', encoded);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جستجو حذف شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف: $e')),
        );
      }
    }
  }

  Future<void> _clearAllHistory() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاک‌کردن تمام تاریخچه'),
        content: const Text('آیا می‌خواهید تمام جستجوها حذف شوند؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('search.history', '[]');

                setState(() {
                  _searchHistory.clear();
                  _filteredHistory.clear();
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمام جستجوها حذف شدند')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا: $e')),
                  );
                }
              }
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFF64D2FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تاریخچۀ جستجو'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_searchHistory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: TextButton(
                  onPressed: _clearAllHistory,
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
          // === جستجو ===
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _filterHistory(),
                decoration: const InputDecoration(
                  hintText: 'جستجو در تاریخچه...',
                  prefixIcon: Icon(Icons.search, color: neon),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
          ),

          // === فیلترها ===
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('تمام', 'all', neon),
                const SizedBox(width: 8),
                _buildFilterChip('وب', 'web', neon),
                const SizedBox(width: 8),
                _buildFilterChip('مقالات', 'articles', neon),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // === لیست جستجوها ===
          Expanded(
            child: _filteredHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchHistory.isEmpty
                              ? 'تاریخچه خالی است'
                              : 'جستجوی مطابقی یافت نشد',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredHistory.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final item = _filteredHistory[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildHistoryCard(item, neon),
                      );
                    },
                  ),
          ),
        ],
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
        _filterHistory();
      },
      backgroundColor: Colors.transparent,
      selectedColor: neon,
      side: BorderSide(
        color: isSelected ? neon : Colors.white.withOpacity(0.2),
      ),
    );
  }

  Widget _buildHistoryCard(SearchHistoryItem item, Color neon) {
    return GestureDetector(
      onTap: () {
        _searchController.text = item.query;
        _filterHistory();
        // در عمل، اینجا جستجو دوباره انجام می‌شود
      },
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: neon.withOpacity(0.2),
              ),
              child: Center(
                child: Icon(item.icon, color: neon, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.query,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _getTimeAgo(item.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: neon.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatResultCount(item.resultCount),
                          style: TextStyle(
                            fontSize: 11,
                            color: neon,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_new, size: 16),
                      const SizedBox(width: 8),
                      const Text('باز کردن'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text(
                        'حذف',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteHistoryItem(item.id);
                } else if (value == 'open') {
                  // باز کردن جستجو دوباره
                }
              },
              child: Icon(
                Icons.more_vert,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
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
      return '${time.day}/${time.month}';
    }
  }

  String _formatResultCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return '$count';
    }
  }
}

class SearchHistoryItem {
  final String id;
  final String query;
  final String type; // web, files, people, articles
  final DateTime timestamp;
  final IconData icon;
  final int resultCount;

  SearchHistoryItem({
    required this.id,
    required this.query,
    required this.type,
    required this.timestamp,
    required this.icon,
    required this.resultCount,
  });
}
