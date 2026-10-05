import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/payment_account.dart';
import '../screens/store_payment_screen.dart';
import '../../auth/auth_store.dart';
import '../stores/store_status_store.dart';
import '../theme/home_colors.dart';
import '../theme/theme_mode_controller.dart';

/// Shows the store's walk-in payment QR code modal sheet.
/// Accessible from Dashboard, POS screen, and Cash Payment dialog.
void showPaymentQrModal(BuildContext context) {
  HapticFeedback.lightImpact();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const PaymentQrModalSheet(),
  );
}

class PaymentQrModalSheet extends StatefulWidget {
  const PaymentQrModalSheet({super.key});

  @override
  State<PaymentQrModalSheet> createState() => _PaymentQrModalSheetState();
}

class _PaymentQrModalSheetState extends State<PaymentQrModalSheet> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final accounts = StoreStatusStore.instance.paymentAccounts;
    final primaryIdx = accounts.indexWhere((a) => a.isPrimary);
    if (primaryIdx >= 0) {
      _selectedIndex = primaryIdx;
    }
  }

  static IconData getAccountIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('gcash') || lower.contains('maya') || lower.contains('wallet')) {
      return Icons.account_balance_wallet_rounded;
    } else if (lower.contains('bank') ||
        lower.contains('bpi') ||
        lower.contains('bdo') ||
        lower.contains('union') ||
        lower.contains('landbank') ||
        lower.contains('metro')) {
      return Icons.account_balance_rounded;
    }
    return Icons.payment_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([StoreStatusStore.instance, ThemeModeController.instance]),
      builder: (context, _) {
        final status = StoreStatusStore.instance;
        List<PaymentAccount> accounts = status.paymentAccounts;
        if (accounts.isEmpty &&
            (status.paymentPhoneNumber.isNotEmpty ||
                (status.paymentQrUrl != null && status.paymentQrUrl!.isNotEmpty))) {
          accounts = [
            PaymentAccount(
              label: 'GCash',
              accountName: status.paymentAccountName,
              accountNumber: status.paymentPhoneNumber,
              qrCodeUrl: status.paymentQrUrl,
            ),
          ];
        }

        if (_selectedIndex >= accounts.length) {
          _selectedIndex = 0;
        }

        final currentAccount = accounts.isNotEmpty ? accounts[_selectedIndex] : null;
        final hasQr = currentAccount != null && currentAccount.hasQr && currentAccount.resolvedQrUrl.isNotEmpty;
        final phone = currentAccount?.accountNumber ?? '';
        final name = currentAccount?.accountName ?? '';
        final label = (currentAccount != null && currentAccount.label.isNotEmpty)
            ? currentAccount.label
            : 'Online Payment';
        final businessName = (AuthStore.instance.businessName != null &&
                AuthStore.instance.businessName!.trim().isNotEmpty)
            ? AuthStore.instance.businessName!.trim()
            : 'Our Store';

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: HomeColors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: HomeColors.cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: HomeColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF60A5FA).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF60A5FA), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan to Pay (Walk-in)',
                            style: TextStyle(
                              color: HomeColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            accounts.isNotEmpty
                                ? '${accounts.length} ${accounts.length == 1 ? 'payment method' : 'payment methods'} available'
                                : 'Setup payment QR',
                            style: TextStyle(
                              color: HomeColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: HomeColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (accounts.isEmpty) ...[
                  // Empty State: No Accounts configured
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    decoration: BoxDecoration(
                      color: HomeColors.cardElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: HomeColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF60A5FA).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF60A5FA), size: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Payment QR Uploaded Yet',
                          style: TextStyle(
                            color: HomeColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Upload your store\'s payment QR codes (GCash, Maya, Bank) so walk-in customers can scan and pay directly on your phone.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: HomeColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const StorePaymentScreen()),
                            );
                          },
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text('Setup Payment Methods Now', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HomeColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // If multiple accounts, display account switcher tabs/chips!
                  if (accounts.length > 1) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(accounts.length, (index) {
                          final acc = accounts[index];
                          final isSelected = _selectedIndex == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    getAccountIcon(acc.label),
                                    size: 15,
                                    color: isSelected ? Colors.white : HomeColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    acc.label.isNotEmpty ? acc.label : 'Account ${index + 1}',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : HomeColors.textPrimary,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  if (acc.hasQr) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.qr_code_rounded,
                                      size: 13,
                                      color: isSelected ? Colors.white70 : HomeColors.textMuted,
                                    ),
                                  ],
                                ],
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedIndex = index);
                                }
                              },
                              selectedColor: const Color(0xFF2563EB),
                              backgroundColor: HomeColors.cardElevated,
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF2563EB) : HomeColors.cardBorder,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              showCheckmark: false,
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // QR Box or Account Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Account Provider Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(getAccountIcon(label), size: 14, color: const Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          businessName,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (name.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Account: $name',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 14),

                        if (hasQr) ...[
                          // The actual QR code image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(
                                maxWidth: 240,
                                maxHeight: 240,
                              ),
                              child: Image.network(
                                currentAccount.resolvedQrUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 200,
                                    width: 200,
                                    alignment: Alignment.center,
                                    child: const CircularProgressIndicator(
                                      color: Color(0xFF2563EB),
                                      strokeWidth: 2.5,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 180,
                                  alignment: Alignment.center,
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
                                      SizedBox(height: 8),
                                      Text(
                                        'Failed to display QR image',
                                        style: TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Show QR to walk-in shoppers',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ] else ...[
                          // No QR uploaded for this specific account
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.tag_rounded, color: Color(0xFF64748B), size: 36),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Manual Transfer / Number Only',
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'No QR code uploaded for this account. Shopper can use the account number below.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Phone / Account Number Copy Box
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: HomeColors.cardElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: HomeColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(getAccountIcon(label), color: const Color(0xFF60A5FA), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$label Account Number',
                                  style: TextStyle(color: HomeColors.textSecondary, fontSize: 11),
                                ),
                                Text(
                                  phone,
                                  style: TextStyle(
                                    color: HomeColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: phone));
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$label number copied to clipboard!'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF60A5FA).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy_rounded, color: Color(0xFF60A5FA), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Copy',
                                    style: TextStyle(
                                      color: Color(0xFF60A5FA),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const StorePaymentScreen()),
                          );
                        },
                        icon: const Icon(Icons.settings_rounded, size: 16),
                        label: const Text('Manage Payment Methods', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class PaymentMiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const PaymentMiniBadge(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
