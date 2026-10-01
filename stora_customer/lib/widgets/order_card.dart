import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/order_provider.dart';
import '../screens/chat/customer_chat_screen.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/navigation_guard.dart';
import 'customer_report_dialog.dart';
import 'customer_receipt_dialog.dart';
import 'notification_badge.dart';
import 'order_status_stepper.dart';

class OrderCard extends StatefulWidget {
  final CustomerOrder order;

  const OrderCard({
    super.key,
    required this.order,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> with NavigationGuard<OrderCard> {
  bool _expanded = false;

  Future<void> _showReportDialog(BuildContext context) async {
    if (widget.order.ownerId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot report this store: Store information is incomplete.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    await showCustomerReportDialog(
      context: context,
      reportedUserId: widget.order.ownerId,
      targetName: widget.order.storeName,
      orderId: widget.order.id,
    );
  }

  Future<void> _handleReorder(BuildContext context, CustomerOrder order) async {
    final messenger = ScaffoldMessenger.of(context);
    final cart = context.read<CartProvider>();

    List<ProductModel>? freshProducts;
    try {
      freshProducts = await CustomerApiService.instance.fetchProducts(storeId: order.ownerId);
    } catch (_) {
      // Graceful fallback to previous order cached pricing if offline/network error
    }

    if (!context.mounted) return;

    final result = cart.addOrderItems(order, freshProducts: freshProducts);

    if (result == -1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Replace Cart Items?',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(
            'Your cart contains items from another store. Replace them with items from "${order.storeName}"?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final added = cart.addOrderItems(order, clearExisting: true, freshProducts: freshProducts);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$added items added to cart from ${order.storeName}!'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Replace & Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$result items added to cart!'),
          backgroundColor: AppColors.success,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  Future<void> _handleCounterOfferResponse(BuildContext context, CustomerOrder order, bool accept) async {
    final actionName = accept ? 'Accept Counter-Offer' : 'Decline Counter-Offer';
    final actionDesc = accept
        ? 'Accept the store\'s new price of ₱${(order.counterPrice ?? order.totalAmount).toStringAsFixed(2)}? The store will begin preparing your order.'
        : 'Are you sure you want to decline this counter-offer? The order will be marked as declined.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          actionName,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          actionDesc,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accept ? AppColors.success : AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(accept ? 'Accept Offer' : 'Decline Offer', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final orderProvider = context.read<OrderProvider>();

    try {
      await orderProvider.respondToCounterOffer(order.id, accept: accept);
      messenger.showSnackBar(
        SnackBar(
          content: Text(accept ? 'Counter-offer accepted! Store notified.' : 'Counter-offer declined.'),
          backgroundColor: accept ? AppColors.success : AppColors.cardElevated,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showReceiptOptions(BuildContext context, CustomerOrder order) {
    CustomerReceiptDialog.show(context, order);
  }

  Future<void> _handleDeleteOrder(BuildContext context, CustomerOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Order',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete Order #${order.id}? This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final orderProvider = context.read<OrderProvider>();

    try {
      await orderProvider.deleteOrder(order.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Order #${order.id} deleted.'),
          backgroundColor: AppColors.success,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.danger,
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
  }

  Future<void> _handleCancelOrder(BuildContext context, CustomerOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Order',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to cancel Order #${order.id}? The store will be notified.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Order', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel Order', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final orderProvider = context.read<OrderProvider>();

    try {
      await orderProvider.cancelOrder(order.id);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully.'),
          backgroundColor: AppColors.success,
          duration: Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.danger,
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: order.status == 'counter_offer'
              ? AppColors.primary
              : (order.status == 'accepted'
                  ? AppColors.success.withValues(alpha: 0.5)
                  : AppColors.cardBorder),
          width: order.status == 'counter_offer' ? 1.5 : 1,
        ),
        boxShadow: order.status == 'counter_offer'
            ? AppColors.glowShadow(AppColors.primary, opacity: 0.25)
            : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Order ID, Date & Status Chip
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (order.formattedDate.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            order.formattedDate,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (order.status == 'accepted' || order.status == 'ready' || order.status == 'completed') ...[
                      Tooltip(
                        message: 'View Receipt',
                        child: InkWell(
                          onTap: () => _showReceiptOptions(context, order),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.successBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.successText,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: order.statusBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: order.statusColor, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(order.statusIcon, size: 14, color: order.statusColor),
                          const SizedBox(width: 4),
                          Text(
                            order.statusDisplay,
                            style: TextStyle(
                              color: order.statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.cardBorder),

          // Order Progress Stepper
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: OrderStatusStepper(order: order),
          ),

          // Counter Offer Box (if applicable)
          if (order.status == 'counter_offer') ...[
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_offer, color: AppColors.primary, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Store Counter-Offer Notice',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (order.counterPrice != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Proposed Price: ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        Text(
                          order.formattedCounterPrice,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (order.counterNotes != null && order.counterNotes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Store Note: "${order.counterNotes}"',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Decline Reason Box (if applicable)
          if ((order.status == 'declined' || order.status == 'auto_declined') &&
              order.declineReason != null &&
              order.declineReason!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${order.declineReason}',
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Delivery info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.customerAddress.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.customerAddress,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                if (order.customerPhone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          order.customerPhone,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                if (order.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note_alt_outlined, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Note: ${order.notes}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        order.isOnlinePayment ? Icons.account_balance_wallet_rounded : Icons.payments_outlined,
                        size: 15,
                        color: order.isOnlinePayment ? const Color(0xFF60A5FA) : const Color(0xFF34D399),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Payment: ',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      Expanded(
                        child: Text(
                          order.isOnlinePayment
                              ? (order.status == 'pending'
                                  ? 'Online Payment (Pay after store acceptance)'
                                  : 'Online Payment')
                              : 'Cash on Pickup / In-Store',
                          style: TextStyle(
                            color: order.isOnlinePayment ? const Color(0xFF93C5FD) : const Color(0xFF6EE7B7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items summary & toggle
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.totalQuantity} ${order.totalQuantity == 1 ? "item" : "items"}${order.items.length > 1 && order.totalQuantity != order.items.length ? " (${order.items.length} products)" : ""}',
                    style: TextStyle(
                      color: AppColors.accentText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _expanded ? 'Hide Items' : 'View Items',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Items List
          if (_expanded) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: AppColors.cardElevated.withValues(alpha: 0.5),
              child: Column(
                children: order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x  ${item.productName}',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          item.formattedSubtotal,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          Divider(height: 1, color: AppColors.cardBorder),

          // Footer: Total Amount
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  order.formattedTotal,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Counter Offer Action Buttons
          if (order.status == 'counter_offer') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleCounterOfferResponse(context, order, true),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text(
                        'Accept Offer${order.counterPrice != null ? " (₱${order.counterPrice!.toStringAsFixed(2)})" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleCounterOfferResponse(context, order, false),
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                      label: const Text(
                        'Decline',
                        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => guardedNavigate(() async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerChatScreen(
                            storeOwnerId: order.ownerId,
                            storeName: order.storeName.isNotEmpty ? order.storeName : 'Store Owner',
                            storeAvatarUrl: order.storeAvatarUrl,
                            initialOrderId: order.id,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        context.read<OrderProvider>().refresh(isSilent: true);
                        context.read<ChatProvider>().fetchConversations(isSilent: true);
                      }
                    }),
                    icon: AppNotificationBadge(
                      count: order.unreadMessageCount,
                      top: -4,
                      right: -6,
                      minSize: 14,
                      child: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.accentText),
                    ),
                    label: Text(
                      order.unreadMessageCount > 0
                          ? 'Chat (${order.unreadMessageCount})'
                          : 'Chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.accentText, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.6), width: 1.2),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (order.status == 'completed') ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _handleReorder(context, order),
                      icon: const Icon(Icons.repeat_rounded, size: 16),
                      label: const Text(
                        'Reorder',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, letterSpacing: 0.2),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                if (order.status == 'pending' || order.status == 'counter_offer')
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      tooltip: 'Cancel Order',
                      onPressed: () => _handleCancelOrder(context, order),
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                        padding: const EdgeInsets.all(10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ),
                if (order.status == 'completed' || order.status == 'declined' || order.status == 'auto_declined')
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      tooltip: 'Delete Order',
                      onPressed: () => _handleDeleteOrder(context, order),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                        padding: const EdgeInsets.all(10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Report Store',
                  onPressed: () => _showReportDialog(context),
                  icon: const Icon(Icons.flag_outlined, color: Colors.amber, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.amber.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
