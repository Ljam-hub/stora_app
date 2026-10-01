import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../auth/auth_store.dart';
import '../services/receipt_service.dart';
import '../stores/utang_store.dart';
import '../theme/home_colors.dart';
import '../utils/date_utils.dart';

class UtangPaymentReceiptDialog extends StatefulWidget {
  final UtangRecord record;
  final UtangPayment payment;
  final double previousBalance;

  const UtangPaymentReceiptDialog({
    super.key,
    required this.record,
    required this.payment,
    required this.previousBalance,
  });

  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context, {
    required UtangRecord record,
    required UtangPayment payment,
    required double previousBalance,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UtangPaymentReceiptDialog(
          record: record,
          payment: payment,
          previousBalance: previousBalance,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<UtangPaymentReceiptDialog> createState() => _UtangPaymentReceiptDialogState();
}

class _UtangPaymentReceiptDialogState extends State<UtangPaymentReceiptDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final payment = widget.payment;
    final previousBalance = widget.previousBalance;
    final remainingDue = record.penaltyAmount > 0 ? record.totalDueWithPenalty : record.balance;
    final isFullyPaid = record.isFullyPaid || remainingDue <= 0.01;

    final bName = AuthStore.instance.businessName?.trim();
    final businessName = (bName != null && bName.isNotEmpty) ? bName : 'Stora Store';
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final formattedDate = dateFormat.format(toManila(payment.paidAt));
    final receiptNum = 'PAY-${payment.id.replaceFirst('pay-', '')}';

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
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 30),
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
                      'OFFICIAL PAYMENT RECEIPT',
                      style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Receipt #: $receiptNum',
                            style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(formattedDate, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Customer:', style: TextStyle(color: Colors.black54, fontSize: 11)),
                        Text(
                          record.customerName,
                          style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (record.customerPhone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Mobile:', style: TextStyle(color: Colors.black54, fontSize: 11)),
                          Text(record.customerPhone, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    _buildDottedDivider(),
                    const SizedBox(height: 12),

                    // Financial breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Previous Balance', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        Text('₱${previousBalance.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Amount Paid',
                            style: TextStyle(color: Color(0xFF1B5E20), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₱${payment.amount.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    if (payment.note != null && payment.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payment Note:', style: TextStyle(color: Colors.black54, fontSize: 11)),
                          Flexible(
                            child: Text(
                              payment.note!,
                              style: const TextStyle(color: Colors.black87, fontSize: 11, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    _buildDottedDivider(),
                    const SizedBox(height: 12),

                    // Remaining Balance row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remaining Balance',
                            style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(
                          '₱${remainingDue.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isFullyPaid ? const Color(0xFF2E7D32) : Colors.amber[900],
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),

                    if (isFullyPaid) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF81C784)),
                        ),
                        child: const Center(
                          child: Text(
                            '🎉 FULLY SETTLED / BAYAD NA',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payment Deadline:', style: TextStyle(color: Colors.black54, fontSize: 11)),
                          Text(
                            DateFormat('MMM dd, yyyy').format(record.dueDate),
                            style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    _buildDottedDivider(),
                    const SizedBox(height: 10),

                    // Footer
                    const Text(
                      'Maraming salamat sa inyong pagbabayad!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stora Store Management System',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.3), fontSize: 9),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HomeColors.textPrimary,
                        side: BorderSide(color: HomeColors.cardBorder),
                        backgroundColor: HomeColors.cardBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              try {
                                await ReceiptService.instance.shareUtangPaymentReceipt(
                                  record: record,
                                  payment: payment,
                                  previousBalance: previousBalance,
                                  businessName: businessName,
                                );
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
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              try {
                                await ReceiptService.instance.printUtangPaymentReceipt(
                                  record: record,
                                  payment: payment,
                                  previousBalance: previousBalance,
                                  businessName: businessName,
                                );
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
                key: const Key('utang_receipt_done_button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done / Close', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDottedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey[400]),
              ),
            );
          }),
        );
      },
    );
  }
}
