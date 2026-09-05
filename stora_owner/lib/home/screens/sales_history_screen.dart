import 'package:flutter/material.dart';
import '../../stora_login/stora_login.dart';
import '../models/sale.dart';
import '../stores/sales_store.dart';
import '../theme/home_colors.dart';
import '../utils/date_utils.dart';

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
      title: const Text('Delete all sales?', style: TextStyle(color: Colors.white)),
      content: const Text(
          'This permanently removes your entire sales history. This can\'t be undone.',
          style: TextStyle(color: AppColors.label)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
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

class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SalesStore.instance,
      builder: (context, _) {
        final sales = SalesStore.instance.sales; // newest first
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
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
                        child: Text('Sales History',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      if (sales.isNotEmpty)
                        IconButton(
                          onPressed: () => confirmClearAllSales(context),
                          icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
                          style: IconButton.styleFrom(
                            backgroundColor: HomeColors.cardBackground,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _HistorySummaryCard(sales: sales),
                ),
                Expanded(
                  child: sales.isEmpty
                      ? Center(
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
                                child: const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.purpleLight),
                              ),
                              const SizedBox(height: 16),
                              const Text('No sales recorded yet',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              const Text('Complete a sale from POS to see it here.',
                                  style: TextStyle(color: AppColors.label, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: sales.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _SaleCard(sale: sales[i]),
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

class _HistorySummaryCard extends StatelessWidget {
  final List<Sale> sales;
  const _HistorySummaryCard({required this.sales});

  @override
  Widget build(BuildContext context) {
    final total = sales.fold(0.0, (sum, s) => sum + s.total);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeColors.cardBorder),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.label),
                  SizedBox(width: 5),
                  Text('All-time revenue', style: TextStyle(color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Text('₱${total.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          Container(
            height: 36,
            width: 1,
            color: HomeColors.cardBorder,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_rounded, size: 14, color: AppColors.purpleLight),
                  SizedBox(width: 5),
                  Text('Total sales', style: TextStyle(color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Text('${sales.length}',
                  style: const TextStyle(color: AppColors.purpleLight, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
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
        title: const Text('Delete sale?', style: TextStyle(color: Colors.white)),
        content: const Text(
            'This removes the sale from your history. It will not add the items back to stock.',
            style: TextStyle(color: AppColors.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.fieldBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HomeColors.cardBorder),
                ),
                child: Text(formatDateTime(sale.date),
                    style: const TextStyle(color: AppColors.label, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              Row(
                children: [
                  Text('₱${sale.total.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.purpleLight, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: HomeColors.dangerBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: HomeColors.cardBorder, height: 1),
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
                              color: AppColors.fieldBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('x${item.quantity}',
                                style: const TextStyle(color: AppColors.purpleLight, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item.product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    Text('₱${item.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
