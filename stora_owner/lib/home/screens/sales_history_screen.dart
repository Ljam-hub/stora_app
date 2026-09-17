import 'package:flutter/material.dart';
import '../../stora_login/stora_login.dart';
import '../models/sale.dart';
import '../stores/sales_store.dart';
import '../theme/home_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/receipt_dialog.dart';

// ---------------------------------------------------------------------
// Sales history — opened by tapping "Today's Total Earnings" on the
// dashboard. Shows every recorded sale with its items and lets you
// delete a mistaken entry.
// ---------------------------------------------------------------------
void confirmClearAllSales(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: HomeColors.cardBackground,
      title: Text('Delete all sales?', style: TextStyle(color: HomeColors.textPrimary)),
      content: Text(
          'This permanently removes your entire sales history. This can\'t be undone.',
          style: TextStyle(color: HomeColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            SalesStore.instance.clearAllSales();
            Navigator.of(ctx).pop();
          },
          child: const Text('Delete all', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

const _fullMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _shortMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  String _selectedFilterKey = 'all'; // 'all', 'today', 'month_YYYY_MM'

  @override
  void initState() {
    super.initState();
    // Automatically load latest sales when opening history so walk-ins & online orders appear immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SalesStore.instance.loadSales();
    });
  }

  List<DateTime> _getAvailableMonths(List<Sale> allSales) {
    final nowManila = toManila(DateTime.now());
    final currentMonth = DateTime(nowManila.year, nowManila.month);
    final monthSet = <String>{'${currentMonth.year}_${currentMonth.month}'};
    final months = <DateTime>[currentMonth];

    for (final s in allSales) {
      final sDate = toManila(s.date);
      final key = '${sDate.year}_${sDate.month}';
      if (!monthSet.contains(key)) {
        monthSet.add(key);
        months.add(DateTime(sDate.year, sDate.month));
      }
    }
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  List<Sale> _getFilteredSales(List<Sale> allSales) {
    if (_selectedFilterKey == 'all') return allSales;
    final nowManila = toManila(DateTime.now());

    if (_selectedFilterKey == 'today') {
      return allSales.where((s) {
        final sDate = toManila(s.date);
        return sDate.year == nowManila.year &&
            sDate.month == nowManila.month &&
            sDate.day == nowManila.day;
      }).toList();
    }

    if (_selectedFilterKey.startsWith('month_')) {
      final parts = _selectedFilterKey.split('_');
      if (parts.length == 3) {
        final year = int.tryParse(parts[1]);
        final month = int.tryParse(parts[2]);
        if (year != null && month != null) {
          return allSales.where((s) {
            final sDate = toManila(s.date);
            return sDate.year == year && sDate.month == month;
          }).toList();
        }
      }
    }

    return allSales;
  }

  String _getFilterLabel(List<DateTime> availableMonths) {
    if (_selectedFilterKey == 'all') return 'All Time';
    if (_selectedFilterKey == 'today') return 'Today';
    if (_selectedFilterKey.startsWith('month_')) {
      final parts = _selectedFilterKey.split('_');
      if (parts.length == 3) {
        final year = int.tryParse(parts[1]);
        final month = int.tryParse(parts[2]);
        if (year != null && month != null && month >= 1 && month <= 12) {
          final now = toManila(DateTime.now());
          if (year == now.year && month == now.month) {
            return 'This Month';
          }
          return '${_shortMonthNames[month - 1]} $year';
        }
      }
    }
    return 'Filter';
  }

  String _getRevenueTitle() {
    if (_selectedFilterKey == 'all') return 'All-time revenue';
    if (_selectedFilterKey == 'today') return "Today's revenue";
    if (_selectedFilterKey.startsWith('month_')) {
      final parts = _selectedFilterKey.split('_');
      if (parts.length == 3) {
        final year = int.tryParse(parts[1]);
        final month = int.tryParse(parts[2]);
        if (year != null && month != null && month >= 1 && month <= 12) {
          final now = toManila(DateTime.now());
          if (year == now.year && month == now.month) {
            return 'This month revenue';
          }
          return '${_shortMonthNames[month - 1]} $year revenue';
        }
      }
    }
    return 'Total revenue';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SalesStore.instance,
      builder: (context, _) {
        final allSales = SalesStore.instance.sales; // newest first
        final availableMonths = _getAvailableMonths(allSales);
        final filteredSales = _getFilteredSales(allSales);
        final nowManila = toManila(DateTime.now());
        final currentMonthKey = 'month_${nowManila.year}_${nowManila.month}';

        return Scaffold(
          backgroundColor: HomeColors.scaffoldBackground,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Bar Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.chevron_left, color: HomeColors.textPrimary),
                        style: IconButton.styleFrom(
                          backgroundColor: HomeColors.cardBackground,
                          side: BorderSide(color: HomeColors.cardBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Sales History',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: HomeColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (allSales.isNotEmpty)
                        IconButton(
                          onPressed: () => confirmClearAllSales(context),
                          icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
                          style: IconButton.styleFrom(
                            backgroundColor: HomeColors.cardBackground,
                            side: BorderSide(color: HomeColors.cardBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Main Content with Refresh
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.purpleLight,
                    backgroundColor: HomeColors.cardBackground,
                    onRefresh: () => SalesStore.instance.loadSales(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        // Summary & Month Filter Card
                        _HistorySummaryCard(
                          filteredSales: filteredSales,
                          allSales: allSales,
                          revenueTitle: _getRevenueTitle(),
                          currentFilterLabel: _getFilterLabel(availableMonths),
                          selectedFilterKey: _selectedFilterKey,
                          currentMonthKey: currentMonthKey,
                          availableMonths: availableMonths,
                          onFilterSelected: (newKey) => setState(() => _selectedFilterKey = newKey),
                        ),
                        const SizedBox(height: 16),

                        // Filter Chips Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All Time (${allSales.length})',
                                isSelected: _selectedFilterKey == 'all',
                                onTap: () => setState(() => _selectedFilterKey = 'all'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Today',
                                isSelected: _selectedFilterKey == 'today',
                                onTap: () => setState(() => _selectedFilterKey = 'today'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'This Month',
                                isSelected: _selectedFilterKey == currentMonthKey,
                                onTap: () => setState(() => _selectedFilterKey = currentMonthKey),
                              ),
                              if (availableMonths.length > 1) ...[
                                const SizedBox(width: 8),
                                _MonthDropdownChip(
                                  selectedFilterKey: _selectedFilterKey,
                                  availableMonths: availableMonths,
                                  onSelected: (key) => setState(() => _selectedFilterKey = key),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Sales Items List or Empty State
                        if (filteredSales.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                            decoration: BoxDecoration(
                              color: HomeColors.cardBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: HomeColors.cardBorder),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: HomeColors.cardElevated,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: HomeColors.cardBorder),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 40,
                                      color: AppColors.purpleLight,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    allSales.isEmpty
                                        ? 'No sales recorded yet'
                                        : 'No sales for ${_getFilterLabel(availableMonths)}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: HomeColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    allSales.isEmpty
                                        ? 'Complete a sale from POS to see it here.'
                                        : 'Try choosing another month or switch back to All Time.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
                                  ),
                                  if (allSales.isNotEmpty && _selectedFilterKey != 'all') ...[
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.purpleLight,
                                        side: const BorderSide(color: AppColors.purpleLight),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => setState(() => _selectedFilterKey = 'all'),
                                      child: const Text('Show All Time'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        else
                          ...filteredSales.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _SaleCard(sale: s),
                              )),
                      ],
                    ),
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

// ---------------------------------------------------------------------
// Summary Card with Embedded Month/Period Selector
// ---------------------------------------------------------------------
class _HistorySummaryCard extends StatelessWidget {
  final List<Sale> filteredSales;
  final List<Sale> allSales;
  final String revenueTitle;
  final String currentFilterLabel;
  final String selectedFilterKey;
  final String currentMonthKey;
  final List<DateTime> availableMonths;
  final ValueChanged<String> onFilterSelected;

  const _HistorySummaryCard({
    required this.filteredSales,
    required this.allSales,
    required this.revenueTitle,
    required this.currentFilterLabel,
    required this.selectedFilterKey,
    required this.currentMonthKey,
    required this.availableMonths,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final total = filteredSales.fold(0.0, (sum, s) => sum + s.total);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeColors.cardBorder),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period Selector Header Row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 14, color: HomeColors.textSecondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        revenueTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HomeColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Select Month / Period',
                onSelected: onFilterSelected,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                color: HomeColors.cardBackground,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: HomeColors.cardElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: HomeColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.purpleLight),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          currentFilterLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: HomeColors.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: HomeColors.textSecondary),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(
                          Icons.all_inclusive_rounded,
                          size: 16,
                          color: selectedFilterKey == 'all' ? AppColors.purpleLight : HomeColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'All Time (${allSales.length})',
                          style: TextStyle(
                            color: selectedFilterKey == 'all' ? AppColors.purpleLight : HomeColors.textPrimary,
                            fontWeight: selectedFilterKey == 'all' ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'today',
                    child: Row(
                      children: [
                        Icon(
                          Icons.today_rounded,
                          size: 16,
                          color: selectedFilterKey == 'today' ? AppColors.purpleLight : HomeColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Today',
                          style: TextStyle(
                            color: selectedFilterKey == 'today' ? AppColors.purpleLight : HomeColors.textPrimary,
                            fontWeight: selectedFilterKey == 'today' ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  ...availableMonths.map((m) {
                    final key = 'month_${m.year}_${m.month}';
                    final label = '${_fullMonthNames[m.month - 1]} ${m.year}';
                    final isSelected = selectedFilterKey == key;
                    final isThisMonth = key == currentMonthKey;
                    return PopupMenuItem(
                      value: key,
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 15,
                            color: isSelected ? AppColors.purpleLight : HomeColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isThisMonth ? '$label (Current)' : label,
                            style: TextStyle(
                              color: isSelected ? AppColors.purpleLight : HomeColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total Earnings & Total Sales Count Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '₱${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: HomeColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 38, width: 1, color: HomeColors.cardBorder, margin: const EdgeInsets.symmetric(horizontal: 12)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_rounded, size: 14, color: HomeColors.accentText),
                      const SizedBox(width: 5),
                      Text(
                        'Total sales',
                        style: TextStyle(
                          color: HomeColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${filteredSales.length}',
                    style: TextStyle(
                      color: HomeColors.accentText,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Filter Chip Component
// ---------------------------------------------------------------------
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.purpleLight : HomeColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.purpleLight : HomeColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : HomeColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MonthDropdownChip extends StatelessWidget {
  final String selectedFilterKey;
  final List<DateTime> availableMonths;
  final ValueChanged<String> onSelected;

  const _MonthDropdownChip({
    required this.selectedFilterKey,
    required this.availableMonths,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isCustomMonth = selectedFilterKey.startsWith('month_');

    return PopupMenuButton<String>(
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: HomeColors.cardBackground,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isCustomMonth ? AppColors.purpleLight.withValues(alpha: 0.2) : HomeColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCustomMonth ? AppColors.purpleLight : HomeColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_rounded,
              size: 14,
              color: isCustomMonth ? AppColors.purpleLight : HomeColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              'Select Month',
              style: TextStyle(
                color: isCustomMonth ? AppColors.purpleLight : HomeColors.textSecondary,
                fontSize: 12,
                fontWeight: isCustomMonth ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: isCustomMonth ? AppColors.purpleLight : HomeColors.textSecondary,
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => availableMonths.map((m) {
        final key = 'month_${m.year}_${m.month}';
        final label = '${_fullMonthNames[m.month - 1]} ${m.year}';
        final isSelected = selectedFilterKey == key;
        return PopupMenuItem(
          value: key,
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: isSelected ? AppColors.purpleLight : HomeColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.purpleLight : HomeColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final Sale sale;
  const _SaleCard({required this.sale});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        title: Text('Delete sale?', style: TextStyle(color: HomeColors.textPrimary)),
        content: Text(
            'This removes the sale from your history. It will not add the items back to stock.',
            style: TextStyle(color: HomeColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              SalesStore.instance.deleteSale(sale.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

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
          // Row 1: Date & Channel Tag on left, Price on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: HomeColors.cardElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: HomeColors.cardBorder),
                      ),
                      child: Text(
                        formatDateTime(sale.date),
                        style: TextStyle(
                          color: HomeColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: sale.isOnlineOrder ? const Color(0xFFE8F5E9) : HomeColors.cardElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: sale.isOnlineOrder ? const Color(0xFF81C784) : HomeColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        sale.isOnlineOrder ? 'Online Order' : 'In-Store',
                        style: TextStyle(
                          color: sale.isOnlineOrder ? const Color(0xFF2E7D32) : HomeColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₱${sale.total.toStringAsFixed(2)}',
                style: TextStyle(
                  color: HomeColors.accentText,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Customer Name & Receipt Number on left, Actions on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 14, color: HomeColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            sale.displayCustomerName,
                            style: TextStyle(
                              color: HomeColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Receipt #: ${sale.displayReceiptNumber}',
                      style: TextStyle(
                        color: HomeColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => ReceiptDialog.show(context, sale),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF2E7D32)),
                          SizedBox(width: 4),
                          Text(
                            'Receipt',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _confirmDelete(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: HomeColors.cardElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: HomeColors.cardBorder),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: HomeColors.cardBorder, height: 1),
          const SizedBox(height: 10),
          ...sale.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: HomeColors.cardElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('x${item.quantity}',
                                style: TextStyle(color: HomeColors.accentText, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item.product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: HomeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    Text('₱${item.subtotal.toStringAsFixed(2)}',
                        style: TextStyle(color: HomeColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
