import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/chat_controller.dart';
import '../../../models/chat_models.dart';

class SessionSidebar extends StatefulWidget {
  const SessionSidebar({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  State<SessionSidebar> createState() => _SessionSidebarState();
}

class _SessionSidebarState extends State<SessionSidebar> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, controller, _) {
        final activeId = controller.activeSession.id;
        final filteredSessions = _searchQuery.isEmpty
            ? controller.sessions
            : controller.sessions
                .where((session) =>
                    session.title
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ||
                    session.messages.any((msg) => msg.content
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase())))
                .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'جستجوی جلسات...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'جلسه جدید',
                    onPressed: () => controller.createSession(),
                    icon: const Icon(Icons.add_circle_outline),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
            if (filteredSessions.isEmpty && _searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: Colors.white38,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'نتیجه‌ای یافت نشد',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white54,
                          ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: widget.scrollController,
                  itemCount: filteredSessions.length,
                  itemBuilder: (context, index) {
                    final session = filteredSessions[index];
                    final isActive = session.id == activeId;
                    return _SessionTile(session: session, isActive: isActive);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.isActive});

  final ChatSession session;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ChatController>();
    return Card(
      color: isActive
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      elevation: isActive ? 1 : 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title:
            Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${session.messages.length} پیام',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        onTap: () => controller.selectSession(session.id),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'rename') {
              final name = await _promptRename(context, session.title);
              if (name != null && name.trim().isNotEmpty) {
                controller.renameSession(session.id, name.trim());
              }
            } else if (value == 'delete') {
              controller.deleteSession(session.id);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'rename',
              child: Text('تغییر نام'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _promptRename(BuildContext context, String current) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('تغییر نام جلسه'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'عنوان جدید'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('ذخیره'),
          ),
        ],
      );
    },
  );
}
