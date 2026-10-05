import 'package:flutter/material.dart';
import '../../stora_login/stora_login.dart';
import '../models/sale.dart';
import '../stores/sales_store.dart';
import '../stores/utang_store.dart';
import '../theme/home_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/utang_payment_receipt_dialog.dart';

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

sealed class SalesHistoryEntry {
  DateTime get date;
}

class SaleHistoryItem extends SalesHistoryEntry {
  final Sale sale;
  SaleHistoryItem(this.sale);
  @override
  DateTime get date => sale.date;
}

class UtangPaymentHistoryItem extends SalesHistoryEntry {
  final UtangPaymentWithRecord paymentWithRecord;
  UtangPaymentHistoryItem(this.paymentWithRecord);
  @override
  DateTime get date => paymentWithRecord.payment.paidAt;
}

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  String _selectedFilterKey = 'all'; // 'all', 'today', 'month_YYYY_MM'
  String _sortOrder = 'newest'; // 'newest', 'oldest'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Automatically load latest sales & utang when opening history so entries appear immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SalesStore.instance.loadSales();
      UtangStore.instance.load();
    });
  }

  List<DateTime> _getAvailableMonths(List<Sale> allSales, List<UtangPaymentWithRecord> allPayments) {
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
    for (final p in allPayments) {
      final pDate = toManila(p.payment.paidAt);
      final key = '${pDate.year}_${pDate.month}';
      if (!monthSet.contains(key)) {
        monthSet.add(key);
        months.add(DateTime(pDate.year, pDate.month));
      }
    }
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  List<SalesHistoryEntry> _getFilteredEntries(List<Sale> allSales, List<UtangPaymentWithRecord> allPayments) {
    final entries = <SalesHistoryEntry>[
      ...allSales.map((s) => SaleHistoryItem(s)),
      ...allPayments.map((p) => UtangPaymentHistoryItem(p)),
    ];

    List<SalesHistoryEntry> result;
    if (_selectedFilterKey == 'all') {
      result = List<SalesHistoryEntry>.from(entries);
    } else if (_selectedFilterKey == 'today') {
      final nowManila = toManila(DateTime.now());
      result = entries.where((e) {
        final eDate = toManila(e.date);
        return eDate.year == nowManila.year &&
            eDate.month == nowManila.month &&
            eDate.day == nowManila.day;
      }).toList();
    } else if (_selectedFilterKey.startsWith('month_')) {
      final parts = _selectedFilterKey.split('_');
      if (parts.length == 3) {
        final year = int.tryParse(parts[1]);
        final month = int.tryParse(parts[2]);
        if (year != null && month != null) {
          result = entries.where((e) {
            final eDate = toManila(e.date);
            return eDate.year == year && eDate.month == month;
          }).toList();
        } else {
          result = List<SalesHistoryEntry>.from(entries);
        }
      } else {
        result = List<SalesHistoryEntry>.from(entries);
      }
    } else {
      result = List<SalesHistoryEntry>.from(entries);
    }

    if (_sortOrder == 'oldest') {
      result.sort((a, b) => a.date.compareTo(b.date));
    } else {
      result.sort((a, b) => b.date.compareTo(a.date));
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((e) {
        if (e is SaleHistoryItem) {
          final s = e.sale;
          final refMatches = s.referenceNumber?.toLowerCase().contains(query) ?? false;
          final nameMatches = s.customerName?.toLowerCase().contains(query) ?? false;
          final notesMatches = s.notes?.toLowerCase().contains(query) ?? false;
          final paymentMethodMatches = s.paymentMethod?.toLowerCase().contains(query) ?? false;
          final itemMatches = s.items.any((item) => item.product.name.toLowerCase().contains(query));
          return refMatches || nameMatches || notesMatches || paymentMethodMatches || itemMatches;
        } else if (e is UtangPaymentHistoryItem) {
          final p = e.paymentWithRecord.payment;
          final r = e.paymentWithRecord.record;
          final nameMatches = r.customerName.toLowerCase().contains(query);
          final phoneMatches = r.customerPhone.toLowerCase().contains(query);
          final noteMatches = p.note?.toLowerCase().contains(query) ?? false;
          final termMatches = 'bayad utang'.contains(query) || 'debt payment'.contains(query) || 'utang'.contains(query);
          return nameMatches || phoneMatches || noteMatches || termMatches;
        }
        return false;
      }).toList();
    }

    return result;
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
      animation: Listenable.merge([SalesStore.instance, UtangStore.instance]),
      builder: (context, _) {
        final allSales = SalesStore.instance.sales; // newest first
        final allPayments = UtangStore.instance.allPayments;
        final availableMonths = _getAvailableMonths(allSales, allPayments);
        final filteredEntries = _getFilteredEntries(allSales, allPayments);
        final allEntriesCount = allSales.length + allPayments.length;
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

                // Search Bar for Reference #, Customer, Notes, Products, Debt Payments
                if (allEntriesCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(color: HomeColors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Search by Ref #, customer, note, product...',
                        hintStyle: TextStyle(color: HomeColors.textMuted, fontSize: 12.5),
                        prefixIcon: Icon(Icons.search_rounded, color: HomeColors.textMuted, size: 19),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: HomeColors.textMuted, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: HomeColors.cardBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: HomeColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: HomeColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
                        ),
                      ),
                    ),
                  ),

                // Main Content with Refresh
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.purpleLight,
                    backgroundColor: HomeColors.cardBackground,
                    onRefresh: () async {
                      await Future.wait([
                        SalesStore.instance.loadSales(),
                        UtangStore.instance.load(),
                      ]);
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: 4 + (filteredEntries.isEmpty ? 1 : filteredEntries.length),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _HistorySummaryCard(
                            filteredEntries: filteredEntries,
                            allEntriesCount: allEntriesCount,
                            revenueTitle: _getRevenueTitle(),
                            currentFilterLabel: _getFilterLabel(availableMonths),
                            selectedFilterKey: _selectedFilterKey,
                            currentMonthKey: currentMonthKey,
                            availableMonths: availableMonths,
                            onFilterSelected: (newKey) => setState(() => _selectedFilterKey = newKey),
                          );
                        }
                        if (index == 1) return const SizedBox(height: 16);
                        if (index == 2) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: 'All Time ($allEntriesCount)',
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
                          );
                        }
                        if (index == 3) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${filteredEntries.length} ${filteredEntries.length == 1 ? 'transaction' : 'transactions'}',
                                  style: TextStyle(
                                    color: HomeColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                _SalesSortDropdown(
                                  sortOrder: _sortOrder,
                                  onSelected: (newOrder) => setState(() => _sortOrder = newOrder),
                                ),
                              ],
                            ),
                          );
                        }

                        if (filteredEntries.isEmpty) {
                          return Container(
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
                                    _searchQuery.isNotEmpty
                                        ? 'No transactions matching "$_searchQuery"'
                                        : (allEntriesCount == 0
                                            ? 'No sales or debt collections recorded yet'
                                            : 'No transactions for ${_getFilterLabel(availableMonths)}'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: HomeColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Check the reference number or spelling and try again.'
                                        : (allEntriesCount == 0
                                            ? 'Complete a sale from POS or record a debt payment in Utang Ledger.'
                                            : 'Try choosing another month or switch back to All Time.'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
                                  ),
                                  if (_searchQuery.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF2196F3),
                                        side: const BorderSide(color: Color(0xFF2196F3)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                      child: const Text('Clear Search'),
                                    ),
                                  ] else if (allEntriesCount > 0 && _selectedFilterKey != 'all') ...[
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
                          );
                        }
                        
                        final entry = filteredEntries[index - 4];
                        if (entry is SaleHistoryItem) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SaleCard(sale: entry.sale),
                          );
                        } else if (entry is UtangPaymentHistoryItem) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _UtangPaymentHistoryCard(paymentWithRecord: entry.paymentWithRecord),
                          );
                        }
                        return const SizedBox.shrink();
                      },
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
  final List<SalesHistoryEntry> filteredEntries;
  final int allEntriesCount;
  final String revenueTitle;
  final String currentFilterLabel;
  final String selectedFilterKey;
  final String currentMonthKey;
  final List<DateTime> availableMonths;
  final ValueChanged<String> onFilterSelected;

  const _HistorySummaryCard({
    required this.filteredEntries,
    required this.allEntriesCount,
    required this.revenueTitle,
    required this.currentFilterLabel,
    required this.selectedFilterKey,
    required this.currentMonthKey,
    required this.availableMonths,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    double total = 0.0;
    double utangCreditTotal = 0.0;
    int collectedCount = 0;

    for (final e in filteredEntries) {
      if (e is SaleHistoryItem) {
        if (!e.sale.isUtang) {
          total += e.sale.total;
          collectedCount++;
        } else {
          utangCreditTotal += e.sale.total;
        }
      } else if (e is UtangPaymentHistoryItem) {
        total += e.paymentWithRecord.payment.amount;
        collectedCount++;
      }
    }

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
                          'All Time ($allEntriesCount)',
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
                    if (utangCreditTotal > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+ ₱${utangCreditTotal.toStringAsFixed(2)} in Utang / Credit',
                          style: const TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
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
                        'Collected sales',
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
                    '$collectedCount',
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

class _SalesSortDropdown extends StatelessWidget {
  final String sortOrder;
  final ValueChanged<String> onSelected;

  const _SalesSortDropdown({
    required this.sortOrder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isNewest = sortOrder == 'newest';

    return PopupMenuButton<String>(
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: HomeColors.cardBackground,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: HomeColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HomeColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: AppColors.purpleLight,
            ),
            const SizedBox(width: 4),
            Text(
              isNewest ? 'Newest Date' : 'Oldest Date',
              style: TextStyle(
                color: HomeColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: HomeColors.textSecondary,
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'newest',
          child: Row(
            children: [
              Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: isNewest ? AppColors.purpleLight : HomeColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Newest Date First',
                style: TextStyle(
                  color: isNewest ? AppColors.purpleLight : HomeColors.textPrimary,
                  fontWeight: isNewest ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (isNewest) ...[
                const Spacer(),
                const Icon(Icons.check_rounded, size: 16, color: AppColors.purpleLight),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: 'oldest',
          child: Row(
            children: [
              Icon(
                Icons.arrow_upward_rounded,
                size: 16,
                color: !isNewest ? AppColors.purpleLight : HomeColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Oldest Date First',
                style: TextStyle(
                  color: !isNewest ? AppColors.purpleLight : HomeColors.textPrimary,
                  fontWeight: !isNewest ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (!isNewest) ...[
                const Spacer(),
                const Icon(Icons.check_rounded, size: 16, color: AppColors.purpleLight),
              ],
            ],
          ),
        ),
      ],
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
                    if (sale.isUtang) ...[
                      Builder(
                        builder: (context) {
                          final utangRecord = UtangStore.instance.getRecordForSale(sale);
                          if (utangRecord != null && utangRecord.isFullyPaid) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF81C784)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 11, color: Color(0xFF2E7D32)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Utang · Fully Paid',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (utangRecord != null && utangRecord.amountPaid > 0) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFD54F)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timelapse_rounded, size: 11, color: Color(0xFFF57F17)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Utang · Paid ₱${utangRecord.amountPaid.toStringAsFixed(0)}/₱${utangRecord.totalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Color(0xFFF57F17),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFFB74D)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.credit_score_rounded, size: 11, color: Color(0xFFE65100)),
                                SizedBox(width: 3),
                                Text(
                                  'Utang · Unpaid',
                                  style: TextStyle(
                                    color: Color(0xFFE65100),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    if (sale.paymentMethod == 'online' || (sale.referenceNumber != null && sale.referenceNumber!.isNotEmpty))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF90CAF9)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.smartphone_rounded, size: 11, color: Color(0xFF1976D2)),
                            const SizedBox(width: 3),
                            Text(
                              sale.referenceNumber != null && sale.referenceNumber!.isNotEmpty
                                  ? 'Ref: ${sale.referenceNumber}'
                                  : 'Online',
                              style: const TextStyle(
                                color: Color(0xFF1976D2),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  final utangRecord = sale.isUtang ? UtangStore.instance.getRecordForSale(sale) : null;
                  final isFullyPaidUtang = utangRecord?.isFullyPaid ?? false;
                  return Text(
                    '₱${sale.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: sale.isUtang
                          ? (isFullyPaidUtang ? const Color(0xFF2E7D32) : const Color(0xFFE65100))
                          : HomeColors.accentText,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  );
                },
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
          if (sale.notes != null && sale.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: HomeColors.cardElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HomeColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 15, color: HomeColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Note: ${sale.notes!}',
                      style: TextStyle(
                        color: HomeColors.textSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Utang Payment History Card (Debt Collection with Receipt)
// ---------------------------------------------------------------------
class _UtangPaymentHistoryCard extends StatelessWidget {
  final UtangPaymentWithRecord paymentWithRecord;
  const _UtangPaymentHistoryCard({required this.paymentWithRecord});

  @override
  Widget build(BuildContext context) {
    final payment = paymentWithRecord.payment;
    final record = paymentWithRecord.record;
    final isSettled = record.isFullyPaid;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF81C784).withValues(alpha: 0.45),
        ),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date & Collection Tag on left, Amount on right
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
                        formatDateTime(payment.paidAt),
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
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payments_rounded, size: 11, color: Color(0xFF2E7D32)),
                          SizedBox(width: 3),
                          Text(
                            'Bayad Utang · Debt Collection',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+₱${payment.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Customer Name & Bal on left, Receipt button on right
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
                            record.customerName,
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
                      isSettled
                          ? 'Debt fully settled (₱0.00 bal)'
                          : 'Remaining debt: ₱${record.balance.toStringAsFixed(2)} (Total was ₱${record.totalAmount.toStringAsFixed(2)})',
                      style: TextStyle(
                        color: isSettled ? const Color(0xFF2E7D32) : HomeColors.textSecondary,
                        fontSize: 11,
                        fontWeight: isSettled ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  final prevBal = record.balance + payment.amount;
                  UtangPaymentReceiptDialog.show(
                    context,
                    record: record,
                    payment: payment,
                    previousBalance: prevBal,
                  );
                },
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
            ],
          ),

          if (payment.note != null && payment.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: HomeColors.cardElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HomeColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 15, color: HomeColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Payment note: ${payment.note!}',
                      style: TextStyle(
                        color: HomeColors.textSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
