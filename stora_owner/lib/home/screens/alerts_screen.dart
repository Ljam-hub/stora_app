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

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        InventoryStore.instance,
        StoreStatusStore.instance,
        ThemeModeController.instance,
      ]),
      builder: (context, _) {
        final lowStock = InventoryStore.instance.lowStock;
        final hasLocationIssue = !StoreStatusStore.instance.hasValidLocation;
        final totalAlerts = lowStock.length + (hasLocationIssue ? 1 : 0);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                            color: totalAlerts > 0 ? HomeColors.dangerBg : HomeColors.successBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            totalAlerts > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                            color: totalAlerts > 0 ? AppColors.error : HomeColors.successText,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Alerts',
                          style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    if (totalAlerts > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HomeColors.dangerBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$totalAlerts alert${totalAlerts > 1 ? 's' : ''}',
                          style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: totalAlerts == 0
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
                                child: const Icon(Icons.verified_user_rounded, size: 52, color: HomeColors.successText),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'All systems healthy',
                                style: TextStyle(color: HomeColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Store location is configured and no items are low in stock.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: (hasLocationIssue ? 1 : 0) + lowStock.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            if (hasLocationIssue && i == 0) {
                              return const _LocationAlertCard(key: ValueKey('location_alert'));
                            }
                            final productIndex = hasLocationIssue ? i - 1 : i;
                            return _AlertCard(
                              key: ValueKey(lowStock[productIndex].id),
                              product: lowStock[productIndex],
                            );
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
        border: Border.all(color: isOut ? AppColors.error.withValues(alpha: 0.4) : HomeColors.warningText.withValues(alpha: 0.35)),
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
                  style: TextStyle(color: HomeColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(child: Text(product.category, overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(color: HomeColors.textSecondary, fontSize: 12))),
                    const SizedBox(width: 6),
                    Text('• ₱${product.price.toStringAsFixed(2)}',
                        style: TextStyle(color: HomeColors.accentText, fontSize: 12, fontWeight: FontWeight.w700)),
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
                  style: TextStyle(color: HomeColors.accentText, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

