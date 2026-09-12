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
import 'ai_insights_screen.dart';
import 'pending_orders_screen.dart';
import 'pos_screen.dart';
import 'profile_screen.dart';
import 'sales_analytics_screen.dart';
import 'sales_history_screen.dart';
import 'set_store_location_screen.dart';
import '../stores/chat_store.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/notification_badge.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onNavigateToChat;

  const DashboardScreen({super.key, this.onNavigateToChat});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AuthStore.instance,
        InventoryStore.instance,
        SalesStore.instance,
        AccountStatusStore.instance,
        OrdersStore.instance,
        ChatStore.instance,
      ]),
      builder: (context, _) {
        final store = InventoryStore.instance;
        final sales = SalesStore.instance;
        final orders = OrdersStore.instance;
        final lowStockCount = store.lowStock.length;

        return SafeArea(
          child: RefreshIndicator(
            color: AppColors.purpleLight,
            backgroundColor: HomeColors.cardBackground,
            onRefresh: () async {
              await Future.wait([
                store.loadProducts(),
                sales.loadSales(),
                orders.fetchOrders(),
                ChatStore.instance.fetchConversations(),
                AccountStatusStore.instance.fetchStatus(),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: HomeColors.cardElevated,
                          backgroundImage: (AuthStore.instance.avatarUrl != null && AuthStore.instance.avatarUrl!.isNotEmpty)
                              ? NetworkImage(AuthStore.instance.avatarUrl!)
                              : null,
                          child: (AuthStore.instance.avatarUrl == null || AuthStore.instance.avatarUrl!.isEmpty)
                              ? const Icon(Icons.storefront_rounded, color: AppColors.purpleLight, size: 20)
                              : null,
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
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 0),
                  child: _IncomingOrdersCard(
                    pendingCount: orders.pendingCount,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PendingOrdersScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: _EarningsCard(
                    amount: '₱${sales.todaysTotal.toStringAsFixed(2)}',
                    subtitle:
                        '${sales.todaysSalesCount} sales · Avg. ₱${sales.todaysAverage.toStringAsFixed(2)}',
                    badge: sales.changeBadge,
                    isPremium: AccountStatusStore.instance.isPremium,
                    daysLeft: AccountStatusStore.instance.daysLeft,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // AI Insights & Map Row
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!AccountStatusStore.instance.isPremium) {
                              _showPremiumFeatureDialog(context, featureName: 'AI Store Insights');
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AiInsightsScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: HomeColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.purpleLight.withValues(alpha: 0.4), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.purple.withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: HomeColors.purpleGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('AI Insights',
                                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                          if (!AccountStatusStore.instance.isPremium) ...[
                                            const SizedBox(width: 5),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 0.8),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.lock_rounded, color: Colors.amber, size: 9),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'PRO',
                                                    style: TextStyle(color: Colors.amber, fontSize: 8.5, fontWeight: FontWeight.w900),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const Text('Smart store tips',
                                          style: TextStyle(color: AppColors.label, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SetStoreLocationScreen()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: HomeColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: HomeColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on_rounded, color: Color(0xFF38BDF8), size: 16),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Store Map',
                                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                      Text('Pin your location',
                                          style: TextStyle(color: AppColors.label, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Analytics Shortcut Bar
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    onTap: () {
                      if (!AccountStatusStore.instance.isPremium) {
                        _showPremiumFeatureDialog(context, featureName: 'Sales Analytics & Reports');
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SalesAnalyticsScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: HomeColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: HomeColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.insights_rounded, color: AppColors.purpleLight, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Sales Analytics & Reports',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                    if (!AccountStatusStore.instance.isPremium) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 0.8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.lock_rounded, color: Colors.amber, size: 9),
                                            SizedBox(width: 2),
                                            Text(
                                              'PRO',
                                              style: TextStyle(color: Colors.amber, fontSize: 8.5, fontWeight: FontWeight.w900),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const Text('View 7-day revenue charts & top sellers',
                                    style: TextStyle(color: AppColors.label, fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.label, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: Row(
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
                ),
                if (!AccountStatusStore.instance.isPremium) ...[
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 500),
                    child: _FreePlanCard(
                      current: AccountStatusStore.instance.productCount,
                      limit: AccountStatusStore.instance.productLimit,
                      daysLeft: AccountStatusStore.instance.daysLeft,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 600),
                  child: Row(
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
                            icon: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('New Sale',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                            ),
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

class _EarningsCard extends StatelessWidget {
  final String amount;
  final String subtitle;
  final String badge;
  final bool isPremium;
  final int daysLeft;
  final VoidCallback? onTap;
  const _EarningsCard({
    required this.amount,
    required this.subtitle,
    required this.badge,
    this.isPremium = false,
    this.daysLeft = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: HomeColors.heroGradient,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            ...HomeColors.cardShadow,
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Today's Total Earnings",
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                  ),
                  child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(amount, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        if (isPremium)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SubscriptionScreen()),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFFD54F).withValues(alpha: 0.9),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, color: Color(0xFFFFD54F), size: 12),
                                  SizedBox(width: 3),
                                  Text(
                                    'PREMIUM',
                                    style: TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SubscriptionScreen()),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: daysLeft <= 3
                                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.9)
                                      : Colors.white.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    daysLeft <= 3 ? Icons.warning_amber_rounded : Icons.hourglass_top_rounded,
                                    color: daysLeft <= 3 ? const Color(0xFFFF8787) : Colors.white,
                                    size: 11,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    daysLeft <= 0 ? 'TRIAL ENDED' : 'TRIAL · ${daysLeft}d',
                                    style: TextStyle(
                                      color: daysLeft <= 3
                                          ? const Color(0xFFFF8787)
                                          : Colors.white.withValues(alpha: 0.95),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                  ),
                ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomeColors.cardBorder.withValues(alpha: 0.8)),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: badgeColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.label, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(color: valueColor, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
          ),
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
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_outlined, size: 16, color: AppColors.purpleLight),
                  SizedBox(width: 6),
                  Text('Free plan', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.fieldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HomeColors.cardBorder),
                    ),
                    child: Text(
                      limit > 0 ? '$current/$limit items · $daysLeft days left' : '$current items',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.purpleLight, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
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
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(color: AppColors.purpleLight, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: hasPending ? HomeColors.cardBackground : HomeColors.cardElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasPending ? AppColors.purpleLight : HomeColors.cardBorder,
            width: hasPending ? 1.5 : 1,
          ),
          boxShadow: hasPending
              ? [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  ...HomeColors.cardShadow,
                ]
              : HomeColors.cardShadow,
        ),
        child: Row(
          children: [
            AppNotificationBadge(
              count: pendingCount,
              top: -4,
              right: -4,
              borderColor: hasPending ? HomeColors.cardBackground : HomeColors.cardElevated,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasPending ? AppColors.purpleLight.withValues(alpha: 0.18) : Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: hasPending ? AppColors.purpleLight : AppColors.label,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          hasPending ? '$pendingCount Incoming ${pendingCount == 1 ? 'Order' : 'Orders'}' : 'Customer Orders',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (hasPending) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: HomeColors.purpleGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: HomeColors.glowShadow(AppColors.purple, opacity: 0.4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: hasPending ? AppColors.purple.withValues(alpha: 0.15) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: hasPending ? AppColors.purpleLight : AppColors.label,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showPremiumFeatureDialog(BuildContext context, {required String featureName}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: HomeColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.35), width: 1),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Premium Feature',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Text(
        '$featureName is exclusive to Premium subscribers. Upgrade now to unlock advanced analytics, smart AI store recommendations, and unlimited products.',
        style: const TextStyle(color: AppColors.label, fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Not Now', style: TextStyle(color: AppColors.label)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SubscriptionScreen()),
            );
          },
          child: const Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

