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
import '../theme/theme_mode_controller.dart';
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
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    ThemeModeController.instance.addListener(_onThemeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadConversations();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) _loadConversations(silent: true);
    });
  }

  @override
  void dispose() {
    ThemeModeController.instance.removeListener(_onThemeChanged);
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
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

  Future<void> _openSupportChat() async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      final support = await ApiClient.instance.getSupportContact();
      if (!mounted) return;
      if (support != null) {
        final supportId = ((support['id'] ?? support['user_id']) as num?)?.toInt() ?? 1;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OwnerChatThreadScreen(
              customerId: supportId,
              customerName: support['name'] ?? 'STORA Support',
              customerEmail: support['email'] ?? 'support@stora.app',
              customerAvatarUrl: support['avatar_url'],
              isSupport: true,
            ),
          ),
        );
        if (mounted) {
          _loadConversations(silent: true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support service is currently unavailable.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reach support: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  Widget _buildSupportCard() {
    final supportConvo = _conversations.firstWhere(
      (c) => c['is_support'] == true,
      orElse: () => const {},
    );
    final supportAvatar = ApiConfig.resolveMediaUrl(supportConvo['avatar_url']?.toString());
    final hasSupportAvatar = supportAvatar != null && supportAvatar.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openSupportChat,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.16),
                  HomeColors.cardElevated,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                hasSupportAvatar
                    ? CircleAvatar(
                        radius: 21,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        backgroundImage: NetworkImage(supportAvatar),
                      )
                    : Container(
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
                          Text(
                            'STORA Store Support',
                            style: TextStyle(color: HomeColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('OFFICIAL', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Direct help with store, billing & issues',
                        style: TextStyle(color: HomeColors.textSecondary, fontSize: 12),
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
                      SizedBox(width: 4),
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

  Future<bool> _confirmDeleteConversation(int customerId, String customerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 22),
            const SizedBox(width: 10),
            Text('Delete Conversation?', style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the conversation with $customerName? This will only be removed for you; the other person can still see it unless they delete it too.',
          style: TextStyle(color: HomeColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
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
                        Text(
                          'Select Customer to Message',
                          style: TextStyle(color: HomeColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: HomeColors.textSecondary, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: HomeColors.cardBorder, height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: customers.length,
                      separatorBuilder: (context, index) => Divider(color: HomeColors.cardBorder, height: 1),
                      itemBuilder: (context, i) {
                        final c = customers[i];
                        final id = c['id'] as int;
                        final name = (c['name'] as String?)?.isNotEmpty == true
                            ? c['name'] as String
                            : 'Customer #$id';
                        final email = (c['email'] as String?) ?? '';
                        final avatar = ApiConfig.resolveMediaUrl(c['avatar_url'] as String?);
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
                          title: Text(name, style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w600)),
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
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        backgroundColor: HomeColors.cardBackground,
        elevation: 0,
        title: Text(
          'Customer Messages',
          style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: widget.isTab
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: HomeColors.textPrimary, size: 20),
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
              style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
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
          if (_searchQuery.trim().isEmpty || 'stora support'.contains(_searchQuery.trim().toLowerCase()))
            _buildSupportCard(),
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
                              Icon(Icons.error_outline_rounded, color: HomeColors.dangerText, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, style: TextStyle(color: HomeColors.textSecondary), textAlign: TextAlign.center),
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
                                      Text(
                                        'No conversations yet',
                                        style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
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
                              separatorBuilder: (context, index) => Divider(color: HomeColors.cardBorder, height: 1),
                              itemBuilder: (context, index) {
                                final conv = _filteredConversations[index];
                                final customerId = (conv['id'] ?? conv['user_id']) as int? ?? 0;
                                final rawName = (conv['name'] as String?)?.trim() ?? '';
                                final isSupport = conv['is_support'] == true ||
                                    conv['role'] == 'admin' ||
                                    rawName.toLowerCase().contains('stora support');
                                final customerName = isSupport
                                    ? 'STORA Support'
                                    : (rawName.isNotEmpty ? rawName : 'Customer #$customerId');
                                final lastMessage = conv['last_message'] as String? ?? '';
                                final unreadCount = (conv['unread_count'] as int?) ?? 0;
                                final lastMessageAt = conv['last_message_at'] as String?;
                                final avatarUrl = ApiConfig.resolveMediaUrl(conv['avatar_url'] as String?);

                                String timeDisplay = '';
                                if (lastMessageAt != null && lastMessageAt.isNotEmpty) {
                                  try {
                                    final dt = toManila(parseApiDateTime(lastMessageAt));
                                    final now = toManila(DateTime.now());
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
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 22),
                                        const SizedBox(width: 6),
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
                                      if (_isNavigating) return;
                                      _isNavigating = true;
                                      try {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => OwnerChatThreadScreen(
                                              customerId: customerId,
                                              customerName: customerName,
                                              customerEmail: conv['email'] as String?,
                                              customerAvatarUrl: avatarUrl,
                                              isSupport: isSupport,
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isNavigating = false);
                                          _loadConversations(silent: true);
                                        } else {
                                          _isNavigating = false;
                                        }
                                      }
                                    },
                                    leading: AppNotificationBadge(
                                      count: unreadCount,
                                      top: -2,
                                      right: -2,
                                      borderColor: const Color(0xFF1B1428),
                                      child: isSupport
                                          ? ((avatarUrl != null && avatarUrl.isNotEmpty)
                                              ? CircleAvatar(
                                                  radius: 28,
                                                  backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.15),
                                                  backgroundImage: NetworkImage(avatarUrl),
                                                )
                                              : Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: const Color(0xFFF97316).withValues(alpha: 0.15),
                                                    border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.5), width: 1.5),
                                                  ),
                                                  child: const Icon(
                                                    Icons.support_agent_rounded,
                                                    color: Color(0xFFF97316),
                                                    size: 30,
                                                  ),
                                                ))
                                          : CircleAvatar(
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
                                        Flexible(
                                          child: Text(
                                            customerName,
                                            style: TextStyle(
                                              color: HomeColors.textPrimary,
                                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSupport) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF97316).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'OFFICIAL',
                                              style: TextStyle(
                                                color: Color(0xFFF97316),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
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
                                         } else if (val == 'report') {
                                           showOwnerReportCustomerDialog(
                                             context: context,
                                             customerId: customerId,
                                             customerName: customerName,
                                           );
                                         }
                                       },
                                       itemBuilder: (_) => [
                                         if (!isSupport)
                                           PopupMenuItem(
                                             value: 'report',
                                             child: Row(
                                               children: [
                                                 const Icon(Icons.report_problem_outlined, color: Colors.amber, size: 18),
                                                 const SizedBox(width: 8),
                                                 Text('Report Customer', style: TextStyle(color: HomeColors.textPrimary, fontSize: 13)),
                                               ],
                                             ),
                                           ),
                                         PopupMenuItem(
                                           value: 'delete',
                                           child: Row(
                                             children: [
                                               Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 18),
                                               const SizedBox(width: 8),
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
  final bool isSupport;

  const OwnerChatThreadScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerEmail,
    this.customerAvatarUrl,
    this.orderId,
    this.isSupport = false,
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
  int? _tappedMessageId;

  bool get _isSupportChat =>
      widget.isSupport || widget.customerName.trim().toLowerCase().contains('stora support');

  static const List<Map<String, dynamic>> _quickReplies = [
    {'icon': Icons.waving_hand_rounded, 'text': 'Hello! How can I help you today?'},
    {'icon': Icons.inventory_2_outlined, 'text': 'Your order is prepared and ready!'},
    {'icon': Icons.delivery_dining_outlined, 'text': 'Rider is on the way to deliver.'},
    {'icon': Icons.qr_code_rounded, 'text': 'Please send GCash payment screenshot.'},
    {'icon': Icons.favorite_border_rounded, 'text': 'Thank you for shopping with us!'},
  ];

  static const List<Map<String, dynamic>> _supportQuickReplies = [
    {'icon': Icons.help_outline_rounded, 'text': 'I need help verifying my store'},
    {'icon': Icons.card_membership_rounded, 'text': 'Question about subscription and payments'},
    {'icon': Icons.shopping_bag_outlined, 'text': 'Having an issue with an order or customer'},
    {'icon': Icons.bug_report_outlined, 'text': 'I want to report an app bug or feedback'},
    {'icon': Icons.support_agent_rounded, 'text': 'Can I speak with a support agent?'},
  ];

  @override
  void initState() {
    super.initState();
    ThemeModeController.instance.addListener(_onThemeChanged);
    final cached = ChatStore.instance.getCachedMessages(widget.customerId);
    if (cached != null && cached.isNotEmpty) {
      _messages = cached;
      _loading = false;
    }
    _fetchBlockStatus();
    _fetchMessages(silent: _messages.isNotEmpty);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    ThemeModeController.instance.removeListener(_onThemeChanged);
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    ChatStore.instance.fetchConversations(isSilent: true);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchBlockStatus() async {
    if (_isSupportChat) return;
    try {
      final blocked = await ApiClient.instance.checkBlockStatus(widget.customerId);
      if (mounted) setState(() => _isBlocked = blocked);
    } catch (_) {}
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final msgs = await ApiClient.instance.fetchMessages(widget.customerId);
      ChatStore.instance.cacheMessages(widget.customerId, msgs);
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
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: HomeColors.dangerBg,
                    child: Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 18),
                  ),
                  title: Text(isMe ? 'Unsend Message' : 'Delete Message',
                      style: TextStyle(color: HomeColors.dangerText, fontWeight: FontWeight.w600, fontSize: 15)),
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
                            Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 22),
                            const SizedBox(width: 10),
                            Text(isMe ? 'Unsend Message?' : 'Delete Message?',
                                style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: Text(
                          isMe
                              ? 'This message will be removed for both you and the customer.'
                              : 'Are you sure you want to delete this message?',
                          style: TextStyle(color: HomeColors.textSecondary, fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dCtx).pop(false),
                            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
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
                            if (isMe) {
                              final idx = _messages.indexWhere((m) => m['id'] == msgId);
                              if (idx != -1) {
                                _messages[idx] = {
                                  ..._messages[idx],
                                  'is_unsent': true,
                                  'message': 'You unsent a message',
                                  'image': null,
                                };
                              }
                            } else {
                              _messages.removeWhere((m) => m['id'] == msgId);
                            }
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
        title: Text(willBlock ? 'Block Customer?' : 'Unblock Customer?', style: TextStyle(color: HomeColors.textPrimary)),
        content: Text(
          willBlock
              ? 'Blocking ${widget.customerName} will prevent them from sending you messages and suppress notifications.'
              : 'Unblock ${widget.customerName} so they can message you again?',
          style: TextStyle(color: HomeColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
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
    await showOwnerReportCustomerDialog(
      context: context,
      customerId: widget.customerId,
      customerName: widget.customerName,
      orderId: widget.orderId,
      isBlocked: _isBlocked,
      onBlockedChanged: (val) {
        if (mounted) setState(() => _isBlocked = val);
      },
    );
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
    return ApiConfig.resolveMediaUrl(url) ?? '';
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
                  errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, color: Colors.white70, size: 48)),
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
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: HomeColors.dangerText, size: 22),
            const SizedBox(width: 10),
            Text('Delete Conversation?', style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the conversation with ${widget.customerName}? This will only be removed for you; the other person can still see it unless they delete it too.',
          style: TextStyle(color: HomeColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
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
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        backgroundColor: HomeColors.cardBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: HomeColors.textPrimary),
        titleSpacing: 0,
        title: Row(
          children: [
            Builder(
              builder: (context) {
                final customerAvatar = _resolveImageUrl(widget.customerAvatarUrl);
                if (_isSupportChat) {
                  return customerAvatar.isNotEmpty
                      ? CircleAvatar(
                          radius: 19,
                          backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.15),
                          backgroundImage: NetworkImage(customerAvatar),
                        )
                      : Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: const Icon(Icons.support_agent_rounded, color: Color(0xFFF97316), size: 22),
                        );
                }
                return CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFF3A3B3C),
                  backgroundImage: customerAvatar.isNotEmpty
                      ? NetworkImage(customerAvatar)
                      : null,
                  child: customerAvatar.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 22)
                      : null,
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _isSupportChat ? 'STORA Support' : widget.customerName,
                          style: TextStyle(color: HomeColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isSupportChat) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OFFICIAL',
                            style: TextStyle(
                              color: Color(0xFFF97316),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _isSupportChat
                        ? 'Official Support'
                        : (_isBlocked
                            ? 'Blocked'
                            : ((widget.customerEmail != null && widget.customerEmail!.isNotEmpty)
                                ? widget.customerEmail!
                                : 'Customer')),
                    style: TextStyle(
                      color: _isSupportChat ? const Color(0xFFF97316) : (_isBlocked ? HomeColors.dangerText : HomeColors.textSecondary),
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
            icon: Icon(Icons.more_vert_rounded, color: HomeColors.textSecondary),
            color: HomeColors.cardElevated,
            onSelected: (val) {
              if (val == 'report') _showReportDialog();
              if (val == 'block') _toggleBlock();
              if (val == 'delete') _deleteConversation();
            },
            itemBuilder: (ctx) => [
              if (!_isSupportChat) ...[
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
                        color: _isBlocked ? Colors.green : HomeColors.dangerText,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isBlocked ? 'Unblock Customer' : 'Block Customer',
                        style: TextStyle(color: _isBlocked ? Colors.green : HomeColors.dangerText),
                      ),
                    ],
                  ),
                ),
              ],
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: HomeColors.dangerText,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isSupportChat ? 'Clear Conversation' : 'Delete Conversation',
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
                  Icon(Icons.block_rounded, color: HomeColors.dangerText, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
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
                            Icon(Icons.error_outline_rounded, color: HomeColors.dangerText, size: 40),
                            const SizedBox(height: 8),
                            Text(_error!, style: TextStyle(color: HomeColors.textSecondary)),
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
                                Builder(
                                  builder: (context) {
                                    final customerAvatar = _resolveImageUrl(widget.customerAvatarUrl);
                                    if (_isSupportChat) {
                                      return customerAvatar.isNotEmpty
                                          ? CircleAvatar(
                                              radius: 38,
                                              backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.15),
                                              backgroundImage: NetworkImage(customerAvatar),
                                            )
                                          : Container(
                                              width: 76,
                                              height: 76,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFFF97316).withValues(alpha: 0.15),
                                                border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.5), width: 1.5),
                                              ),
                                              child: const Icon(Icons.support_agent_rounded, color: Color(0xFFF97316), size: 44),
                                            );
                                    }
                                    return CircleAvatar(
                                      radius: 38,
                                      backgroundColor: const Color(0xFF3A3B3C),
                                      backgroundImage: customerAvatar.isNotEmpty
                                          ? NetworkImage(customerAvatar)
                                          : null,
                                      child: customerAvatar.isEmpty
                                          ? const Icon(Icons.person, color: Colors.white, size: 44)
                                          : null,
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _isSupportChat ? 'STORA Support' : widget.customerName,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isSupportChat ? 'Official STORA Help & Support Desk' : 'You\'re connected on Stora',
                                  style: const TextStyle(color: AppColors.label, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              int lastMeIndex = -1;
                              for (int i = _messages.length - 1; i >= 0; i--) {
                                 final m = _messages[i];
                                 final mSenderId = m['sender_id'] ?? m['sender'];
                                 final mSenderRole = m['sender_role'] as String?;
                                 final bool mIsMe = (m['is_me'] is bool)
                                     ? (m['is_me'] as bool)
                                     : ((mSenderRole != null && (mSenderRole == 'owner' || mSenderRole == 'admin')) ||
                                        (mSenderRole == null && mSenderId != null && mSenderId != widget.customerId));
                                 if (mIsMe && m['is_unsent'] != true) {
                                   lastMeIndex = i;
                                   break;
                                 }
                               }

                               return ListView.builder(
                                 controller: _scrollController,
                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                 itemCount: _messages.length,
                                 itemBuilder: (context, index) {
                                   final msg = _messages[index];
                                   final senderId = msg['sender_id'] ?? msg['sender'];
                                   final senderRole = msg['sender_role'] as String?;
                                   final bool isMe = (msg['is_me'] is bool)
                                       ? (msg['is_me'] as bool)
                                       : ((senderRole != null && (senderRole == 'owner' || senderRole == 'admin')) ||
                                          (senderRole == null && senderId != null && senderId != widget.customerId));
                                  final text = msg['message'] as String? ?? '';
                                  final rawImg = msg['image'] as String?;
                                  final orderId = msg['order'] as int?;
                                  final createdAt = msg['created_at'] as String?;

                                  String timeDisplay = '';
                                  DateTime? currentDt;
                                  if (createdAt != null && createdAt.isNotEmpty) {
                                    try {
                                      currentDt = toManila(parseApiDateTime(createdAt));
                                      timeDisplay = DateFormat('h:mm a').format(currentDt);
                                    } catch (_) {}
                                  }

                                  bool showHeader = false;
                                  String headerText = '';
                                  if (currentDt != null) {
                                    if (index == 0) {
                                      showHeader = true;
                                    } else {
                                      final prevMsg = _messages[index - 1];
                                      final prevCreatedAt = prevMsg['created_at'] as String?;
                                      if (prevCreatedAt != null && prevCreatedAt.isNotEmpty) {
                                        try {
                                          final prevDt = toManila(parseApiDateTime(prevCreatedAt));
                                          if (currentDt.difference(prevDt).inMinutes.abs() >= 20 ||
                                              currentDt.day != prevDt.day ||
                                              currentDt.month != prevDt.month ||
                                              currentDt.year != prevDt.year) {
                                            showHeader = true;
                                          }
                                        } catch (_) {
                                          showHeader = true;
                                        }
                                      } else {
                                        showHeader = true;
                                      }
                                    }

                                    if (showHeader) {
                                      final now = toManila(DateTime.now());
                                      final isToday = currentDt.year == now.year && currentDt.month == now.month && currentDt.day == now.day;
                                      final yesterday = now.subtract(const Duration(days: 1));
                                      final isYesterday = currentDt.year == yesterday.year && currentDt.month == yesterday.month && currentDt.day == yesterday.day;
                                      final timeStr = DateFormat('h:mm a').format(currentDt);

                                      if (isToday) {
                                        headerText = timeStr;
                                      } else if (isYesterday) {
                                        headerText = 'YESTERDAY AT $timeStr';
                                      } else if (currentDt.year == now.year) {
                                        headerText = '${DateFormat('MMM d').format(currentDt).toUpperCase()} AT $timeStr';
                                      } else {
                                        headerText = '${DateFormat('MMM d, yyyy').format(currentDt).toUpperCase()} AT $timeStr';
                                      }
                                    }
                                  }

                                  final msgId = msg['id'] as int? ?? index;
                                  final bool isTapped = (_tappedMessageId == msgId);
                                  final bool isLastMeInThread = (index == lastMeIndex);

                                  bool isLastOfCluster = true;
                                  if (index < _messages.length - 1) {
                                    final nextMsg = _messages[index + 1];
                                    final nextSenderId = nextMsg['sender_id'] ?? nextMsg['sender'];
                                    final nextSenderRole = nextMsg['sender_role'] as String?;
                                    final bool nextIsMe = (nextMsg['is_me'] is bool)
                                        ? (nextMsg['is_me'] as bool)
                                        : ((nextSenderRole != null && (nextSenderRole == 'owner' || nextSenderRole == 'admin')) ||
                                           (nextSenderRole == null && nextSenderId != null && nextSenderId != widget.customerId));
                                    if (nextIsMe == isMe && nextMsg['is_unsent'] != true) {
                                      isLastOfCluster = false;
                                    }
                                  }

                                  final isUnsent = msg['is_unsent'] == true;

                                  if (isUnsent) {
                                    return Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (showHeader && headerText.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Center(
                                              child: Text(
                                                headerText,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                            children: [
                                               if (!isMe) ...[
                                                Builder(
                                                  builder: (context) {
                                                    final bubbleAvatar = _resolveImageUrl((msg['sender_avatar_url'] ?? widget.customerAvatarUrl)?.toString());
                                                    final hasBubbleAvatar = bubbleAvatar.isNotEmpty;
                                                    if (_isSupportChat) {
                                                      return hasBubbleAvatar
                                                          ? CircleAvatar(
                                                              radius: 14,
                                                              backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.15),
                                                              backgroundImage: NetworkImage(bubbleAvatar),
                                                            )
                                                          : Container(
                                                              width: 28,
                                                              height: 28,
                                                              decoration: BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                color: const Color(0xFFF97316).withValues(alpha: 0.15),
                                                                border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.5), width: 1),
                                                              ),
                                                              child: const Icon(Icons.support_agent_rounded, color: Color(0xFFF97316), size: 16),
                                                            );
                                                    }
                                                    return CircleAvatar(
                                                      radius: 14,
                                                      backgroundColor: const Color(0xFF3A3B3C),
                                                      backgroundImage: hasBubbleAvatar ? NetworkImage(bubbleAvatar) : null,
                                                      child: !hasBubbleAvatar ? const Icon(Icons.person, color: Colors.white, size: 16) : null,
                                                    );
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Container(
                                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: Colors.white12,
                                                    width: 1,
                                                  ),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.undo_rounded, size: 14, color: AppColors.label),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        isMe ? 'You unsent a message' : '${_isSupportChat ? 'STORA Support' : widget.customerName} unsent a message',
                                                        style: const TextStyle(
                                                          color: AppColors.label,
                                                          fontSize: 13,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (showHeader && headerText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          child: Center(
                                            child: Text(
                                              headerText,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: EdgeInsets.only(bottom: (isLastOfCluster || isLastMeInThread || isTapped) ? 6 : 2),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                          children: [
                                            if (!isMe) ...[
                                              if (isLastOfCluster)
                                                Builder(
                                                  builder: (context) {
                                                    final bubbleAvatar = _resolveImageUrl((msg['sender_avatar_url'] ?? widget.customerAvatarUrl)?.toString());
                                                    final hasBubbleAvatar = bubbleAvatar.isNotEmpty;
                                                    if (_isSupportChat) {
                                                      return hasBubbleAvatar
                                                          ? CircleAvatar(
                                                              radius: 14,
                                                              backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.15),
                                                              backgroundImage: NetworkImage(bubbleAvatar),
                                                            )
                                                          : Container(
                                                              width: 28,
                                                              height: 28,
                                                              decoration: BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                color: const Color(0xFFF97316).withValues(alpha: 0.15),
                                                                border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.5), width: 1),
                                                              ),
                                                              child: const Icon(Icons.support_agent_rounded, color: Color(0xFFF97316), size: 16),
                                                            );
                                                    }
                                                    return CircleAvatar(
                                                      radius: 14,
                                                      backgroundColor: const Color(0xFF3A3B3C),
                                                      backgroundImage: hasBubbleAvatar ? NetworkImage(bubbleAvatar) : null,
                                                      child: !hasBubbleAvatar ? const Icon(Icons.person, color: Colors.white, size: 16) : null,
                                                    );
                                                  },
                                                )
                                              else
                                                const SizedBox(width: 28),
                                              const SizedBox(width: 8),
                                            ],
                                            Flexible(
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _tappedMessageId = (_tappedMessageId == msgId) ? null : msgId;
                                                  });
                                                },
                                                onLongPress: () => _showMessageActionSheet(msg, isMe),
                                                child: Container(
                                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
                                                  decoration: BoxDecoration(
                                                    gradient: isMe ? HomeColors.purpleGradient : null,
                                                    color: isMe ? null : HomeColors.cardElevated,
                                                    border: !isMe && !ThemeModeController.instance.isDarkMode ? Border.all(color: HomeColors.cardBorder) : null,
                                                    borderRadius: BorderRadius.only(
                                                      topLeft: const Radius.circular(16),
                                                      topRight: const Radius.circular(16),
                                                      bottomLeft: isMe ? const Radius.circular(16) : Radius.circular(isLastOfCluster ? 4 : 16),
                                                      bottomRight: isMe ? Radius.circular(isLastOfCluster ? 4 : 16) : const Radius.circular(16),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(color: Colors.black.withValues(alpha: ThemeModeController.instance.isDarkMode ? 0.15 : 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                                                    ],
                                                  ),
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                                          style: TextStyle(
                                                            color: isMe ? Colors.white : HomeColors.textPrimary,
                                                            fontSize: 14.5,
                                                            height: 1.3,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isMe && (isLastMeInThread || isTapped)) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2, right: 6, bottom: 4),
                                          child: Text(
                                            isTapped && timeDisplay.isNotEmpty
                                                ? '$timeDisplay • ${(msg['is_read'] == true) ? 'Seen' : 'Delivered'}'
                                                : ((msg['is_read'] == true) ? 'Seen' : 'Delivered'),
                                            style: TextStyle(
                                              color: HomeColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ] else if (!isMe && isTapped && timeDisplay.isNotEmpty) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2, left: 36, bottom: 4),
                                          child: Text(
                                            timeDisplay,
                                            style: TextStyle(
                                              color: HomeColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
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
                  Text('Photo ready to send', style: TextStyle(color: HomeColors.textSecondary, fontSize: 13)),
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
                itemCount: (_isSupportChat ? _supportQuickReplies : _quickReplies).length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final item = (_isSupportChat ? _supportQuickReplies : _quickReplies)[i];
                  final isDark = ThemeModeController.instance.isDarkMode;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _onQuickReplyTap(item['text'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF26193E) : const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.4 : 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item['icon'] as IconData, color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            item['text'] as String,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF6B21A8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
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
              decoration: BoxDecoration(
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
                        color: _showQuickReplies ? const Color(0xFFA78BFA) : HomeColors.textSecondary,
                        size: 22,
                      ),
                      tooltip: 'Quick Replies',
                      onPressed: () => setState(() => _showQuickReplies = !_showQuickReplies),
                    ),
                    IconButton(
                      icon: Icon(Icons.camera_alt_outlined, color: HomeColors.textSecondary, size: 22),
                      onPressed: _sending ? null : () => _pickImage(ImageSource.camera),
                    ),
                    IconButton(
                      icon: Icon(Icons.photo_library_outlined, color: HomeColors.textSecondary, size: 22),
                      onPressed: _sending ? null : () => _pickImage(ImageSource.gallery),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: HomeColors.textSecondary, fontSize: 14),
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

Future<void> showOwnerReportCustomerDialog({
  required BuildContext context,
  required int customerId,
  required String customerName,
  int? orderId,
  bool isBlocked = false,
  ValueChanged<bool>? onBlockedChanged,
}) async {
  String selectedReason = 'harassment';
  final descriptionController = TextEditingController();
  bool alsoBlock = !isBlocked;
  bool isSubmitting = false;
  Uint8List? evidenceBytes;
  String? evidenceFilename;

  final reasons = [
    {'value': 'harassment', 'label': 'Harassment / Abusive Behavior'},
    {'value': 'fraud', 'label': 'Fraud / Scam / Non-payment'},
    {'value': 'fake_order', 'label': 'Fake / Suspicious Order'},
    {'value': 'inappropriate_content', 'label': 'Inappropriate Photos or Content'},
    {'value': 'spam', 'label': 'Spam / Unsolicited Promotion'},
    {'value': 'other', 'label': 'Other Violation'},
  ];

  Future<void> pickEvidence(ImageSource source, StateSetter setSheetState) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setSheetState(() {
          evidenceBytes = bytes;
          evidenceFilename = picked.name;
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not attach image: $e'),
            backgroundColor: HomeColors.dangerText,
          ),
        );
      }
    }
  }

  void showSourcePicker(StateSetter setSheetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: HomeColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HomeColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Attach Evidence',
                style: TextStyle(
                  color: HomeColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: Text('Take Photo', style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('Capture evidence using camera', style: TextStyle(color: HomeColors.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.of(bCtx).pop();
                  pickEvidence(ImageSource.camera, setSheetState);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.purpleAccent),
                ),
                title: Text('Choose from Gallery', style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('Pick screenshot or image file', style: TextStyle(color: HomeColors.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.of(bCtx).pop();
                  pickEvidence(ImageSource.gallery, setSheetState);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                          color: HomeColors.cardBorder,
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
                                customerName.isNotEmpty ? 'Report $customerName' : 'Report Customer',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: HomeColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Reports are investigated by Stora platform admins.',
                                style: TextStyle(fontSize: 12, color: HomeColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Reason for Report',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: HomeColors.cardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: HomeColors.cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedReason,
                          isExpanded: true,
                          dropdownColor: HomeColors.cardElevated,
                          style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
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
                    Text(
                      'Details / Description',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      enabled: !isSubmitting,
                      style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Describe what happened (e.g. offensive messages, bogus orders)...',
                        hintStyle: TextStyle(color: HomeColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: HomeColors.cardElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: HomeColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: HomeColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Attach Evidence / Screenshot (Optional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    if (evidenceBytes == null)
                      InkWell(
                        onTap: isSubmitting ? null : () => showSourcePicker(setSheetState),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: HomeColors.cardElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: HomeColors.cardBorder, style: BorderStyle.solid),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Attach photo or screenshot',
                                      style: TextStyle(color: HomeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Tap to take photo or choose from gallery',
                                      style: TextStyle(color: HomeColors.textMuted, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: HomeColors.textMuted, size: 14),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: HomeColors.cardElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                evidenceBytes!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    evidenceFilename ?? 'evidence.jpg',
                                    style: TextStyle(color: HomeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Attached',
                                          style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${(evidenceBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                                        style: TextStyle(color: HomeColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove Image',
                              icon: Icon(Icons.close_rounded, color: HomeColors.dangerText, size: 20),
                              onPressed: isSubmitting
                                  ? null
                                  : () => setSheetState(() {
                                        evidenceBytes = null;
                                        evidenceFilename = null;
                                      }),
                            ),
                          ],
                        ),
                      ),
                    if (!isBlocked) ...[
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
                              Expanded(
                                child: Text(
                                  'Also block this customer from messaging me',
                                  style: TextStyle(color: HomeColors.textPrimary, fontSize: 13),
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
                              side: BorderSide(color: HomeColors.cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
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
                                        reportedUserId: customerId,
                                        reason: selectedReason,
                                        description: descriptionController.text.trim(),
                                        orderId: orderId,
                                        attachmentBytes: evidenceBytes,
                                        filename: evidenceFilename ?? 'report_evidence.jpg',
                                      );

                                      if (alsoBlock && !isBlocked) {
                                        try {
                                          await ApiClient.instance.blockCustomer(customerId);
                                          onBlockedChanged?.call(true);
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
