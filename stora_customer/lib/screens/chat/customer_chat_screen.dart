import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class CustomerChatScreen extends StatefulWidget {
  final int storeOwnerId;
  final String storeName;
  final String? storeAvatarUrl;
  final int? initialOrderId;

  const CustomerChatScreen({
    super.key,
    required this.storeOwnerId,
    required this.storeName,
    this.storeAvatarUrl,
    this.initialOrderId,
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
  String? _error;
  Timer? _pollTimer;

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

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
                  Text(
                    widget.storeName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isBlocked ? 'Blocked by store' : 'Store Owner',
                    style: TextStyle(
                      color: _isBlocked ? AppColors.danger : AppColors.secondaryLight,
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
                      'Report Store',
                      style: TextStyle(color: Colors.amber),
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
          if (widget.initialOrderId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.cardElevated,
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppColors.primaryLight, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Inquiring regarding Order #${widget.initialOrderId}',
                    style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
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
                                            Text(
                                              timeDisplay,
                                              style: TextStyle(
                                                color: isMe ? Colors.white70 : AppColors.textSecondary,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
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
