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
import '../services/receipt_service.dart';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Receipt #${order.receiptNumber}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Order #${order.id} • ${order.customerDisplayName}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await CustomerReceiptService.instance.shareReceipt(order);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Share error: $e'), backgroundColor: AppColors.danger),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await CustomerReceiptService.instance.printReceipt(order);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Print error: $e'), backgroundColor: AppColors.danger),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
                Column(
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
                          ? 'Message (${order.unreadMessageCount})'
                          : 'Message Store',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.accentText, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (order.status == 'completed') ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _handleReorder(context, order),
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text('Reorder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
                if (order.status == 'accepted' || order.status == 'ready' || order.status == 'completed') ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'View Receipt',
                    onPressed: () {
                      _showReceiptOptions(context, order);
                    },
                    icon: const Icon(Icons.receipt_long_rounded, color: AppColors.success, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.successBg,
                      padding: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
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
