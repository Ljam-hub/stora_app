import 'package:flutter/material.dart';
import '../../stora_login/stora_login.dart';
import '../models/product.dart';
import '../stores/inventory_store.dart';
import '../stores/store_status_store.dart';
import '../theme/home_colors.dart';
import '../theme/theme_mode_controller.dart';
import '../widgets/product_image_widget.dart';
import 'add_edit_product_screen.dart';
import 'set_store_location_screen.dart';

enum AlertsFilter { all, lowStock, inStock }

class AlertsScreen extends StatefulWidget {
  final AlertsFilter initialFilter;
  const AlertsScreen({super.key, this.initialFilter = AlertsFilter.all});

  static final ValueNotifier<AlertsFilter> activeFilter =
      ValueNotifier<AlertsFilter>(AlertsFilter.all);

  static void setFilter(AlertsFilter filter) {
    activeFilter.value = filter;
  }

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != AlertsFilter.all) {
      AlertsScreen.activeFilter.value = widget.initialFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        InventoryStore.instance,
        StoreStatusStore.instance,
        ThemeModeController.instance,
        AlertsScreen.activeFilter,
      ]),
      builder: (context, _) {
        final store = InventoryStore.instance;
        final lowStock = store.lowStock;
        final inStock = store.inStock;
        final hasLocationIssue = !StoreStatusStore.instance.hasValidLocation;
        final currentFilter = AlertsScreen.activeFilter.value;

        int totalCount;
        switch (currentFilter) {
          case AlertsFilter.lowStock:
            totalCount = lowStock.length + (hasLocationIssue ? 1 : 0);
            break;
          case AlertsFilter.inStock:
            totalCount = inStock.length;
            break;
          case AlertsFilter.all:
            totalCount = lowStock.length + inStock.length + (hasLocationIssue ? 1 : 0);
            break;
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: lowStock.isNotEmpty || hasLocationIssue
                                ? HomeColors.dangerBg
                                : HomeColors.successBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            lowStock.isNotEmpty || hasLocationIssue
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            color: lowStock.isNotEmpty || hasLocationIssue
                                ? AppColors.error
                                : HomeColors.successText,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Stock Alerts',
                          style: TextStyle(
                            color: HomeColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (lowStock.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HomeColors.dangerBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${lowStock.length} low stock',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Filter Tabs (Low Stock / In Stock / All)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterTab(
                        label: 'Low Stock',
                        count: lowStock.length,
                        badgeColor: AppColors.error,
                        isSelected: currentFilter == AlertsFilter.lowStock,
                        onTap: () => AlertsScreen.setFilter(AlertsFilter.lowStock),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        label: 'In Stock',
                        count: inStock.length,
                        badgeColor: HomeColors.successText,
                        isSelected: currentFilter == AlertsFilter.inStock,
                        onTap: () => AlertsScreen.setFilter(AlertsFilter.inStock),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        label: 'All Items',
                        count: lowStock.length + inStock.length,
                        isSelected: currentFilter == AlertsFilter.all,
                        onTap: () => AlertsScreen.setFilter(AlertsFilter.all),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: totalCount == 0
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: HomeColors.successBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: HomeColors.successText.withValues(alpha: 0.2)),
                                ),
                                child: const Icon(
                                  Icons.verified_user_rounded,
                                  size: 48,
                                  color: HomeColors.successText,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                currentFilter == AlertsFilter.lowStock
                                    ? 'No low stock alerts'
                                    : 'No items in this category',
                                style: TextStyle(
                                  color: HomeColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currentFilter == AlertsFilter.lowStock
                                    ? 'All products have 5 or more units in stock.'
                                    : 'Add or restock products to view them here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: totalCount,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            if (currentFilter == AlertsFilter.lowStock) {
                              if (hasLocationIssue && i == 0) {
                                return const _LocationAlertCard(key: ValueKey('location_alert'));
                              }
                              final productIndex = hasLocationIssue ? i - 1 : i;
                              return _AlertCard(
                                key: ValueKey(lowStock[productIndex].id),
                                product: lowStock[productIndex],
                              );
                            } else if (currentFilter == AlertsFilter.inStock) {
                              return _InStockCard(
                                key: ValueKey(inStock[i].id),
                                product: inStock[i],
                              );
                            } else {
                              // All Items filter
                              if (hasLocationIssue && i == 0) {
                                return const _LocationAlertCard(key: ValueKey('location_alert'));
                              }
                              final offset = hasLocationIssue ? 1 : 0;
                              final adjIndex = i - offset;
                              if (adjIndex < lowStock.length) {
                                return _AlertCard(
                                  key: ValueKey(lowStock[adjIndex].id),
                                  product: lowStock[adjIndex],
                                );
                              } else {
                                final inStockIndex = adjIndex - lowStock.length;
                                return _InStockCard(
                                  key: ValueKey(inStock[inStockIndex].id),
                                  product: inStock[inStockIndex],
                                );
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

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final Color? badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : HomeColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : HomeColors.cardBorder,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : HomeColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.22)
                    : (badgeColor ?? AppColors.primary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : (badgeColor ?? HomeColors.textPrimary),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationAlertCard extends StatefulWidget {
  const _LocationAlertCard({super.key});

  @override
  State<_LocationAlertCard> createState() => _LocationAlertCardState();
}

class _LocationAlertCardState extends State<_LocationAlertCard> {
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.warningBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeColors.warningText.withValues(alpha: 0.4), width: 1.2),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HomeColors.warningText.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_off_rounded, color: HomeColors.warningText, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Location Not Configured',
                      style: TextStyle(
                        color: HomeColors.warningText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hidden from customer map pins',
                      style: TextStyle(
                        color: HomeColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: HomeColors.warningText.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ACTION REQUIRED',
                  style: TextStyle(
                    color: HomeColors.warningText,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Customers in your area cannot see your store on their map screen until you pin your store address.',
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
              onPressed: () async {
                if (_isNavigating) return;
                setState(() => _isNavigating = true);
                try {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetStoreLocationScreen()),
                  );
                } finally {
                  if (mounted) setState(() => _isNavigating = false);
                }
              },
              icon: const Icon(Icons.pin_drop_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Set Location Pin Now',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeColors.warningText,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatefulWidget {
  final Product product;
  const _AlertCard({super.key, required this.product});

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _isOpening = false;

  void _handleRestock() async {
    if (_isOpening || !mounted) return;
    _isOpening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddEditProductScreen(existing: widget.product)),
      );
    } finally {
      if (mounted) {
        _isOpening = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isOut = product.stock <= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOut
              ? AppColors.error.withValues(alpha: 0.4)
              : HomeColors.warningText.withValues(alpha: 0.35),
        ),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProductImageWidget(
            imageBytes: product.imageBytes,
            imageUrl: product.imageUrl,
            productName: product.name,
            category: product.category,
            width: 44,
            height: 44,
            borderRadius: BorderRadius.circular(12),
            iconSize: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HomeColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        product.category,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(color: HomeColors.textSecondary, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ₱${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: HomeColors.accentText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOut ? HomeColors.dangerBg : HomeColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOut ? '0 left' : '${product.stock} left',
                  style: TextStyle(
                    color: isOut ? AppColors.error : HomeColors.warningText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _handleRestock,
                child: Text(
                  'Restock →',
                  style: TextStyle(
                    color: HomeColors.accentText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InStockCard extends StatelessWidget {
  final Product product;
  const _InStockCard({super.key, required this.product});

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProductImageWidget(
            imageBytes: product.imageBytes,
            imageUrl: product.imageUrl,
            productName: product.name,
            category: product.category,
            width: 44,
            height: 44,
            borderRadius: BorderRadius.circular(12),
            iconSize: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HomeColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        product.category,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(color: HomeColors.textSecondary, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ₱${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: HomeColors.accentText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: HomeColors.successBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${product.stock} in stock',
                  style: const TextStyle(
                    color: HomeColors.successText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AddEditProductScreen(existing: product)),
                  );
                },
                child: Text(
                  'Edit →',
                  style: TextStyle(
                    color: HomeColors.accentText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
