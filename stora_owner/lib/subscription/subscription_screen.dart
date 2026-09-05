import 'package:flutter/material.dart';
import '../data/stores/account_status_store.dart';
import '../stora_login/stora_login.dart';
import '../home/theme/home_colors.dart';
import '../home/widgets/status_chip.dart';
import 'upload_gcash_proof_screen.dart';

// ---------------------------------------------------------------------
// Subscription — shown when a store hits the Free plan's product
// limit (see dashboard_screen.dart's _FreePlanCard, which links here)
// or from the Profile menu. Compares Free vs Premium and hands off to
// UploadGcashProofScreen to collect the GCash payment proof.
// ---------------------------------------------------------------------
class SubscriptionScreen extends StatelessWidget {
  final int productsUsed;
  final int productsLimit;
  final int? monthlyPrice;

  SubscriptionScreen({
    super.key,
    this.productsUsed = 0,
    int? productsLimit,
    this.monthlyPrice,
  }) : productsLimit = productsLimit ?? AccountStatusStore.instance.productLimit;

  static const _features = ['Unlimited products', 'Sales analytics', 'Priority support'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AccountStatusStore.instance,
      builder: (context, _) {
        final price = monthlyPrice ?? AccountStatusStore.instance.monthlyPrice.toInt();
        final progress = productsLimit == 0 ? 0.0 : (productsUsed / productsLimit).clamp(0.0, 1.0);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: HomeColors.cardBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const Expanded(
                        child: Text('Upgrade',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("You've hit the Free limit",
                      style: TextStyle(color: AppColors.label, fontSize: 14)),
                  const SizedBox(height: 16),

                  // Free plan card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration:
                        BoxDecoration(color: HomeColors.cardBackground, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const StatusChip(
                                label: 'FREE', color: AppColors.label, background: AppColors.fieldBackground),
                            StatusChip(
                                label: '$productsUsed/$productsLimit used',
                                color: AppColors.error,
                                background: HomeColors.dangerBg),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: progress.toDouble(),
                            minHeight: 6,
                            backgroundColor: AppColors.fieldBorder,
                            valueColor: const AlwaysStoppedAnimation(AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Premium plan card — same gradient treatment as the
                  // dashboard's earnings card, for visual consistency.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [AppColors.purple, AppColors.backgroundGradientTop],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('PREMIUM',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                            RichText(
                              text: TextSpan(children: [
                                TextSpan(
                                  text: '₱$price',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                                ),
                                const TextSpan(text: '/mo', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ..._features.map((f) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 15, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(f, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  StoraGradientButton(
                    label: 'Upgrade ₱$price/mo',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UploadGcashProofScreen(
                          amount: price,
                          gcashNumber: AccountStatusStore.instance.gcashNumber,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
