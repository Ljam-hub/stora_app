import 'package:flutter/material.dart';
import '../../auth/auth_store.dart';
import '../../stora_login/stora_login.dart';
import '../../data/stores/account_status_store.dart';
import '../stores/inventory_store.dart';
import '../stores/orders_store.dart';
import '../stores/owner_notes_store.dart';
import '../stores/sales_store.dart';
import '../theme/home_colors.dart';
import '../theme/theme_mode_controller.dart';
import '../utils/date_utils.dart';
import '../../subscription/subscription_screen.dart';
import 'alerts_screen.dart';
import 'business_insights_screen.dart';
import 'owner_notes_screen.dart';
import 'pending_orders_screen.dart';
import 'profile_screen.dart';
import 'sales_analytics_screen.dart';
import 'sales_history_screen.dart';
import 'set_store_location_screen.dart';
import '../stores/chat_store.dart';
import '../stores/store_status_store.dart';
import '../stores/utang_store.dart';
import 'utang_ledger_screen.dart';
import '../shell/stora_shell.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/notification_badge.dart';
import '../widgets/payment_qr_modal.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static bool _isNavigating = false;

  static Future<T?> safeNavigate<T>(BuildContext context, Widget screen) async {
    if (_isNavigating) return null;
    _isNavigating = true;
    Future.delayed(const Duration(milliseconds: 500), () => _isNavigating = false);
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AuthStore.instance,
        InventoryStore.instance,
        SalesStore.instance,
        AccountStatusStore.instance,
        OrdersStore.instance,
        StoreStatusStore.instance,
        ThemeModeController.instance,
        OwnerNotesStore.instance,
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
                StoreStatusStore.instance.fetchStatus(),
                UtangStore.instance.load(),
                OwnerNotesStore.instance.load(),
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
                        onTap: () => DashboardScreen.safeNavigate(context, const ProfileScreen()),
                        child: Builder(
                          builder: (_) {
                            final avatar = AuthStore.instance.avatarUrl;
                            final hasAvatar = avatar != null && avatar.isNotEmpty;
                            return CircleAvatar(
                              radius: 20,
                              backgroundColor: HomeColors.cardElevated,
                              backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
                              child: !hasAvatar
                                  ? const Icon(Icons.storefront_rounded, color: AppColors.purpleLight, size: 20)
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hi, ${AuthStore.instance.greetingName}',
                              style: TextStyle(color: HomeColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
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
                                  style: TextStyle(color: HomeColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Payment QR Code',
                      onPressed: () => _showPaymentQrDialog(context),
                      icon: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.purpleLight.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, color: AppColors.purpleLight, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 0),
                  child: _StoreOpenClosedCard(),
                ),
                if (!StoreStatusStore.instance.hasValidLocation) ...[
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 25),
                    child: _MissingLocationBanner(
                      onTap: () => DashboardScreen.safeNavigate(context, const SetStoreLocationScreen()),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 50),
                  child: _IncomingOrdersCard(
                    pendingCount: orders.pendingCount,
                    onTap: () => DashboardScreen.safeNavigate(context, const PendingOrdersScreen()),
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
                    onTap: () => DashboardScreen.safeNavigate(context, const SalesHistoryScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                const FadeSlideIn(
                  delay: Duration(milliseconds: 125),
                  child: _SalesGrowthHubCard(),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: _QuickUtilityGrid(
                    totalStock: store.totalStock,
                    lowStockCount: lowStockCount,
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
              ],
            ),
          ),
        ),
      );
    },
    );
  }
}

