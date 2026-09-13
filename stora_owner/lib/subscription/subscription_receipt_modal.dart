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
                        color: HomeColors.successBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: HomeColors.successText, size: 24),
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
                            style: TextStyle(color: AppColors.label, fontSize: 12),
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
                    color: AppColors.fieldBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.fieldBorder),
                  ),
                  child: Column(
                    children: [
                      _receiptRow('Plan', planName),
                      const Divider(color: AppColors.fieldBorder, height: 16),
                      _receiptRow('Status', 'PAID & ACTIVE', valueColor: HomeColors.successText),
                      const Divider(color: AppColors.fieldBorder, height: 16),
                      _receiptRow('Amount', amountFormatted, isBold: true),
                      const Divider(color: AppColors.fieldBorder, height: 16),
                      _receiptRow('Payment Method', 'GCash'),
                      const Divider(color: AppColors.fieldBorder, height: 16),
                      _receiptRow('Reference #', ref),
                      const Divider(color: AppColors.fieldBorder, height: 16),
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
                          side: const BorderSide(color: AppColors.fieldBorder),
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
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Print'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.fieldBorder),
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
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share'),
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
        Text(label, style: const TextStyle(color: AppColors.label, fontSize: 13)),
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
