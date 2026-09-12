import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/chat_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class CustomerChatScreen extends StatefulWidget {
  final int storeOwnerId;
  final String storeName;
  final String? storeAvatarUrl;
  final int? initialOrderId;
  final bool isSupport;

  const CustomerChatScreen({
    super.key,
    required this.storeOwnerId,
    required this.storeName,
    this.storeAvatarUrl,
    this.initialOrderId,
    this.isSupport = false,
  });

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
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

  static const List<Map<String, dynamic>> _customerQuickReplies = [
    {'icon': Icons.inventory_2_outlined, 'text': 'Is this item in stock and available?'},
    {'icon': Icons.schedule_rounded, 'text': 'What are your store hours today?'},
    {'icon': Icons.delivery_dining_outlined, 'text': 'Can this be delivered today?'},
    {'icon': Icons.location_on_outlined, 'text': 'Where is your physical store located?'},
    {'icon': Icons.local_offer_outlined, 'text': 'Do you offer bulk discounts?'},
  ];

  static const List<Map<String, dynamic>> _supportQuickReplies = [
    {'icon': Icons.help_outline_rounded, 'text': 'I need help with an order.'},
    {'icon': Icons.delivery_dining_outlined, 'text': 'Where is my delivery right now?'},
    {'icon': Icons.payment_rounded, 'text': 'I have a question about payment or refunds.'},
    {'icon': Icons.report_problem_outlined, 'text': 'I encountered an issue with a store.'},
    {'icon': Icons.chat_bubble_outline_rounded, 'text': 'Can I speak with a customer representative?'},
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
    try {
      context.read<ChatProvider>().fetchConversations(isSilent: true);
      context.read<OrderProvider>().refresh(isSilent: true);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _fetchBlockStatus() async {
    if (widget.isSupport) return;
    try {
      final blocked = await CustomerApiService.instance.checkBlockStatus(widget.storeOwnerId);
      if (mounted) setState(() => _isBlocked = blocked);
    } catch (_) {}
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final msgs = await CustomerApiService.instance.fetchMessages(widget.storeOwnerId);
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
      backgroundColor: AppColors.cardElevated,
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
                  subtitle: const Text('Copy message text to clipboard', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                        backgroundColor: AppColors.cardBackground,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              if (msgId != null)
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.dangerBg,
                    child: Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                  ),
                  title: Text(isMe ? 'Unsend Message' : 'Delete Message',
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Text(
                    isMe ? 'Remove message for everyone' : 'Delete this message from chat',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: AppColors.cardBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
                            const SizedBox(width: 10),
                            Text(isMe ? 'Unsend Message?' : 'Delete Message?',
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        content: Text(
                          isMe
                              ? 'This message will be removed for both you and the store.'
                              : 'Are you sure you want to delete this message?',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dCtx).pop(false),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
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
                        await CustomerApiService.instance.deleteMessage(msgId);
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
                              backgroundColor: AppColors.cardElevated,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete message: $e'),
                              backgroundColor: AppColors.danger,
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
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: AppColors.danger),
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
      await CustomerApiService.instance.sendChatMessage(
        recipientId: widget.storeOwnerId,
        message: text.isNotEmpty ? text : null,
        imageBytes: _selectedImageBytes,
        filename: _selectedImageName ?? 'customer_photo.jpg',
        orderId: widget.initialOrderId,
      );

      _textController.clear();
      setState(() {
        _selectedImageBytes = null;
        _selectedImageName = null;
      });

      await _fetchMessages(silent: true);
    } on ApiException catch (e) {
      if (e.statusCode == 403 || e.message.toLowerCase().contains('blocked') || e.message.toLowerCase().contains('cannot send')) {
        setState(() => _isBlocked = true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e'), backgroundColor: AppColors.danger),
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
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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

  Future<void> _showReportDialog() async {
    String selectedReason = 'fraud';
    final descriptionController = TextEditingController();
    bool isSubmitting = false;

    final reasons = [
      {'value': 'fraud', 'label': 'Fraud, Scam, or Undelivered Items'},
      {'value': 'harassment', 'label': 'Harassment / Abusive Behavior'},
      {'value': 'inappropriate_content', 'label': 'Inappropriate Photos or Content'},
      {'value': 'fake_order', 'label': 'Misleading Pricing or Order Issues'},
      {'value': 'spam', 'label': 'Spam / Unsolicited Ads'},
      {'value': 'other', 'label': 'Other Violation'},
    ];

    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.cardBackground,
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
                            color: AppColors.cardBorder,
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
                            child: const Icon(Icons.flag_rounded, color: Colors.amber, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Report ${widget.storeName}',
                                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Reports are sent to platform administrators for investigation.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Violation Reason',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedReason,
                            dropdownColor: AppColors.cardElevated,
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                            items: reasons.map((r) {
                              return DropdownMenuItem<String>(
                                value: r['value'],
                                child: Text(r['label']!),
                              );
                            }).toList(),
                            onChanged: isSubmitting
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setSheetState(() => selectedReason = val);
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Explanation / Details (Optional)',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        enabled: !isSubmitting,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Describe what happened in detail for the platform admin...',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.cardElevated,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.cardBorder),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      setSheetState(() => isSubmitting = true);
                                      try {
                                        await CustomerApiService.instance.submitReport(
                                          reportedUserId: widget.storeOwnerId,
                                          reason: selectedReason,
                                          description: descriptionController.text.trim(),
                                          orderId: widget.initialOrderId,
                                        );

                                        if (ctx.mounted) Navigator.of(ctx).pop();

                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Report submitted. Our administrators will review this store.'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      } catch (e) {
                                        if (ctx.mounted) setSheetState(() => isSubmitting = false);
                                        final eStr = e.toString().toLowerCase();
                                        final msg = eStr.contains('pending report') || eStr.contains('already have')
                                            ? 'You already have an active pending report for this store.'
                                            : 'Failed to submit report: $e';
                                        messenger.showSnackBar(
                                          SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
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

  Future<void> _deleteConversation() async {
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
          'Are you sure you want to delete all messages with ${widget.storeName}? This cannot be undone.',
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
        await CustomerApiService.instance.deleteConversation(widget.storeOwnerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversation with ${widget.storeName} deleted', style: const TextStyle(color: Colors.white)),
              backgroundColor: AppColors.cardElevated,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete conversation: $e'),
              backgroundColor: AppColors.danger,
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
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            if (widget.isSupport)
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 22),
              )
            else
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.cardElevated,
                backgroundImage: (widget.storeAvatarUrl != null && widget.storeAvatarUrl!.isNotEmpty)
                    ? NetworkImage(widget.storeAvatarUrl!)
                    : null,
                child: (widget.storeAvatarUrl == null || widget.storeAvatarUrl!.isEmpty)
                    ? const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20)
                    : null,
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
                          widget.isSupport ? 'STORA Support' : widget.storeName,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isSupport) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: AppColors.secondaryLight, size: 16),
                      ],
                    ],
                  ),
                  Text(
                    widget.isSupport
                        ? 'Official Support · Online'
                        : (_isBlocked ? 'Blocked by store' : 'Store Owner'),
                    style: TextStyle(
                      color: widget.isSupport
                          ? AppColors.secondaryLight
                          : (_isBlocked ? AppColors.danger : AppColors.secondaryLight),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            color: AppColors.cardElevated,
            onSelected: (val) {
              if (val == 'report') _showReportDialog();
              if (val == 'delete') _deleteConversation();
            },
            itemBuilder: (ctx) => [
              if (!widget.isSupport)
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
                        'Report Store',
                        style: TextStyle(color: Colors.amber),
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
                      color: AppColors.danger,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Delete Conversation',
                      style: TextStyle(color: AppColors.danger),
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
          if (widget.initialOrderId != null && _showOrderBanner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.cardElevated,
                border: const Border(
                  left: BorderSide(color: Color(0xFF10B981), width: 3.5),
                  bottom: BorderSide(color: Colors.white10, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Color(0xFF34D399), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Order #${widget.initialOrderId}',
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
              color: AppColors.dangerBg,
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, color: AppColors.danger, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'You have been blocked by this store owner. You cannot send messages.',
                      style: TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null && _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => _fetchMessages(),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
                                  backgroundColor: AppColors.cardElevated,
                                  backgroundImage: (widget.storeAvatarUrl != null && widget.storeAvatarUrl!.isNotEmpty)
                                      ? NetworkImage(widget.storeAvatarUrl!)
                                      : null,
                                  child: (widget.storeAvatarUrl == null || widget.storeAvatarUrl!.isEmpty)
                                      ? const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 44)
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                Text('Message ${widget.storeName}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('Ask questions about products, orders, or delivery', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isMe = msg['sender_role'] == 'customer';
                              final text = msg['message'] as String? ?? '';
                              final rawImg = msg['image'] as String?;
                              final orderId = msg['order'] as int?;
                              final createdAt = msg['created_at'] as String?;

                              String timeDisplay = '';
                              if (createdAt != null) {
                                try {
                                  final dt = DateTime.parse(createdAt).toLocal();
                                  timeDisplay = DateFormat('h:mm a').format(dt);
                                } catch (_) {}
                              }

                              final isUnsent = msg['is_unsent'] == true;

                              if (isUnsent) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    children: [
                                      if (!isMe) ...[
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppColors.cardElevated,
                                          backgroundImage: (widget.storeAvatarUrl != null && widget.storeAvatarUrl!.isNotEmpty)
                                              ? NetworkImage(widget.storeAvatarUrl!)
                                              : null,
                                          child: (widget.storeAvatarUrl == null || widget.storeAvatarUrl!.isEmpty)
                                              ? const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 14)
                                              : null,
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
                                            const Icon(Icons.undo_rounded, size: 14, color: AppColors.textMuted),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                isMe ? 'You unsent a message' : '${widget.storeName} unsent a message',
                                                style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 13,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                            if (timeDisplay.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                timeDisplay,
                                                style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 9.5,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
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
                                        backgroundColor: AppColors.cardElevated,
                                        backgroundImage: (widget.storeAvatarUrl != null && widget.storeAvatarUrl!.isNotEmpty)
                                            ? NetworkImage(widget.storeAvatarUrl!)
                                            : null,
                                        child: (widget.storeAvatarUrl == null || widget.storeAvatarUrl!.isEmpty)
                                            ? const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 14)
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
                                            gradient: isMe ? AppColors.purpleGradient : null,
                                            color: isMe ? null : AppColors.cardElevated,
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
                                                      errorBuilder: (_, error, stackTrace) => Container(
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
                                                      color: isMe ? Colors.white70 : AppColors.textSecondary,
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
              color: AppColors.cardBackground,
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
              color: AppColors.cardBackground,
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: widget.isSupport ? _supportQuickReplies.length : _customerQuickReplies.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final item = widget.isSupport ? _supportQuickReplies[i] : _customerQuickReplies[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _onQuickReplyTap(item['text'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item['icon'] as IconData, color: AppColors.primaryLight, size: 14),
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
                color: AppColors.cardBackground,
                border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        _showQuickReplies ? Icons.bolt_rounded : Icons.bolt_outlined,
                        color: _showQuickReplies ? AppColors.primaryLight : AppColors.textSecondary,
                        size: 22,
                      ),
                      tooltip: 'Quick Questions',
                      onPressed: () => setState(() => _showQuickReplies = !_showQuickReplies),
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary, size: 22),
                      onPressed: _sending ? null : () => _pickImage(ImageSource.camera),
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined, color: AppColors.textSecondary, size: 22),
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
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                          filled: true,
                          fillColor: AppColors.cardElevated,
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
                        gradient: AppColors.purpleGradient,
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
