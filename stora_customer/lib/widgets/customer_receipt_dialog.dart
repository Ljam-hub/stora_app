import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/receipt_service.dart';
import '../theme/app_theme.dart';

class CustomerReceiptDialog extends StatefulWidget {
  final CustomerOrder order;

  const CustomerReceiptDialog({super.key, required this.order});

  static bool _isShowing = false;

  static Future<void> show(BuildContext context, CustomerOrder order) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CustomerReceiptDialog(order: order),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<CustomerReceiptDialog> createState() => _CustomerReceiptDialogState();
}

class _CustomerReceiptDialogState extends State<CustomerReceiptDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final storeName = order.storeName.trim().isNotEmpty ? order.storeName.trim() : 'STORA STORE';
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final formattedDate = dateFormat.format(order.createdAt?.toLocal() ?? DateTime.now());

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Receipt Paper Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top check circle
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2E7D32),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      storeName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'OFFICIAL RECEIPT',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Receipt #: ${order.receiptNumber}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: const TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #: #${order.id}',
                          style: const TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Online Order',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Customer: ${order.customerDisplayName}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order.statusDisplay,
                            style: const TextStyle(
                              color: Color(0xFF0369A1),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.black26, thickness: 1, height: 20),

                    // Items List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = order.items[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.quantity}x',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '@ ₱${item.unitPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.black45,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₱${item.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const Divider(color: Colors.black26, thickness: 1, height: 24),

                    // Totals
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Items', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        Text(
                          '${order.totalQuantity}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (order.counterPrice != null && order.counterPrice! > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(color: Colors.black54, fontSize: 12)),
                          Text(
                            '₱${order.items.fold<double>(0, (sum, i) => sum + i.subtotal).toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Special Offer Price',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₱${order.counterPrice!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '₱${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thank you for shopping with us!',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons: Share & Print
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: AppColors.cardBorder),
                        backgroundColor: AppColors.cardBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              try {
                                await CustomerReceiptService.instance.shareReceipt(order);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Sharing error: $e'),
                                      duration: const Duration(milliseconds: 1500),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isProcessing = false);
                              }
                            },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              try {
                                await CustomerReceiptService.instance.printReceipt(order);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Print error: $e'),
                                      duration: const Duration(milliseconds: 1500),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isProcessing = false);
                              }
                            },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Done / Close',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