class _SalesGrowthHubCard extends StatelessWidget {
  const _SalesGrowthHubCard();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AccountStatusStore.instance,
      builder: (context, _) {
        final isPremium = AccountStatusStore.instance.isPremium;

        return Container(
          decoration: BoxDecoration(
            color: HomeColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: HomeColors.cardBorder,
              width: 1,
            ),
            boxShadow: HomeColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.trending_up_rounded,
                        color: Color(0xFFFF6B00),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'SALES & BUSINESS GROWTH',
                      style: TextStyle(
                        color: HomeColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: HomeColors.cardBorder.withValues(alpha: 0.6)),

              // 1. Sales History
              _HubItem(
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFFFF6B00),
                title: 'Sales History',
                subtitle: 'View past sales, cash flow & receipts',
                onTap: () => DashboardScreen.safeNavigate(context, const SalesHistoryScreen()),
              ),

              Divider(height: 1, indent: 56, endIndent: 16, color: HomeColors.cardBorder.withValues(alpha: 0.5)),

              // 2. Business Insights
              _HubItem(
                icon: Icons.auto_awesome_rounded,
                iconColor: AppColors.purpleLight,
                title: 'Business Insights',
                subtitle: 'Fast-moving items & reorder tips',
                onTap: () async {
                  if (!AccountStatusStore.instance.isPremium) {
                    await AccountStatusStore.instance.fetchStatus();
                  }
                  if (!context.mounted) return;
                  if (!AccountStatusStore.instance.isPremium) {
                    _showPremiumFeatureDialog(context, featureName: 'Business Insights');
                    return;
                  }
                  DashboardScreen.safeNavigate(context, const BusinessInsightsScreen());
                },
              ),

              Divider(height: 1, indent: 56, endIndent: 16, color: HomeColors.cardBorder.withValues(alpha: 0.5)),

              // 3. Sales Analytics (PRO)
              _HubItem(
                icon: Icons.insights_rounded,
                iconColor: const Color(0xFF38BDF8),
                title: 'Sales Analytics',
                subtitle: 'Visual charts, peak hours & profit',
                badge: isPremium ? null : 'PRO',
                onTap: () async {
                  if (!AccountStatusStore.instance.isPremium) {
                    await AccountStatusStore.instance.fetchStatus();
                  }
                  if (!context.mounted) return;
                  if (!AccountStatusStore.instance.isPremium) {
                    _showPremiumFeatureDialog(context, featureName: 'Sales Analytics & Reports');
                    return;
                  }
                  DashboardScreen.safeNavigate(context, const SalesAnalyticsScreen());
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HubItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _HubItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: HomeColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_rounded, color: Colors.amber, size: 8.5),
                              const SizedBox(width: 2),
                              Text(
                                badge!,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: HomeColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: HomeColors.textSecondary.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
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
                            onTap: () => DashboardScreen.safeNavigate(context, SubscriptionScreen()),
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
                            onTap: () => DashboardScreen.safeNavigate(context, SubscriptionScreen()),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sales History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                      ],
                    ),
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

class _QuickUtilityGrid extends StatelessWidget {
  final int totalStock;
  final int lowStockCount;

  const _QuickUtilityGrid({
    required this.totalStock,
    required this.lowStockCount,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([UtangStore.instance, OwnerNotesStore.instance]),
      builder: (context, _) {
        final utang = UtangStore.instance;
        final notes = OwnerNotesStore.instance;

        // Utang data
        final utangTotal = utang.totalOutstanding;
        final utangDebtors = utang.totalActiveDebtors;
        final utangOverdue = utang.overdueRecords.length;

        // Notes data
        final activeNotesCount = notes.activeNotes.length;
        final remindersDue = notes.remindersOverdue.length;
        final remindersToday = notes.remindersToday.length;

        return Column(
          children: [
            Row(
              children: [
                // Top-Left: Utang Ledger
                Expanded(
                  child: _MiniUtilityTile(
                    icon: Icons.menu_book_rounded,
                    iconColor: Colors.amber,
                    title: 'Utang Ledger',
                    value: '₱${utangTotal.toStringAsFixed(0)}',
                    valueColor: utangTotal > 0 ? Colors.amber : HomeColors.textPrimary,
                    subtitle: utangOverdue > 0
                        ? '$utangOverdue overdue'
                        : utangDebtors > 0
                            ? '$utangDebtors debtor${utangDebtors > 1 ? 's' : ''}'
                            : 'All settled',
                    subtitleColor: utangOverdue > 0 ? AppColors.error : HomeColors.textMuted,
                    badge: utangOverdue > 0 ? 'ALERT' : null,
                    badgeColor: AppColors.error,
                    badgeBg: AppColors.error.withValues(alpha: 0.15),
                    onTap: () => DashboardScreen.safeNavigate(context, const UtangLedgerScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                // Top-Right: Owner Notes
                Expanded(
                  child: _MiniUtilityTile(
                    icon: Icons.sticky_note_2_rounded,
                    iconColor: AppColors.purpleLight,
                    title: 'Owner Notes',
                    value: '$activeNotesCount',
                    valueColor: HomeColors.textPrimary,
                    subtitle: remindersDue > 0
                        ? '$remindersDue due now'
                        : remindersToday > 0
                            ? '$remindersToday due today'
                            : activeNotesCount == 0
                                ? 'Tap to add'
                                : 'Active memos',
                    subtitleColor: remindersDue > 0
                        ? AppColors.error
                        : remindersToday > 0
                            ? const Color(0xFFF59E0B)
                            : HomeColors.textMuted,
                    badge: remindersDue > 0 ? 'DUE' : null,
                    badgeColor: AppColors.error,
                    badgeBg: AppColors.error.withValues(alpha: 0.15),
                    onTap: () => DashboardScreen.safeNavigate(context, const OwnerNotesScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Bottom-Left: In-Stock Health
                Expanded(
                  child: _MiniUtilityTile(
                    icon: Icons.inventory_2_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    title: 'In Stock',
                    value: '$totalStock',
                    subtitle: 'Catalog items',
                    badge: 'Healthy',
                    badgeColor: HomeColors.successText,
                    badgeBg: HomeColors.successBg,
                    onTap: () => StoraShell.switchToTab(context, 1),
                  ),
                ),
                const SizedBox(width: 12),
                // Bottom-Right: Low Stock Alert
                Expanded(
                  child: _MiniUtilityTile(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: lowStockCount > 0 ? AppColors.error : const Color(0xFFFF6B00),
                    title: 'Low Stock',
                    value: '$lowStockCount',
                    valueColor: lowStockCount > 0 ? AppColors.error : HomeColors.textPrimary,
                    subtitle: lowStockCount > 0 ? 'Needs reorder' : 'All stocked up',
                    subtitleColor: lowStockCount > 0 ? AppColors.error : HomeColors.textMuted,
                    badge: lowStockCount > 0 ? 'Action' : null,
                    badgeColor: AppColors.error,
                    badgeBg: HomeColors.dangerBg,
                    onTap: () => StoraShell.switchToTab(context, 4, alertsFilter: AlertsFilter.lowStock),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MiniUtilityTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final Color? valueColor;
  final String subtitle;
  final Color? subtitleColor;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeBg;
  final VoidCallback onTap;

  const _MiniUtilityTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.valueColor,
    required this.subtitle,
    this.subtitleColor,
    this.badge,
    this.badgeColor,
    this.badgeBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomeColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.cardBorder.withValues(alpha: 0.8)),
            boxShadow: HomeColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: badgeBg ?? iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          color: badgeColor ?? iconColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: HomeColors.textSecondary.withValues(alpha: 0.4),
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? HomeColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: HomeColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subtitleColor ?? HomeColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_outlined, size: 16, color: AppColors.purpleLight),
                  const SizedBox(width: 6),
                  Text('Free plan', style: TextStyle(color: HomeColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HomeColors.cardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HomeColors.cardBorder),
                    ),
                    child: Text(
                      limit > 0 ? '$current/$limit items · $daysLeft days left' : '$current items',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: HomeColors.accentText, fontSize: 12, fontWeight: FontWeight.w700),
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
              backgroundColor: HomeColors.cardBorder,
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
                  style: TextStyle(color: HomeColors.textSecondary, fontSize: 12),
                ),
              ),
              GestureDetector(
                onTap: () => DashboardScreen.safeNavigate(
                  context,
                  SubscriptionScreen(productsUsed: current, productsLimit: limit),
                ),
                child: Text(
                  'Upgrade →',
                  style: TextStyle(color: HomeColors.accentText, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
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
                  color: hasPending ? AppColors.purpleLight.withValues(alpha: 0.18) : HomeColors.surfaceHover,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: hasPending ? HomeColors.accentText : HomeColors.textSecondary,
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
                          style: TextStyle(
                            color: HomeColors.textPrimary,
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
                              color: Colors.white,
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
                      color: hasPending ? HomeColors.accentText : HomeColors.textSecondary,
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
                color: hasPending ? HomeColors.accentText : HomeColors.textSecondary,
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
          Expanded(
            child: Text(
              'Premium Feature',
              style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Text(
        '$featureName is exclusive to Premium subscribers. Upgrade now to unlock advanced analytics, business insights & recommendations, and unlimited products.',
        style: TextStyle(color: HomeColors.textSecondary, fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Not Now', style: TextStyle(color: HomeColors.textSecondary)),
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
            DashboardScreen.safeNavigate(context, SubscriptionScreen());
          },
          child: const Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

class _StoreOpenClosedCard extends StatelessWidget {
  const _StoreOpenClosedCard();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StoreStatusStore.instance,
      builder: (context, _) {
        final storeStatus = StoreStatusStore.instance;
        final isOpen = storeStatus.isOpen;
        final isUpdating = storeStatus.isUpdating;

        return Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isOpen
                  ? HomeColors.chartGreen.withValues(alpha: 0.12)
                  : HomeColors.dangerText.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOpen
                    ? HomeColors.chartGreen.withValues(alpha: 0.35)
                    : HomeColors.dangerText.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? HomeColors.chartGreen.withValues(alpha: 0.15)
                        : HomeColors.dangerText.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOpen ? Icons.storefront_rounded : Icons.store_mall_directory_outlined,
                    color: isOpen ? HomeColors.chartGreen : HomeColors.dangerText,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOpen ? HomeColors.chartGreen : HomeColors.dangerText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOpen ? 'Store is OPEN' : 'Store is CLOSED',
                            style: TextStyle(
                              color: isOpen ? HomeColors.chartGreen : HomeColors.dangerText,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOpen
                            ? 'Accepting online orders from customers'
                            : 'Orders paused. Customers see store as closed',
                        style: TextStyle(
                          color: HomeColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUpdating)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Transform.scale(
                    scale: 0.85,
                    child: Switch.adaptive(
                      value: isOpen,
                      activeTrackColor: HomeColors.chartGreen,
                      inactiveThumbColor: HomeColors.dangerText,
                      inactiveTrackColor: HomeColors.dangerText.withValues(alpha: 0.25),
                      onChanged: (val) async {
                        try {
                          await storeStatus.setOpenStatus(val);
                          if (context.mounted) {
                            showStoraSnackBar(
                              context,
                              val
                                  ? 'Store is now OPEN for customer orders'
                                  : 'Store is now CLOSED. Incoming customer orders paused',
                              isError: false,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showStoraSnackBar(context, 'Failed to update store status: $e');
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MissingLocationBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _MissingLocationBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HomeColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.warningText.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: HomeColors.warningText.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HomeColors.warningText.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_off_rounded, color: HomeColors.warningText, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Location Not Set',
                      style: TextStyle(
                        color: HomeColors.warningText,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hidden from customer map pins until configured',
                      style: TextStyle(
                        color: HomeColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Customers in your area cannot find your store on the map until you confirm your accurate pin.',
            style: TextStyle(
              color: HomeColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.pin_drop_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Set Store Location Pin',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeColors.warningText,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showPaymentQrDialog(BuildContext context) {
  showPaymentQrModal(context);
}
