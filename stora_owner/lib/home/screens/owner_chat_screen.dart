import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_config.dart';
import '../../stora_login/theme/app_colors.dart';
import '../stores/chat_store.dart';
import '../theme/home_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/notification_badge.dart';

class OwnerChatScreen extends StatefulWidget {
  final bool isTab;
  const OwnerChatScreen({super.key, this.isTab = false});

  @override
  State<OwnerChatScreen> createState() => _OwnerChatScreenState();
}

class _OwnerChatScreenState extends State<OwnerChatScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) _loadConversations(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      await ChatStore.instance.fetchConversations(isSilent: silent);
      if (mounted) {
        setState(() {
          _conversations = ChatStore.instance.conversations;
          _error = ChatStore.instance.error;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredConversations {
    if (_searchQuery.trim().isEmpty) return _conversations;
    final q = _searchQuery.toLowerCase();
    return _conversations.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final lastMsg = (c['last_message'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || lastMsg.contains(q) || email.contains(q);
    }).toList();
  }

  Future<bool> _confirmDeleteConversation(int customerId, String customerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 22),
            SizedBox(width: 10),
            Text('Delete Conversation?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all messages with $customerName? This cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeColors.dangerText,
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
        await ChatStore.instance.deleteConversation(customerId);
        if (mounted) {
          setState(() {
            _conversations.removeWhere((c) => (c['id'] ?? c['user_id']) == customerId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversation with $customerName deleted', style: const TextStyle(color: Colors.white)),
              backgroundColor: HomeColors.cardElevated,
            ),
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete conversation: $e'),
              backgroundColor: HomeColors.dangerText,
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  Future<void> _openNewMessagePicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: HomeColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: ApiClient.instance.getStoreCustomers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            }
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Failed to load customers: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.label),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final customers = snapshot.data ?? [];
            if (customers.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.label),
                    const SizedBox(height: 12),
                    const Text(
                      'No Customers Yet',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Customers who order from or message your store will appear here so you can chat with them directly.',
                      style: TextStyle(color: AppColors.label, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        const Text(
                          'Select Customer to Message',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: HomeColors.cardBorder, height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: customers.length,
                      separatorBuilder: (context, index) => const Divider(color: HomeColors.cardBorder, height: 1),
                      itemBuilder: (context, i) {
                        final c = customers[i];
                        final id = c['id'] as int;
                        final name = (c['name'] as String?)?.isNotEmpty == true
                            ? c['name'] as String
                            : 'Customer #$id';
                        final email = (c['email'] as String?) ?? '';
                        final avatar = c['avatar_url'] as String?;
                        final orderCount = c['order_count'] as int? ?? 0;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFF3A3B3C),
                            backgroundImage: (avatar != null && avatar.isNotEmpty)
                                ? NetworkImage(avatar)
                                : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? const Icon(Icons.person, color: Colors.white, size: 26)
                                : null,
                          ),
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            email.isNotEmpty
                                ? '$email • $orderCount order${orderCount == 1 ? "" : "s"}'
                                : '$orderCount order${orderCount == 1 ? "" : "s"} placed',
                            style: const TextStyle(color: AppColors.label, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 20),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.of(this.context).push(
                              MaterialPageRoute(
                                builder: (_) => OwnerChatThreadScreen(
                                  customerId: id,
                                  customerName: name,
                                  customerEmail: email.isNotEmpty ? email : null,
                                  customerAvatarUrl: avatar,
                                ),
                              ),
                            ).then((_) => _loadConversations(silent: true));
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: HomeColors.cardBackground,
        elevation: 0,
        title: const Text(
          'Customer Messages',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
        automaticallyImplyLeading: !widget.isTab,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: AppColors.primary, size: 22),
            tooltip: 'New Message',
            onPressed: _openNewMessagePicker,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: HomeColors.cardBackground,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: const TextStyle(color: AppColors.label, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.label, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.label, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: HomeColors.cardElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading && _conversations.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.purpleLight))
                : _error != null && _conversations.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: HomeColors.dangerText, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _loadConversations(),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.purpleLight),
                                child: const Text('Retry', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredConversations.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _loadConversations,
                            color: AppColors.purpleLight,
                            child: ListView(
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: HomeColors.cardElevated,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.label, size: 48),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No conversations yet',
                                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 40),
                                        child: Text(
                                          'When customers reach out with inquiries or order questions, they will appear here.',
                                          style: TextStyle(color: AppColors.label, fontSize: 14),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadConversations,
                            color: AppColors.purpleLight,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _filteredConversations.length,
                              separatorBuilder: (context, index) => const Divider(color: HomeColors.cardBorder, height: 1),
                              itemBuilder: (context, index) {
                                final conv = _filteredConversations[index];
                                final customerId = (conv['id'] ?? conv['user_id']) as int? ?? 0;
                                final customerName = (conv['name'] as String?)?.isNotEmpty == true
                                    ? conv['name'] as String
                                    : 'Customer #$customerId';
                                final lastMessage = conv['last_message'] as String? ?? '';
                                final unreadCount = (conv['unread_count'] as int?) ?? 0;
                                final lastMessageAt = conv['last_message_at'] as String?;
                                final avatarUrl = conv['avatar_url'] as String?;

                                String timeDisplay = '';
                                if (lastMessageAt != null && lastMessageAt.isNotEmpty) {
                                  try {
                                    final dt = parseApiDateTime(lastMessageAt).toLocal();
                                    final now = DateTime.now();
                                    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
                                      timeDisplay = DateFormat('h:mm a').format(dt);
                                    } else {
                                      timeDisplay = DateFormat('MMM d').format(dt);
                                    }
                                  } catch (_) {
                                    timeDisplay = '';
                                  }
                                }

                                return Dismissible(
                                  key: Key('conv_$customerId'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    color: HomeColors.dangerBg,
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 22),
                                        SizedBox(width: 6),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: HomeColors.dangerText, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  confirmDismiss: (_) => _confirmDeleteConversation(customerId, customerName),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    onLongPress: () => _confirmDeleteConversation(customerId, customerName),
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => OwnerChatThreadScreen(
                                            customerId: customerId,
                                            customerName: customerName,
                                            customerEmail: conv['email'] as String?,
                                            customerAvatarUrl: avatarUrl,
                                          ),
                                        ),
                                      );
                                      _loadConversations(silent: true);
                                    },
                                    leading: AppNotificationBadge(
                                      count: unreadCount,
                                      top: -2,
                                      right: -2,
                                      borderColor: const Color(0xFF1B1428),
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: const Color(0xFF3A3B3C),
                                        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                            ? NetworkImage(avatarUrl)
                                            : null,
                                        child: (avatarUrl == null || avatarUrl.isEmpty)
                                            ? const Icon(Icons.person, color: Colors.white, size: 34)
                                            : null,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            customerName,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (timeDisplay.isNotEmpty)
                                          Text(
                                            timeDisplay,
                                            style: TextStyle(
                                              color: unreadCount > 0 ? const Color(0xFFEF4444) : AppColors.label,
                                              fontSize: 12,
                                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                                              style: TextStyle(
                                                color: unreadCount > 0 ? Colors.white : AppColors.label,
                                                fontSize: 13.5,
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
                                                borderColor: HomeColors.cardBackground,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert_rounded,
                                        color: Colors.white38,
                                        size: 20,
                                      ),
                                      color: HomeColors.cardElevated,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      onSelected: (val) {
                                        if (val == 'delete') {
                                          _confirmDeleteConversation(customerId, customerName);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 18),
                                              SizedBox(width: 8),
                                              Text('Delete Convo', style: TextStyle(color: HomeColors.dangerText, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
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

class OwnerChatThreadScreen extends StatefulWidget {
  final int customerId;
  final String customerName;
  final String? customerEmail;
  final String? customerAvatarUrl;
  final int? orderId;

  const OwnerChatThreadScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerEmail,
    this.customerAvatarUrl,
    this.orderId,
  });

  @override
  State<OwnerChatThreadScreen> createState() => _OwnerChatThreadScreenState();
}

class _OwnerChatThreadScreenState extends State<OwnerChatThreadScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _isBlocked = false;
  bool _showOrderBanner = true;
  bool _showQuickReplies = true;
  String? _error;
  Timer? _pollTimer;

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  static const List<Map<String, dynamic>> _quickReplies = [
    {'icon': Icons.waving_hand_rounded, 'text': 'Hello! How can I help you today?'},
    {'icon': Icons.inventory_2_outlined, 'text': 'Your order is prepared and ready!'},
    {'icon': Icons.delivery_dining_outlined, 'text': 'Rider is on the way to deliver.'},
    {'icon': Icons.qr_code_rounded, 'text': 'Please send GCash payment screenshot.'},
    {'icon': Icons.favorite_border_rounded, 'text': 'Thank you for shopping with us!'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchBlockStatus();
    _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchBlockStatus() async {
    try {
      final blocked = await ApiClient.instance.checkBlockStatus(widget.customerId);
      if (mounted) setState(() => _isBlocked = blocked);
    } catch (_) {}
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final msgs = await ApiClient.instance.fetchMessages(widget.customerId);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onQuickReplyTap(String text) {
    setState(() {
      _textController.text = text;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    });
  }

  void _showMessageActionSheet(Map<String, dynamic> msg, bool isMe) {
    final text = msg['message'] as String? ?? '';
    final msgId = msg['id'] as int?;

    showModalBottomSheet(
      context: context,
      backgroundColor: HomeColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (text.isNotEmpty)
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF064E3B),
                    child: Icon(Icons.copy_rounded, color: Color(0xFF34D399), size: 18),
                  ),
                  title: const Text('Copy Text', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: const Text('Copy message text to clipboard', style: TextStyle(color: AppColors.label, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                            SizedBox(width: 8),
                            Text('Copied to clipboard', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                        backgroundColor: Color(0xFF1E142F),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              if (msgId != null)
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: HomeColors.dangerBg,
                    child: Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 18),
                  ),
                  title: Text(isMe ? 'Unsend Message' : 'Delete Message',
                      style: const TextStyle(color: HomeColors.dangerText, fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Text(
                    isMe ? 'Remove message for everyone' : 'Delete this message from chat',
                    style: const TextStyle(color: AppColors.label, fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: HomeColors.cardBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 22),
                            const SizedBox(width: 10),
                            Text(isMe ? 'Unsend Message?' : 'Delete Message?',
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: Text(
                          isMe
                              ? 'This message will be removed for both you and the customer.'
                              : 'Are you sure you want to delete this message?',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dCtx).pop(false),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HomeColors.dangerText,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.of(dCtx).pop(true),
                            child: Text(isMe ? 'Unsend' : 'Delete', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      try {
                        await ApiClient.instance.deleteMessage(msgId);
                        if (mounted) {
                          setState(() {
                            _messages.removeWhere((m) => m['id'] == msgId);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isMe ? 'Message unsent' : 'Message deleted',
                                  style: const TextStyle(color: Colors.white)),
                              backgroundColor: HomeColors.cardElevated,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete message: $e'),
                              backgroundColor: HomeColors.dangerText,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBlock() async {
    final willBlock = !_isBlocked;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        title: Text(willBlock ? 'Block Customer?' : 'Unblock Customer?', style: const TextStyle(color: Colors.white)),
        content: Text(
          willBlock
              ? 'Blocking ${widget.customerName} will prevent them from sending you messages and suppress notifications.'
              : 'Unblock ${widget.customerName} so they can message you again?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: willBlock ? HomeColors.dangerText : AppColors.purpleLight,
            ),
            child: Text(willBlock ? 'Block' : 'Unblock', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (willBlock) {
        await ApiClient.instance.blockCustomer(widget.customerId);
      } else {
        await ApiClient.instance.unblockCustomer(widget.customerId);
      }
      if (mounted) {
        setState(() => _isBlocked = willBlock);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willBlock ? '${widget.customerName} has been blocked' : '${widget.customerName} has been unblocked',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: willBlock ? HomeColors.dangerText : HomeColors.successText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update block status: $e'), backgroundColor: HomeColors.dangerText),
        );
      }
    }
  }

  Future<void> _showReportDialog() async {
    String selectedReason = 'harassment';
    final descriptionController = TextEditingController();
    bool alsoBlock = !_isBlocked;
    bool isSubmitting = false;

    final reasons = [
      {'value': 'harassment', 'label': 'Harassment / Abusive Behavior'},
      {'value': 'fraud', 'label': 'Fraud / Scam / Non-payment'},
      {'value': 'fake_order', 'label': 'Fake / Suspicious Order'},
      {'value': 'inappropriate_content', 'label': 'Inappropriate Photos or Content'},
      {'value': 'spam', 'label': 'Spam / Unsolicited Promotion'},
      {'value': 'other', 'label': 'Other Violation'},
    ];

    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: HomeColors.cardBackground,
        isScrollControlled: true,
        isDismissible: !isSubmitting,
        enableDrag: !isSubmitting,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (sheetCtx, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.fieldBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.report_problem_rounded, color: Colors.amber, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.customerName.isNotEmpty ? 'Report ${widget.customerName}' : 'Report Customer',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  'Reports are investigated by Stora platform admins.',
                                  style: TextStyle(fontSize: 12, color: AppColors.label),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Reason for Report',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.label),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.fieldBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedReason,
                            isExpanded: true,
                            dropdownColor: HomeColors.cardElevated,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            items: reasons.map((r) {
                              return DropdownMenuItem<String>(
                                value: r['value'],
                                child: Text(r['label']!),
                              );
                            }).toList(),
                            onChanged: isSubmitting
                                ? null
                                : (val) {
                                    if (val != null) setSheetState(() => selectedReason = val);
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Details / Description',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.label),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        enabled: !isSubmitting,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Describe what happened (e.g. offensive messages, bogus orders)...',
                          hintStyle: const TextStyle(color: AppColors.hint, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.fieldBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      if (!_isBlocked) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: isSubmitting ? null : () => setSheetState(() => alsoBlock = !alsoBlock),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: alsoBlock,
                                    activeColor: AppColors.primary,
                                    onChanged: isSubmitting ? null : (val) => setSheetState(() => alsoBlock = val ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Also block this customer from messaging me',
                                    style: TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.fieldBorder),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      setSheetState(() => isSubmitting = true);
                                      try {
                                        await ApiClient.instance.submitReport(
                                          reportedUserId: widget.customerId,
                                          reason: selectedReason,
                                          description: descriptionController.text.trim(),
                                          orderId: widget.orderId,
                                        );

                                        if (alsoBlock && !_isBlocked) {
                                          try {
                                            await ApiClient.instance.blockCustomer(widget.customerId);
                                            if (mounted) setState(() => _isBlocked = true);
                                          } catch (_) {}
                                        }

                                        if (ctx.mounted) Navigator.of(ctx).pop();

                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Report submitted. Our administrators will review this user.',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                            backgroundColor: HomeColors.successText,
                                          ),
                                        );
                                      } catch (e) {
                                        if (ctx.mounted) setSheetState(() => isSubmitting = false);
                                        final eStr = e.toString().toLowerCase();
                                        final msg = eStr.contains('pending report') || eStr.contains('already have')
                                            ? 'You already have an active pending report for this user.'
                                            : 'Failed to submit report: $e';
                                        messenger.showSnackBar(
                                          SnackBar(content: Text(msg), backgroundColor: HomeColors.dangerText),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[700],
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Submit Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      descriptionController.dispose();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1200);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = picked.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: HomeColors.dangerText),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImageBytes == null) return;
    if (_sending) return;

    setState(() => _sending = true);

    try {
      await ApiClient.instance.sendChatMessage(
        recipientId: widget.customerId,
        message: text.isNotEmpty ? text : null,
        imageBytes: _selectedImageBytes,
        filename: _selectedImageName ?? 'chat_image.jpg',
        orderId: widget.orderId,
      );

      _textController.clear();
      setState(() {
        _selectedImageBytes = null;
        _selectedImageName = null;
      });

      await _fetchMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e'), backgroundColor: HomeColors.dangerText),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }

  void _showImageFullscreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: AppColors.purpleLight));
                  },
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 22),
            SizedBox(width: 10),
            Text('Delete Conversation?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all messages with ${widget.customerName}? This cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeColors.dangerText,
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
        await ChatStore.instance.deleteConversation(widget.customerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversation with ${widget.customerName} deleted', style: const TextStyle(color: Colors.white)),
              backgroundColor: HomeColors.cardElevated,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete conversation: $e'),
              backgroundColor: HomeColors.dangerText,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: HomeColors.cardBackground,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFF3A3B3C),
              backgroundImage: (widget.customerAvatarUrl != null && widget.customerAvatarUrl!.isNotEmpty)
                  ? NetworkImage(widget.customerAvatarUrl!)
                  : null,
              child: (widget.customerAvatarUrl == null || widget.customerAvatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 22)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customerName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isBlocked
                        ? 'Blocked'
                        : ((widget.customerEmail != null && widget.customerEmail!.isNotEmpty)
                            ? widget.customerEmail!
                            : 'Customer'),
                    style: TextStyle(
                      color: _isBlocked ? HomeColors.dangerText : AppColors.label,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            color: HomeColors.cardElevated,
            onSelected: (val) {
              if (val == 'report') _showReportDialog();
              if (val == 'block') _toggleBlock();
              if (val == 'delete') _deleteConversation();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Report Customer',
                      style: TextStyle(color: Colors.amber),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      _isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                      color: _isBlocked ? HomeColors.successText : HomeColors.dangerText,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isBlocked ? 'Unblock Customer' : 'Block Customer',
                      style: TextStyle(color: _isBlocked ? HomeColors.successText : HomeColors.dangerText),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: HomeColors.dangerText,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Delete Conversation',
                      style: TextStyle(color: HomeColors.dangerText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.orderId != null && _showOrderBanner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: const BoxDecoration(
                color: Color(0xFF1E142F),
                border: Border(
                  left: BorderSide(color: Color(0xFF10B981), width: 3.5),
                  bottom: BorderSide(color: Colors.white10, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Color(0xFF34D399), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Order #${widget.orderId}',
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Active Order Chat',
                      style: TextStyle(color: Color(0xFF34D399), fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showOrderBanner = false),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          if (_isBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: HomeColors.dangerBg,
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, color: HomeColors.dangerText, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'This customer is blocked. They cannot message you.',
                      style: TextStyle(color: HomeColors.dangerText, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleBlock,
                    child: const Text('Unblock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.purpleLight))
                : _error != null && _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: HomeColors.dangerText, size: 40),
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => _fetchMessages(),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.purpleLight),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 38,
                                  backgroundColor: const Color(0xFF3A3B3C),
                                  backgroundImage: (widget.customerAvatarUrl != null && widget.customerAvatarUrl!.isNotEmpty)
                                      ? NetworkImage(widget.customerAvatarUrl!)
                                      : null,
                                  child: (widget.customerAvatarUrl == null || widget.customerAvatarUrl!.isEmpty)
                                      ? const Icon(Icons.person, color: Colors.white, size: 44)
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                Text(widget.customerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('You\'re connected on Stora', style: TextStyle(color: AppColors.label, fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final senderId = msg['sender_id'] ?? msg['sender'];
                          final senderRole = msg['sender_role'] as String?;
                          final bool isMe = (senderRole != null && (senderRole == 'owner' || senderRole == 'admin')) ||
                              (senderRole == null && senderId != null && senderId != widget.customerId);
                          final text = msg['message'] as String? ?? '';
                          final rawImg = msg['image'] as String?;
                          final orderId = msg['order'] as int?;
                          final createdAt = msg['created_at'] as String?;

                          String timeDisplay = '';
                          if (createdAt != null) {
                            try {
                              final dt = parseApiDateTime(createdAt).toLocal();
                              timeDisplay = DateFormat('h:mm a').format(dt);
                            } catch (_) {}
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              children: [
                                if (!isMe) ...[
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF3A3B3C),
                                    backgroundImage: (widget.customerAvatarUrl != null && widget.customerAvatarUrl!.isNotEmpty)
                                        ? NetworkImage(widget.customerAvatarUrl!)
                                        : null,
                                    child: (widget.customerAvatarUrl == null || widget.customerAvatarUrl!.isEmpty)
                                        ? const Icon(Icons.person, color: Colors.white, size: 16)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: () => _showMessageActionSheet(msg, isMe),
                                    child: Container(
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
                                      decoration: BoxDecoration(
                                        gradient: isMe ? HomeColors.purpleGradient : null,
                                        color: isMe ? null : HomeColors.cardElevated,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                                        ),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2)),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          if (orderId != null)
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.black26,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.receipt_long_rounded, color: Colors.white70, size: 13),
                                                  const SizedBox(width: 4),
                                                  Text('Order #$orderId', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          if (rawImg != null && rawImg.isNotEmpty) ...[
                                            GestureDetector(
                                              onTap: () => _showImageFullscreen(_resolveImageUrl(rawImg)),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: Image.network(
                                                  _resolveImageUrl(rawImg),
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: 180,
                                                  loadingBuilder: (_, child, progress) {
                                                    if (progress == null) return child;
                                                    return Container(
                                                      height: 180,
                                                      color: Colors.black12,
                                                      child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                                    );
                                                  },
                                                  errorBuilder: (context, error, stackTrace) => Container(
                                                    height: 100,
                                                    color: Colors.black12,
                                                    child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white54)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (text.isNotEmpty) const SizedBox(height: 6),
                                          ],
                                          if (text.isNotEmpty)
                                            Text(
                                              text,
                                              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                                            ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                timeDisplay,
                                                style: TextStyle(
                                                  color: isMe ? Colors.white70 : AppColors.label,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              if (isMe) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  (msg['is_read'] == true)
                                                      ? Icons.done_all_rounded
                                                      : Icons.done_rounded,
                                                  size: 13,
                                                  color: (msg['is_read'] == true)
                                                      ? const Color(0xFF38BDF8)
                                                      : Colors.white60,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (_selectedImageBytes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: HomeColors.cardBackground,
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_selectedImageBytes!, width: 60, height: 60, fit: BoxFit.cover),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedImageBytes = null;
                          _selectedImageName = null;
                        }),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.black87,
                          child: Icon(Icons.close_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Text('Photo ready to send', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          if (!_isBlocked && _showQuickReplies)
            Container(
              height: 44,
              color: HomeColors.cardBackground,
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickReplies.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final item = _quickReplies[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _onQuickReplyTap(item['text'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26193E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item['icon'] as IconData, color: const Color(0xFFA78BFA), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            item['text'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (!_isBlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: HomeColors.cardBackground,
                border: Border(top: BorderSide(color: HomeColors.cardBorder, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        _showQuickReplies ? Icons.bolt_rounded : Icons.bolt_outlined,
                        color: _showQuickReplies ? const Color(0xFFA78BFA) : AppColors.label,
                        size: 22,
                      ),
                      tooltip: 'Quick Replies',
                      onPressed: () => setState(() => _showQuickReplies = !_showQuickReplies),
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, color: AppColors.label, size: 22),
                      onPressed: _sending ? null : () => _pickImage(ImageSource.camera),
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined, color: AppColors.label, size: 22),
                      onPressed: _sending ? null : () => _pickImage(ImageSource.gallery),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: const TextStyle(color: AppColors.label, fontSize: 14),
                          filled: true,
                          fillColor: HomeColors.cardElevated,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: HomeColors.purpleGradient,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: _sending ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
