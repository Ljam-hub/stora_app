import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../auth/auth_store.dart';
import '../models/sale.dart';
import '../services/receipt_service.dart';
import '../theme/home_colors.dart';

class ReceiptDialog extends StatefulWidget {
  final Sale sale;

  const ReceiptDialog({super.key, required this.sale});

  static Future<void> show(BuildContext context, Sale sale) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceiptDialog(sale: sale),
    );
  }

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final businessName = AuthStore.instance.businessName ?? 'Stora Store';
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final formattedDate = dateFormat.format(sale.date);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Receipt Paper Styling
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top check icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      businessName.toUpperCase(),
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
                      style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Receipt #: ${sale.id}', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                        Text(formattedDate, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                      ],
                    ),
                    const Divider(color: Colors.black26, thickness: 1, height: 24),

                    // Items
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sale.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = sale.items[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.quantity}x', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12)),
                                  Text('@ ₱${item.product.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black45, fontSize: 10)),
                                ],
                              ),
                            ),
                            Text('₱${(item.product.price * item.quantity).toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 12)),
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
                        Text('${sale.items.fold<int>(0, (sum, i) => sum + i.quantity)}',
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Paid', style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('₱${sale.total.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Thank you for shopping with us!',
                        style: TextStyle(color: Colors.black45, fontSize: 11, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: HomeColors.cardBorder),
                        backgroundColor: HomeColors.cardBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              try {
                                await ReceiptService.instance.shareReceipt(sale, businessName: businessName);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sharing error: $e')));
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
                        backgroundColor: const Color(0xFF9B87F5),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              try {
                                await ReceiptService.instance.printReceipt(sale, businessName: businessName);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print error: $e')));
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
                child: const Text('Done / Close', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
