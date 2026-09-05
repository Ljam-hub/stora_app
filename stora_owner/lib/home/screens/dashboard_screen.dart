import 'package:flutter/material.dart';
import '../../auth/auth_store.dart';
import '../../stora_login/stora_login.dart';
import '../../data/stores/account_status_store.dart';
import '../stores/inventory_store.dart';
import '../stores/orders_store.dart';
import '../stores/sales_store.dart';
import '../theme/home_colors.dart';
import '../utils/date_utils.dart';
import '../../subscription/subscription_screen.dart';
import 'add_edit_product_screen.dart';
import 'pending_orders_screen.dart';
import 'pos_screen.dart';
import 'profile_screen.dart';
import 'sales_history_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        InventoryStore.instance,
        SalesStore.instance,
        AccountStatusStore.instance,
        OrdersStore.instance,
      ]),
      builder: (context, _) {
        final store = InventoryStore.instance;
        final sales = SalesStore.instance;
        final orders = OrdersStore.instance;
        final lowStockCount = store.lowStock.length;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: HomeColors.purpleGradient,
                      ),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                        child: const CircleAvatar(
                          radius: 20,
                          backgroundColor: HomeColors.cardElevated,
                          child: Icon(Icons.storefront_rounded, color: AppColors.purpleLight, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hi, ${AuthStore.instance.greetingName}',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: HomeColors.successText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(formatFriendlyDate(DateTime.now()),
                                  style: const TextStyle(color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined, color: AppColors.label, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _IncomingOrdersCard(
                  pendingCount: orders.pendingCount,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PendingOrdersScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _EarningsCard(
                  amount: '₱${sales.todaysTotal.toStringAsFixed(2)}',
                  subtitle:
                      '${sales.todaysSalesCount} sales · Avg. ₱${sales.todaysAverage.toStringAsFixed(2)}',
                  badge: sales.changeBadge,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'In stock',
                        icon: Icons.inventory_2_rounded,
                        badge: 'Healthy',
                        badgeColor: HomeColors.successText,
                        badgeBg: HomeColors.successBg,
                        value: '${store.totalStock}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Low stock',
                        icon: Icons.local_fire_department_rounded,
                        badge: 'Action',
                        badgeColor: AppColors.error,
                        badgeBg: HomeColors.dangerBg,
                        value: '$lowStockCount',
                        valueColor: lowStockCount > 0 ? AppColors.error : Colors.white,
                      ),
                    ),
                  ],
                ),
                if (!AccountStatusStore.instance.isPremium) ...[
                  const SizedBox(height: 14),
                  _FreePlanCard(
                    current: AccountStatusStore.instance.productCount,
                    limit: AccountStatusStore.instance.productLimit,
                    daysLeft: AccountStatusStore.instance.daysLeft,
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: HomeColors.purpleGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: HomeColors.glowShadow(AppColors.purple, opacity: 0.3),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PosScreen(isStandalone: true)),
                          ),
                          icon: const Icon(Icons.point_of_sale_rounded, color: Colors.black, size: 20),
                          label: const Text('New Sale',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OutlinedAction(
                        label: 'Add Product',
                        icon: Icons.add_circle_outline_rounded,
                        onPressed: () {
                          if (!AccountStatusStore.instance.canAddProduct) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SubscriptionScreen(
                                  productsUsed: AccountStatusStore.instance.productCount,
                                  productsLimit: AccountStatusStore.instance.productLimit,
                                ),
                              ),
                            );
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final String amount;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;
  const _EarningsCard({required this.amount, required this.subtitle, required this.badge, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: HomeColors.heroGradient,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
          boxShadow: HomeColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payments_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text("Today's Total Earnings",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(amount, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                if (onTap != null)
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String badge;
  final Color badgeColor;
  final Color badgeBg;
  final String value;
  final Color valueColor;
  const _StatCard({
    required this.title,
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.badgeBg,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeColors.cardBorder),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: badgeColor),
                  const SizedBox(width: 6),
                  Text(title, style: const TextStyle(color: AppColors.label, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: valueColor, fontSize: 26, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _FreePlanCard extends StatelessWidget {
  final int current;
  final int limit;
  final int daysLeft;
  const _FreePlanCard({required this.current, required this.limit, required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final progress = limit == 0 ? 0.0 : (current / limit).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeColors.cardBorder),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium_outlined, size: 16, color: AppColors.purpleLight),
                  SizedBox(width: 6),
                  Text('Free plan', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.fieldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HomeColors.cardBorder),
                ),
                child: Text(
                  limit > 0 ? '$current/$limit items · $daysLeft days left' : '$current items',
                  style: const TextStyle(color: AppColors.purpleLight, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.fieldBorder,
              valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? AppColors.error : AppColors.purple),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  daysLeft > 0
                      ? 'Upgrade to Premium to unlock unlimited items.'
                      : 'Free trial ended. Upgrade to add more products.',
                  style: const TextStyle(color: AppColors.label, fontSize: 12),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubscriptionScreen(productsUsed: current, productsLimit: limit),
                  ),
                ),
                child: const Text(
                  'Upgrade →',
                  style: TextStyle(color: AppColors.purpleLight, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _OutlinedAction({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.purpleLight, size: 18),
        label: Text(label, style: const TextStyle(color: AppColors.purpleLight, fontWeight: FontWeight.w700, fontSize: 14)),
        style: OutlinedButton.styleFrom(
          backgroundColor: HomeColors.cardBackground,
          side: const BorderSide(color: HomeColors.cardBorderLight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _IncomingOrdersCard extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;

  const _IncomingOrdersCard({required this.pendingCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasPending ? HomeColors.cardBackground : HomeColors.cardElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasPending ? AppColors.purpleLight : Colors.white10,
            width: hasPending ? 1.5 : 1,
          ),
          boxShadow: hasPending
              ? [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasPending ? AppColors.purpleLight.withValues(alpha: 0.2) : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: hasPending ? AppColors.purpleLight : AppColors.label,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        hasPending ? '$pendingCount Incoming ${pendingCount == 1 ? 'Order' : 'Orders'}' : 'Customer Orders',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hasPending) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.purpleLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPending
                        ? 'Tap to review, accept, or counter-offer'
                        : 'Review incoming customer carts and orders',
                    style: TextStyle(
                      color: hasPending ? AppColors.purpleLight : AppColors.label,
                      fontSize: 12,
                      fontWeight: hasPending ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: hasPending ? AppColors.purpleLight : AppColors.label,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

