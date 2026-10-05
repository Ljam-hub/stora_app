import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/stores/account_status_store.dart';
import '../../stora_login/stora_login.dart';
import '../../subscription/subscription_screen.dart';
import '../stores/inventory_store.dart';
import '../stores/sales_store.dart';
import '../stores/utang_store.dart';
import '../theme/home_colors.dart';
import '../theme/theme_mode_controller.dart';
import '../utils/date_utils.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  int _selectedPeriodIndex = 0; // 0: 7 Days, 1: 30 Days, 2: All Time

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        SalesStore.instance,
        UtangStore.instance,
        InventoryStore.instance,
        AccountStatusStore.instance,
        ThemeModeController.instance,
      ]),
      builder: (context, _) {
        final isPremium = AccountStatusStore.instance.isPremium;
        if (!isPremium) {
          return Scaffold(
            backgroundColor: HomeColors.scaffoldBackground,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.chevron_left, color: HomeColors.textPrimary),
                          style: IconButton.styleFrom(
                            backgroundColor: HomeColors.cardBackground,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Sales Analytics',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber.withValues(alpha: 0.15),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 2),
                              ),
                              child: const Icon(Icons.insights_rounded, color: Colors.amber, size: 54),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Premium Feature',
                              style: TextStyle(color: HomeColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sales Analytics & Reports provide in-depth charts for 7-day and 30-day revenue trends, best-selling product breakdowns, and order volume insights.\n\nUpgrade to Premium to unlock full analytics.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: HomeColors.textSecondary, fontSize: 14, height: 1.5),
                            ),
                            const SizedBox(height: 28),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => SubscriptionScreen()),
                              ),
                              icon: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 20),
                              label: const Text(
                                'Upgrade to Premium',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          );
        }
        final sales = SalesStore.instance.sales;
        final allUtangPayments = UtangStore.instance.allPayments;
        final now = DateTime.now();

        // Calculations
        final todaySales = sales.where((s) => isSameDay(s.date, now) && !s.isUtang).toList();
        final todaysUtangCollected = UtangStore.instance.todaysPaymentsCollected;
        final todaysRevenue = todaySales.fold(0.0, (sum, s) => sum + s.total) + todaysUtangCollected;
        final todaysTransactionsCount = todaySales.length + UtangStore.instance.todaysPaymentsCount;

        final thisWeekSales = sales.where((s) => now.difference(s.date).inDays <= 7 && !s.isUtang).toList();
        final thisWeekUtangPayments = allUtangPayments.where((p) => now.difference(p.payment.paidAt).inDays <= 7).toList();
        final thisWeekUtangCollected = thisWeekUtangPayments.fold(0.0, (sum, p) => sum + p.payment.amount);
        final thisWeekRevenue = thisWeekSales.fold(0.0, (sum, s) => sum + s.total) + thisWeekUtangCollected;
        final thisWeekTransactionsCount = thisWeekSales.length + thisWeekUtangPayments.length;

        final thisMonthSales = sales.where((s) => now.difference(s.date).inDays <= 30 && !s.isUtang).toList();
        final thisMonthUtangPayments = allUtangPayments.where((p) => now.difference(p.payment.paidAt).inDays <= 30).toList();
        final thisMonthUtangCollected = thisMonthUtangPayments.fold(0.0, (sum, p) => sum + p.payment.amount);
        final thisMonthRevenue = thisMonthSales.fold(0.0, (sum, s) => sum + s.total) + thisMonthUtangCollected;
        final thisMonthTransactionsCount = thisMonthSales.length + thisMonthUtangPayments.length;

        final allTimeUtangCollected = allUtangPayments.fold(0.0, (sum, p) => sum + p.payment.amount);
        final allTimeRevenue = sales.where((s) => !s.isUtang).fold(0.0, (sum, s) => sum + s.total) + allTimeUtangCollected;
        final allTimeTransactionsCount = sales.where((s) => !s.isUtang).length + allUtangPayments.length;

        // Daily breakdown for the past 7 days (Bar chart data)
        final last7Days = List.generate(7, (i) {
          final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
          final daySalesTotal = sales
              .where((s) => isSameDay(s.date, day) && !s.isUtang)
              .fold(0.0, (sum, s) => sum + s.total);
          final dayUtangTotal = UtangStore.instance.paymentsCollectedOnDay(day);
          final dayTotal = daySalesTotal + dayUtangTotal;
          return {'day': DateFormat('E').format(day), 'date': day, 'total': dayTotal};
        });

        final maxDayTotal = last7Days.fold(0.0, (max, d) => (d['total'] as double) > max ? (d['total'] as double) : max);

        // Top Selling Products computation
        final Map<String, int> productQtyMap = {};
        final Map<String, double> productRevenueMap = {};

        final filteredSales = _selectedPeriodIndex == 0
            ? thisWeekSales
            : (_selectedPeriodIndex == 1 ? thisMonthSales : sales.where((s) => !s.isUtang).toList());

        final periodUtangPayments = _selectedPeriodIndex == 0
            ? thisWeekUtangCollected
            : (_selectedPeriodIndex == 1 ? thisMonthUtangCollected : allTimeUtangCollected);

        final cashSales = filteredSales.where((s) => s.paymentMethod != 'online' && !s.isUtang).toList();
        final onlineSales = filteredSales.where((s) => s.paymentMethod == 'online' && !s.isUtang).toList();
        final cashRevenue = cashSales.fold(0.0, (sum, s) => sum + s.total) + periodUtangPayments;
        final onlineRevenue = onlineSales.fold(0.0, (sum, s) => sum + s.total);
        final totalPeriodRevenue = cashRevenue + onlineRevenue;
        final cashPct = totalPeriodRevenue > 0 ? ((cashRevenue / totalPeriodRevenue) * 100).toStringAsFixed(0) : '0';
        final onlinePct = totalPeriodRevenue > 0 ? ((onlineRevenue / totalPeriodRevenue) * 100).toStringAsFixed(0) : '0';

        for (final sale in filteredSales) {
          for (final item in sale.items) {
            productQtyMap[item.product.name] = (productQtyMap[item.product.name] ?? 0) + item.quantity;
            productRevenueMap[item.product.name] =
                (productRevenueMap[item.product.name] ?? 0.0) + (item.product.price * item.quantity);
          }
        }

        final topProducts = productQtyMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          backgroundColor: HomeColors.scaffoldBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Bar
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.chevron_left, color: HomeColors.textPrimary),
                        style: IconButton.styleFrom(
                          backgroundColor: HomeColors.cardBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Sales Analytics',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Key Performance Metric Cards
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: "Today's Sales",
                          amount: '₱${todaysRevenue.toStringAsFixed(2)}',
                          subtitle: '$todaysTransactionsCount transactions today',
                          icon: Icons.today_rounded,
                          accentColor: HomeColors.accentText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: '7-Day Revenue',
                          amount: '₱${thisWeekRevenue.toStringAsFixed(2)}',
                          subtitle: '$thisWeekTransactionsCount transactions',
                          icon: Icons.calendar_view_week_rounded,
                          accentColor: HomeColors.chartGreen,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: '30-Day Revenue',
                          amount: '₱${thisMonthRevenue.toStringAsFixed(2)}',
                          subtitle: '$thisMonthTransactionsCount transactions',
                          icon: Icons.calendar_month_rounded,
                          accentColor: HomeColors.chartBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: 'All-Time Total',
                          amount: '₱${allTimeRevenue.toStringAsFixed(2)}',
                          subtitle: '$allTimeTransactionsCount total transactions',
                          icon: Icons.all_inclusive_rounded,
                          accentColor: HomeColors.chartYellow,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Weekly Sales Bar Graph Section
                  Container(
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
                            Text(
                              'Revenue (Past 7 Days)',
                              style: TextStyle(color: HomeColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: HomeColors.cardElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: HomeColors.cardBorder),
                              ),
                              child: Text(
                                'Peak: ₱${maxDayTotal.toStringAsFixed(0)}',
                                style: TextStyle(color: HomeColors.accentText, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 130,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: last7Days.map((d) {
                              final total = d['total'] as double;
                              final ratio = maxDayTotal > 0 ? (total / maxDayTotal) : 0.0;
                              final isToday = isSameDay(d['date'] as DateTime, now);

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (total > 0)
                                    Text(
                                      '₱${total.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: isToday ? HomeColors.accentText : HomeColors.textSecondary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 24,
                                    height: (ratio * 80).clamp(6.0, 80.0),
                                    decoration: BoxDecoration(
                                      color: isToday
                                          ? const Color(0xFF9B87F5)
                                          : (total > 0 ? const Color(0xFF5E49A8) : HomeColors.cardElevated),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    d['day'] as String,
                                    style: TextStyle(
                                      color: isToday ? HomeColors.textPrimary : HomeColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Method Breakdown (Cash vs Online)
                  Container(
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF6366F1)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Payment Breakdown',
                                  style: TextStyle(
                                    color: HomeColors.textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: HomeColors.cardElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: HomeColors.cardBorder),
                              ),
                              child: Text(
                                _selectedPeriodIndex == 0 ? '7 Days' : (_selectedPeriodIndex == 1 ? '30 Days' : 'All Time'),
                                style: TextStyle(color: HomeColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Proportional Stacked Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 12,
                            child: totalPeriodRevenue > 0
                                ? Row(
                                    children: [
                                      if (cashRevenue > 0)
                                        Expanded(
                                          flex: (cashRevenue * 100).round(),
                                          child: Container(color: const Color(0xFF10B981)),
                                        ),
                                      if (onlineRevenue > 0)
                                        Expanded(
                                          flex: (onlineRevenue * 100).round(),
                                          child: Container(color: const Color(0xFF2563EB)),
                                        ),
                                    ],
                                  )
                                : Container(color: HomeColors.cardBorder),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Cash & Online Metrics Row
                        Row(
                          children: [
                            // Cash Card
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Cash on Hand',
                                          style: TextStyle(
                                            color: HomeColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '₱${cashRevenue.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: HomeColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${cashSales.length} sales ($cashPct%)',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Online Card
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2563EB),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Online / E-Wallet',
                                          style: TextStyle(
                                            color: HomeColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '₱${onlineRevenue.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: HomeColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${onlineSales.length} sales ($onlinePct%)',
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Top Selling Items Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Top Selling Products',
                        style: TextStyle(color: HomeColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      // Filter chips (7d / 30d / All)
                      Row(
                        children: [
                          _FilterChip(
                            label: '7D',
                            selected: _selectedPeriodIndex == 0,
                            onTap: () => setState(() => _selectedPeriodIndex = 0),
                          ),
                          const SizedBox(width: 4),
                          _FilterChip(
                            label: '30D',
                            selected: _selectedPeriodIndex == 1,
                            onTap: () => setState(() => _selectedPeriodIndex = 1),
                          ),
                          const SizedBox(width: 4),
                          _FilterChip(
                            label: 'All',
                            selected: _selectedPeriodIndex == 2,
                            onTap: () => setState(() => _selectedPeriodIndex = 2),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (topProducts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: HomeColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: HomeColors.cardBorder),
                      ),
                      child: Center(
                        child: Text(
                          'No sales recorded in this period yet.',
                          style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: topProducts.take(8).length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final entry = topProducts[i];
                        final name = entry.key;
                        final qty = entry.value;
                        final revenue = productRevenueMap[name] ?? 0.0;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: HomeColors.cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: HomeColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: i < 3 ? AppColors.purple.withValues(alpha: 0.2) : HomeColors.cardElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: i < 3 ? AppColors.purpleLight : HomeColors.cardBorder),
                                ),
                                child: Text(
                                  '#${i + 1}',
                                  style: TextStyle(
                                    color: i < 3 ? AppColors.purpleLight : HomeColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '$qty units sold',
                                      style: TextStyle(color: HomeColors.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₱${revenue.toStringAsFixed(2)}',
                                style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      },
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _MetricCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.cardBorder),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: HomeColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              Icon(icon, color: accentColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(amount, style: TextStyle(color: HomeColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: HomeColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple : HomeColors.cardElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.purpleLight : HomeColors.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : HomeColors.textSecondary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
