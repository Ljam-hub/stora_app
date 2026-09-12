import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/notification_badge.dart';
import 'customer_chat_screen.dart';

class CustomerConversationsScreen extends StatefulWidget {
  final VoidCallback? onBrowseStores;

  const CustomerConversationsScreen({super.key, this.onBrowseStores});

  @override
  State<CustomerConversationsScreen> createState() => _CustomerConversationsScreenState();
}

class _CustomerConversationsScreenState extends State<CustomerConversationsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().fetchConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return DateFormat('h:mm a').format(dt);
      }
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<bool> _confirmDeleteConversation(int storeOwnerId, String storeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 10),
            Text('Delete Conversation?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all messages with $storeName? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (!mounted) return false;
        await context.read<ChatProvider>().deleteConversation(storeOwnerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversation with $storeName deleted', style: const TextStyle(color: Colors.white)),
              backgroundColor: AppColors.cardElevated,
            ),
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete conversation: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  Future<void> _openSupportChat() async {
    try {
      final contact = await CustomerApiService.instance.getSupportContact();
      if (!mounted) return;
      final supportId = (contact?['id'] as num?)?.toInt() ?? 1;
      final supportName = (contact?['name'] as String?) ?? 'STORA Support';
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerChatScreen(
            storeOwnerId: supportId,
            storeName: supportName,
            isSupport: true,
          ),
        ),
      );
      if (mounted) {
        context.read<ChatProvider>().fetchConversations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to connect to STORA Support: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _buildSupportCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.cardElevated,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openSupportChat,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'STORA Support',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OFFICIAL',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Orders, delivery & customer assistance',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Chat', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final conversations = chatProvider.conversations;

    final filtered = _searchQuery.trim().isEmpty
        ? conversations
        : conversations.where((c) {
            final name = (c['name'] ?? '').toString().toLowerCase();
            final lastMsg = (c['last_message'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || lastMsg.contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => chatProvider.fetchConversations(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search stores or messages...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.cardBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // Pinned Support Card
          if (_searchQuery.trim().isEmpty || 'stora support'.contains(_searchQuery.trim().toLowerCase()))
            _buildSupportCard(),

          // Conversation list
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.cardElevated,
              onRefresh: () => chatProvider.fetchConversations(),
              child: chatProvider.isLoading && conversations.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : filtered.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: EmptyState(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: _searchQuery.isNotEmpty ? 'No conversations found' : 'No Store Messages Yet',
                                message: _searchQuery.isNotEmpty
                                    ? 'No chats match "$_searchQuery".'
                                    : 'When you message a store or place an order, your conversations will appear here.',
                                buttonText: widget.onBrowseStores != null && _searchQuery.isEmpty ? 'Browse Stores' : null,
                                onButtonPressed: widget.onBrowseStores,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final conv = filtered[index];
                            final storeOwnerId = (conv['id'] ?? conv['user_id']) as int;
                            final storeName = (conv['name'] as String?)?.trim() ?? 'Store';
                            final avatarUrl = conv['avatar_url'] as String?;
                            final unreadCount = (conv['unread_count'] as int?) ?? 0;
                            final lastMsg = (conv['last_message'] as String?) ?? '';
                            final timeText = _formatTime(conv['last_message_at'] as String?);

                            return Dismissible(
                              key: Key('conv_$storeOwnerId'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
                                    SizedBox(width: 6),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              confirmDismiss: (_) => _confirmDeleteConversation(storeOwnerId, storeName),
                              child: Material(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onLongPress: () => _confirmDeleteConversation(storeOwnerId, storeName),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CustomerChatScreen(
                                          storeOwnerId: storeOwnerId,
                                          storeName: storeName,
                                          storeAvatarUrl: avatarUrl,
                                        ),
                                      ),
                                    );
                                    if (context.mounted) {
                                      context.read<ChatProvider>().fetchConversations(isSilent: true);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: unreadCount > 0
                                            ? AppColors.primary.withValues(alpha: 0.3)
                                            : Colors.white.withValues(alpha: 0.06),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        AppNotificationBadge(
                                          count: unreadCount,
                                          top: -2,
                                          right: -2,
                                          borderColor: AppColors.cardBackground,
                                          child: CircleAvatar(
                                            radius: 24,
                                            backgroundColor: AppColors.cardElevated,
                                            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                                ? NetworkImage(avatarUrl)
                                                : null,
                                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                                ? const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24)
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      storeName,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                        fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (timeText.isNotEmpty)
                                                    Text(
                                                      timeText,
                                                      style: TextStyle(
                                                        color: unreadCount > 0 ? const Color(0xFFEF4444) : AppColors.textMuted,
                                                        fontSize: 11.5,
                                                        fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.normal,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      lastMsg.isNotEmpty ? lastMsg : 'Tap to chat with store',
                                                      style: TextStyle(
                                                        color: unreadCount > 0 ? Colors.white : AppColors.textSecondary,
                                                        fontSize: 13,
                                                        fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (unreadCount > 0)
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 8),
                                                      child: AppNotificationBadge(
                                                        count: unreadCount,
                                                        borderColor: AppColors.cardBackground,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(
                                            Icons.more_vert_rounded,
                                            color: AppColors.textMuted,
                                            size: 20,
                                          ),
                                          color: AppColors.cardElevated,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          onSelected: (val) {
                                            if (val == 'delete') {
                                              _confirmDeleteConversation(storeOwnerId, storeName);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Delete Convo', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
