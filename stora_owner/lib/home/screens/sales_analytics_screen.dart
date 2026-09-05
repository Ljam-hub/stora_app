import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../stora_login/stora_login.dart';
import '../stores/inventory_store.dart';
import '../stores/sales_store.dart';
import '../theme/home_colors.dart';
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
      animation: Listenable.merge([SalesStore.instance, InventoryStore.instance]),
      builder: (context, _) {
        final sales = SalesStore.instance.sales;
        final now = DateTime.now();

        // Calculations
        final todaySales = sales.where((s) => isSameDay(s.date, now)).toList();
        final todaysRevenue = todaySales.fold(0.0, (sum, s) => sum + s.total);

        final thisWeekSales = sales.where((s) => now.difference(s.date).inDays <= 7).toList();
        final thisWeekRevenue = thisWeekSales.fold(0.0, (sum, s) => sum + s.total);

        final thisMonthSales = sales.where((s) => now.difference(s.date).inDays <= 30).toList();
        final thisMonthRevenue = thisMonthSales.fold(0.0, (sum, s) => sum + s.total);

        final allTimeRevenue = sales.fold(0.0, (sum, s) => sum + s.total);

        // Daily breakdown for the past 7 days (Bar chart data)
        final last7Days = List.generate(7, (i) {
          final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
          final dayTotal = sales
              .where((s) => isSameDay(s.date, day))
              .fold(0.0, (sum, s) => sum + s.total);
          return {'day': DateFormat('E').format(day), 'date': day, 'total': dayTotal};
        });

        final maxDayTotal = last7Days.fold(0.0, (max, d) => (d['total'] as double) > max ? (d['total'] as double) : max);

        // Top Selling Products computation
        final Map<String, int> productQtyMap = {};
        final Map<String, double> productRevenueMap = {};

        final filteredSales = _selectedPeriodIndex == 0
            ? thisWeekSales
            : (_selectedPeriodIndex == 1 ? thisMonthSales : sales);

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
          backgroundColor: AppColors.background,
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
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: HomeColors.cardBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Sales Analytics',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
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
                          subtitle: '${todaySales.length} orders today',
                          icon: Icons.today_rounded,
                          accentColor: AppColors.purpleLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: '7-Day Revenue',
                          amount: '₱${thisWeekRevenue.toStringAsFixed(2)}',
                          subtitle: '${thisWeekSales.length} orders',
                          icon: Icons.calendar_view_week_rounded,
                          accentColor: const Color(0xFF4ADE80),
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
                          subtitle: '${thisMonthSales.length} orders',
                          icon: Icons.calendar_month_rounded,
                          accentColor: const Color(0xFF60A5FA),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: 'All-Time Total',
                          amount: '₱${allTimeRevenue.toStringAsFixed(2)}',
                          subtitle: '${sales.length} total orders',
                          icon: Icons.all_inclusive_rounded,
                          accentColor: const Color(0xFFFBBF24),
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
                            const Text(
                              'Revenue (Past 7 Days)',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
                                style: const TextStyle(color: AppColors.purpleLight, fontSize: 11, fontWeight: FontWeight.w700),
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
                                        color: isToday ? AppColors.purpleLight : Colors.white60,
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
                                      color: isToday ? Colors.white : AppColors.label,
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

                  // Top Selling Items Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Top Selling Products',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
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
                      child: const Center(
                        child: Text(
                          'No sales recorded in this period yet.',
                          style: TextStyle(color: AppColors.label, fontSize: 13),
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
                                    color: i < 3 ? AppColors.purpleLight : AppColors.label,
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
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '$qty units sold',
                                      style: const TextStyle(color: AppColors.label, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₱${revenue.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
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
              Text(title, style: const TextStyle(color: AppColors.label, fontSize: 11, fontWeight: FontWeight.w600)),
              Icon(icon, color: accentColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(amount, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.hint, fontSize: 10)),
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
            color: selected ? Colors.white : AppColors.label,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
