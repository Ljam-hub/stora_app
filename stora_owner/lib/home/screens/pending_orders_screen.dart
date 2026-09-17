import 'package:flutter/material.dart';
import '../../data/api/api_config.dart';
import '../../data/services/notification_service.dart';
import '../../stora_login/theme/app_colors.dart';
import '../stores/orders_store.dart';
import '../theme/home_colors.dart';
import '../theme/theme_mode_controller.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../utils/date_utils.dart';
import '../widgets/customer_location_map_sheet.dart';
import '../widgets/notification_badge.dart';
import '../widgets/receipt_dialog.dart';
import 'owner_chat_screen.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  String _filter = 'pending'; // 'pending', 'all'

  @override
  void initState() {
    super.initState();
    OrdersStore.instance.fetchOrders();
    OwnerNotificationService.instance.cancelAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        backgroundColor: HomeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: HomeColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Customer Orders',
          style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([OrdersStore.instance, ThemeModeController.instance]),
        builder: (context, _) {
          final store = OrdersStore.instance;

          if (store.isLoading && store.orders.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.purpleLight),
            );
          }

          if (store.error != null && store.orders.isEmpty) {
            return RefreshIndicator(
              color: AppColors.purpleLight,
              backgroundColor: HomeColors.cardBackground,
              onRefresh: () => store.fetchOrders(),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded, color: HomeColors.dangerText, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              store.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.label, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.purpleLight,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => store.fetchOrders(),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          final allOrders = store.orders;
          final displayedOrders = _filter == 'pending'
              ? allOrders.where((o) => o['status'] == 'pending' || o['status'] == 'counter_offer' || o['status'] == 'accepted' || o['status'] == 'ready').toList()
              : allOrders;

          return RefreshIndicator(
            color: AppColors.purpleLight,
            backgroundColor: HomeColors.cardBackground,
            onRefresh: () => store.fetchOrders(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Filter chips
                Row(
                  children: [
                    _FilterChip(
                      label: 'Active / Pending',
                      badgeCount: store.activeCount,
                      isSelected: _filter == 'pending',
                      onTap: () => setState(() => _filter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'All Orders (${allOrders.length})',
                      isSelected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (displayedOrders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: HomeColors.cardElevated,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.label,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filter == 'pending' ? 'No active orders' : 'No orders found',
                            style: TextStyle(
                              color: HomeColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Incoming customer carts will appear here.',
                            style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...displayedOrders.map((order) => _OrderCard(order: order)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.purpleLight : HomeColors.cardElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.purpleLight : HomeColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : HomeColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              AppNotificationBadge(
                count: badgeCount,
                minSize: 17,
                borderColor: isSelected ? AppColors.purpleLight : HomeColors.cardElevated,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;

  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isExpanded = true;
  bool _isProcessing = false;

  int get orderId => (widget.order['id'] as num?)?.toInt() ?? int.tryParse(widget.order['id']?.toString() ?? '') ?? 0;
  String get status => (widget.order['status'] as String?) ?? 'pending';
  String get customerName => (widget.order['customer_name'] as String?) ?? 'Customer';
  String get customerEmail => (widget.order['customer_email'] as String?) ?? (widget.order['email'] as String?) ?? '';
  String? get customerAvatarUrl => ApiConfig.resolveMediaUrl(widget.order['customer_avatar_url'] as String?);
  int? get customerId {
    final val = widget.order['customer'] ?? widget.order['customer_id'];
    if (val is int) return val;
    if (val is Map) return val['id'] as int?;
    if (val is String) return int.tryParse(val);
    return null;
  }
  String get customerPhone => (widget.order['customer_phone'] as String?) ?? '';
  String get customerAddress => (widget.order['customer_address'] as String?) ?? '';
  String get notes => (widget.order['notes'] as String?) ?? '';
  String get totalAmount {
    if ((status == 'accepted' || status == 'ready') && widget.order['counter_price'] != null) {
      final cp = double.tryParse(widget.order['counter_price'].toString());
      if (cp != null && cp > 0) return cp.toStringAsFixed(2);
    }
    return widget.order['total_amount']?.toString() ?? '0.00';
  }
  List get items => (widget.order['items'] as List?) ?? [];
  int get totalQuantity => items.fold<int>(
      0, (sum, i) => sum + ((i is Map ? (i['quantity'] as num?)?.toInt() : null) ?? 1));

  Sale _createSaleFromOrder() {
    final rawDate = widget.order['created_at']?.toString();
    DateTime parsedDate;
    try {
      parsedDate = rawDate != null ? parseApiDateTime(rawDate) : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }
    final orderItems = items.whereType<Map>().map((it) {
      final price = double.tryParse(it['unit_price']?.toString() ?? '0') ?? 0.0;
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
      return CartItem(
        product: Product(
          id: it['product']?.toString() ?? '',
          name: it['product_name']?.toString() ?? 'Item',
          category: '',
          price: price,
          stock: 0,
        ),
        quantity: qty,
      );
    }).toList();

    final rNum = (widget.order['receipt_number'] as String?)?.trim();
    final receiptNum = (rNum != null && rNum.isNotEmpty) ? rNum : 'ORD-$orderId';

    return Sale(
      id: orderId.toString(),
      date: parsedDate,
      items: orderItems,
      total: double.tryParse(totalAmount) ?? 0.0,
      customerName: customerName,
      receiptNumber: receiptNum,
      orderId: orderId,
      channel: 'online_order',
    );
  }

  Color get _statusColor {
    switch (status) {
      case 'ready':
        return const Color(0xFF00E676);
      case 'accepted':
        return HomeColors.successText;
      case 'declined':
      case 'auto_declined':
        return HomeColors.dangerText;
      case 'counter_offer':
        return const Color(0xFFFFA726);
      default:
        return AppColors.purpleLight;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'ready':
        return 'READY FOR PICKUP';
      case 'accepted':
        return 'ACCEPTED (PREPARING)';
      case 'declined':
        return 'DECLINED';
      case 'auto_declined':
        return 'EXPIRED';
      case 'counter_offer':
        return 'COUNTERED';
      default:
        return 'PENDING REVIEW';
    }
  }

  void _showFeedback(
    String message, {
    bool isSuccess = true,
    bool isWarning = false,
    IconData? icon,
  }) {
    if (!mounted) return;
    final primaryColor = isSuccess
        ? const Color(0xFF00E676)
        : (isWarning ? const Color(0xFFFFA726) : const Color(0xFFEF4444));
    final bgColor = isSuccess
        ? const Color(0xFF13251C)
        : (isWarning ? const Color(0xFF2B1F10) : const Color(0xFF2C1318));
    final borderColor = isSuccess
        ? const Color(0xFF00E676).withValues(alpha: 0.4)
        : (isWarning ? const Color(0xFFFFA726).withValues(alpha: 0.4) : const Color(0xFFEF4444).withValues(alpha: 0.4));

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        backgroundColor: bgColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? (isSuccess ? Icons.check_circle_rounded : (isWarning ? Icons.info_outline_rounded : Icons.error_outline_rounded)),
                color: primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await OrdersStore.instance.acceptOrder(orderId);
      if (mounted) {
        _showFeedback(
          'Order #$orderId accepted! Stock deducted and recorded in sales.',
          isSuccess: true,
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        _showFeedback('Failed to accept order: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleMarkReady() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await OrdersStore.instance.markOrderReady(orderId);
      if (mounted) {
        _showFeedback(
          'Order #$orderId marked as ready! Customer notified for pickup.',
          isSuccess: true,
          icon: Icons.storefront_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        _showFeedback('Failed to mark order as ready: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showDeclineDialog() {
    final controller = TextEditingController();
    String selectedReason = 'Out of stock';
    final standardReasons = ['Out of stock', 'Store closed', 'Outside delivery area', 'Custom reason'];
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: HomeColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Decline Order', style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select reason for customer:', style: TextStyle(color: HomeColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 10),
              RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedReason = val);
                },
                child: Column(
                  children: standardReasons.map((r) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.purpleLight,
                    title: Text(r, style: TextStyle(color: HomeColors.textPrimary, fontSize: 14)),
                    value: r,
                  )).toList(),
                ),
              ),
              if (selectedReason == 'Custom reason') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter reason...',
                    hintStyle: TextStyle(color: HomeColors.textSecondary),
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeColors.dangerText,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (isSubmitting) return;
                isSubmitting = true;
                final reason = selectedReason == 'Custom reason' ? controller.text.trim() : selectedReason;
                Navigator.of(ctx).pop();
                setState(() => _isProcessing = true);
                try {
                  await OrdersStore.instance.declineOrder(orderId, reason: reason);
                  if (mounted) {
                    _showFeedback(
                      'Order #$orderId declined.',
                      isSuccess: false,
                      isWarning: true,
                      icon: Icons.cancel_outlined,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    _showFeedback('Failed to decline order: $e', isSuccess: false);
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
              child: const Text('Decline Order'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCounterDialog() {
    final notesController = TextEditingController();
    final priceController = TextEditingController(text: totalAmount);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Propose Counter-Offer', style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Suggest modifications or adjusted pricing to the customer:',
              style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Notes for Customer *',
                labelStyle: TextStyle(color: HomeColors.textSecondary),
                hintText: 'e.g. Medium size substituted, ₱20 discount',
                hintStyle: TextStyle(color: HomeColors.textSecondary),
                filled: true,
                fillColor: HomeColors.cardElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Adjusted Total (₱)',
                labelStyle: TextStyle(color: HomeColors.textSecondary),
                filled: true,
                fillColor: HomeColors.cardElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA726),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (isSubmitting) return;
              final notes = notesController.text.trim();
              if (notes.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter notes explaining the counter-offer.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              final priceText = priceController.text.trim();
              final price = priceText.isNotEmpty ? double.tryParse(priceText) : null;
              if (price != null && price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Adjusted total must be greater than zero.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              isSubmitting = true;
              Navigator.of(ctx).pop();
              setState(() => _isProcessing = true);
              try {
                await OrdersStore.instance.counterOrder(
                  orderId,
                  notes: notes,
                  counterPrice: price,
                );
                if (mounted) {
                  _showFeedback(
                    'Counter-offer sent for Order #$orderId.',
                    isSuccess: true,
                    icon: Icons.handshake_outlined,
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showFeedback('Failed to send counter-offer: $e', isSuccess: false);
                }
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text('Send Counter', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending' || status == 'counter_offer';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending ? AppColors.purpleLight.withValues(alpha: 0.35) : HomeColors.cardBorder,
        ),
        boxShadow: isPending ? HomeColors.glowShadow(AppColors.purpleLight) : HomeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Avatar & Details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Avatar Circle
                CircleAvatar(
                  radius: 21,
                  backgroundColor: const Color(0xFF3A3B3C),
                  backgroundImage: (customerAvatarUrl != null && customerAvatarUrl!.isNotEmpty)
                      ? NetworkImage(customerAvatarUrl!)
                      : null,
                  child: (customerAvatarUrl == null || customerAvatarUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 24)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 3,
                        children: [
                          Text(
                            'Order #$orderId',
                            style: TextStyle(
                              color: HomeColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _statusColor.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              _statusLabel,
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customerName,
                        style: TextStyle(
                          color: HomeColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱$totalAmount',
                      style: TextStyle(
                        color: HomeColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (customerId != null) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OwnerChatThreadScreen(
                                customerId: customerId!,
                                customerName: customerName,
                                customerEmail: customerEmail,
                                customerAvatarUrl: customerAvatarUrl,
                                orderId: orderId,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.purpleLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.purpleLight.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, color: AppColors.purpleLight, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Chat',
                                style: TextStyle(
                                  color: AppColors.purpleLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Contact Details & Message Customer Option
          if (customerEmail.isNotEmpty || customerPhone.isNotEmpty || customerAddress.isNotEmpty || notes.isNotEmpty || customerId != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HomeColors.cardElevated.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HomeColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customerEmail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: AppColors.purpleLight, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customerEmail,
                              style: const TextStyle(color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (customerPhone.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, color: AppColors.purpleLight, size: 14),
                        const SizedBox(width: 8),
                        Text(customerPhone, style: const TextStyle(color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  if (customerAddress.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.purpleLight, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(customerAddress, style: const TextStyle(color: AppColors.label, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => CustomerLocationMapSheet.show(
                            context,
                            orderId: orderId,
                            customerName: customerName,
                            customerAddress: customerAddress,
                            customerPhone: customerPhone,
                            customerId: customerId,
                            customerEmail: customerEmail,
                            customerAvatarUrl: customerAvatarUrl,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: HomeColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: HomeColors.primary.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map_rounded, color: HomeColors.primary, size: 13),
                                SizedBox(width: 4),
                                Text(
                                  'View Map',
                                  style: TextStyle(
                                    color: HomeColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded, color: Color(0xFFFFA726), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Note: "$notes"', style: TextStyle(color: HomeColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ),
                  ],
                  if (customerId != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OwnerChatThreadScreen(
                              customerId: customerId!,
                              customerName: customerName,
                              customerEmail: customerEmail,
                              customerAvatarUrl: customerAvatarUrl,
                              orderId: orderId,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.purpleLight.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.purpleLight.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, color: AppColors.purpleLight, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Message customer about this order',
                              style: TextStyle(
                                color: AppColors.purpleLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Items Divider & Toggle
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: HomeColors.surfaceHover,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$totalQuantity ${totalQuantity == 1 ? 'item' : 'items'}${items.length > 1 && totalQuantity != items.length ? ' (${items.length} products)' : ''}',
                      style: const TextStyle(color: AppColors.label, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.label,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Items List
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: items.whereType<Map>().map<Widget>((item) {
                  final name = item['product_name'] ?? 'Item';
                  final qty = item['quantity'] ?? 1;
                  final price = item['unit_price'] ?? '0.00';
                  final subtotal = item['subtotal'] ?? '0.00';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.purpleLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${qty}x',
                            style: const TextStyle(color: AppColors.purpleLight, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(color: HomeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '₱$price each',
                                style: const TextStyle(color: AppColors.label, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱$subtotal',
                          style: TextStyle(color: HomeColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 14),

          // Action Buttons for Pending Orders
          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _isProcessing
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(color: AppColors.purpleLight),
                      ),
                    )
                  : Row(
                      children: [
                        // Decline
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HomeColors.dangerText,
                              side: BorderSide(color: HomeColors.dangerText.withValues(alpha: 0.6)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: _showDeclineDialog,
                            child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Counter
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFA726),
                              side: BorderSide(color: const Color(0xFFFFA726).withValues(alpha: 0.6)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            onPressed: _showCounterDialog,
                            child: const Text('Counter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Accept
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HomeColors.successText,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                            ),
                            onPressed: _handleAccept,
                            child: const Text('Accept Order', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
            ),

          // Action Button for Accepted Orders (Mark as Ready & Receipt)
          if (status == 'accepted')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _isProcessing
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(color: AppColors.purpleLight),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2E7D32),
                              side: const BorderSide(color: Color(0xFF81C784)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => ReceiptDialog.show(context, _createSaleFromOrder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.done_all_rounded, size: 18),
                            label: const Text(
                              'Mark as Ready',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                            ),
                            onPressed: _handleMarkReady,
                          ),
                        ),
                      ],
                    ),
            ),

          // Action Button for Ready Orders (View / Print Receipt)
          if (status == 'ready')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text(
                    'View / Print Order Receipt',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFF81C784)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => ReceiptDialog.show(context, _createSaleFromOrder()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
