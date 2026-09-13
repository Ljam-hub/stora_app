import 'package:flutter/material.dart';
import '../auth/auth_store.dart';
import '../home/services/receipt_service.dart';
import '../home/theme/home_colors.dart';
import '../home/utils/date_utils.dart';
import '../stora_login/stora_login.dart';

class SubscriptionReceiptModal {
  static void show(
    BuildContext context, {
    String? businessName,
    String? email,
    String planName = 'Stora Premium (Monthly)',
    required double amount,
    required String referenceNumber,
    required DateTime date,
  }) {
    final auth = AuthStore.instance;
    final bName = (businessName != null && businessName.trim().isNotEmpty)
        ? businessName.trim()
        : ((auth.businessName != null && auth.businessName!.trim().isNotEmpty)
            ? auth.businessName!.trim()
            : 'Stora Store');
    final mail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : ((auth.email != null && auth.email!.trim().isNotEmpty)
            ? auth.email!.trim()
            : 'owner@example.com');
    final ref = referenceNumber.trim().isNotEmpty
        ? referenceNumber.trim()
        : 'SUB-${date.millisecondsSinceEpoch}';
    final amountFormatted = 'PHP ${amount.toStringAsFixed(2)}';

    showModalBottomSheet(
      context: context,
      backgroundColor: HomeColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.6), width: 1.2),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF34D399), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subscription Receipt',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Official digital proof of payment',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1326),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.4), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _receiptRow('Plan', planName),
                      Divider(color: const Color(0xFFA855F7).withValues(alpha: 0.2), height: 16),
                      _receiptRow('Status', 'PAID & ACTIVE', valueColor: const Color(0xFF34D399), isBold: true),
                      Divider(color: const Color(0xFFA855F7).withValues(alpha: 0.2), height: 16),
                      _receiptRow('Amount', amountFormatted, valueColor: const Color(0xFF4ADE80), isBold: true),
                      Divider(color: const Color(0xFFA855F7).withValues(alpha: 0.2), height: 16),
                      _receiptRow('Payment Method', 'GCash'),
                      Divider(color: const Color(0xFFA855F7).withValues(alpha: 0.2), height: 16),
                      _receiptRow('Reference #', ref),
                      Divider(color: const Color(0xFFA855F7).withValues(alpha: 0.2), height: 16),
                      _receiptRow('Date', formatManilaShortDateTime(date)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF9333EA).withValues(alpha: 0.12),
                          side: BorderSide(color: const Color(0xFFA855F7).withValues(alpha: 0.7), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ReceiptService.instance.printSubscriptionReceipt(
                            businessName: bName,
                            email: mail,
                            planName: planName,
                            amount: amount,
                            referenceNumber: ref,
                            date: date,
                            expiresAt: date.add(const Duration(days: 30)),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 18, color: Color(0xFFC084FC)),
                        label: const Text('Print', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF9333EA).withValues(alpha: 0.12),
                          side: BorderSide(color: const Color(0xFFA855F7).withValues(alpha: 0.7), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ReceiptService.instance.shareSubscriptionReceipt(
                            businessName: bName,
                            email: mail,
                            planName: planName,
                            amount: amount,
                            referenceNumber: ref,
                            date: date,
                            expiresAt: date.add(const Duration(days: 30)),
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFFC084FC)),
                        label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StoraGradientButton(
                  label: 'Save PDF Receipt',
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      final file = await ReceiptService.instance.saveSubscriptionReceiptToFile(
                        businessName: bName,
                        email: mail,
                        planName: planName,
                        amount: amount,
                        referenceNumber: ref,
                        date: date,
                        expiresAt: date.add(const Duration(days: 30)),
                      );
                      if (context.mounted) {
                        showStoraSnackBar(context, 'Receipt saved to: ${file.path}', isError: false);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showStoraSnackBar(context, 'Failed to save receipt: $e');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _receiptRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 13, fontWeight: FontWeight.w500)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
