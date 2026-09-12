import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/stores/account_status_store.dart';
import '../stora_login/stora_login.dart';
import '../home/theme/home_colors.dart';
import '../home/widgets/status_chip.dart';
import 'upload_gcash_proof_screen.dart';

// ---------------------------------------------------------------------
// Subscription — shows active Premium status or upgrade options.
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

  static const _features = [
    'Unlimited products & categories',
    'Sales analytics & revenue reports',
    'AI store insights & recommendations',
    'Priority support & map discovery',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AccountStatusStore.instance,
      builder: (context, _) {
        final account = AccountStatusStore.instance;
        final isPremium = account.isPremium;
        final price = monthlyPrice ?? account.monthlyPrice.toInt();
        final currentProducts = productsUsed > 0 ? productsUsed : account.productCount;
        final progress = productsLimit == 0 ? 0.0 : (currentProducts / productsLimit).clamp(0.0, 1.0);
        final premiumUntil = account.status.premiumUntil;
        final daysLeft = account.daysLeft;

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
                      Expanded(
                        child: Text(
                          isPremium ? 'My Subscription' : 'Upgrade Plan',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (isPremium) ...[
                    // Premium Active Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A1C3C), Color(0xFF1E142B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.6), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'ACTIVE PREMIUM',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₱$price/mo',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "You're on Premium!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            premiumUntil != null
                                ? 'Active until ${DateFormat.yMMMd().format(premiumUntil)} ($daysLeft days remaining)'
                                : 'All store features and unlimited products unlocked.',
                            style: const TextStyle(
                              color: AppColors.label,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  '$currentProducts products listed',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                const Text(
                                  'Unlimited',
                                  style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Included Features',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    ..._features.map((f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, size: 14, color: Color(0xFF4ADE80)),
                              ),
                              const SizedBox(width: 10),
                              Text(f, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 28),

                    StoraGradientButton(
                      label: 'Extend / Renew Subscription',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UploadGcashProofScreen(
                            amount: price,
                            gcashNumber: account.gcashNumber,
                            gcashName: account.gcashName,
                            qrCodeUrl: account.qrCodeUrl,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Free / Trial Plan View
                    Text(
                      daysLeft > 0
                          ? 'Free Trial: $daysLeft days left'
                          : "You've hit the Free limit",
                      style: const TextStyle(color: AppColors.label, fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Free plan card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: HomeColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              StatusChip(
                                label: daysLeft > 0 ? 'FREE TRIAL' : 'FREE',
                                color: AppColors.label,
                                background: AppColors.fieldBackground,
                              ),
                              StatusChip(
                                label: '$currentProducts/$productsLimit used',
                                color: progress >= 1.0 ? AppColors.error : AppColors.purpleLight,
                                background: progress >= 1.0 ? HomeColors.dangerBg : AppColors.purple.withValues(alpha: 0.15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: progress.toDouble(),
                              minHeight: 6,
                              backgroundColor: AppColors.fieldBorder,
                              valueColor: AlwaysStoppedAnimation(
                                progress >= 1.0 ? AppColors.error : AppColors.purpleLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Premium plan card
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
                                child: const Text(
                                  'PREMIUM',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                              RichText(
                                text: TextSpan(children: [
                                  TextSpan(
                                    text: '₱$price',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
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
                            gcashNumber: account.gcashNumber,
                            gcashName: account.gcashName,
                            qrCodeUrl: account.qrCodeUrl,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
