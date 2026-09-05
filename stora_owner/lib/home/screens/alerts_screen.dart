import 'package:flutter/material.dart';
import '../../stora_login/stora_login.dart';
import '../models/product.dart';
import '../stores/inventory_store.dart';
import '../theme/home_colors.dart';
import 'add_edit_product_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: InventoryStore.instance,
      builder: (context, _) {
        final lowStock = InventoryStore.instance.lowStock;
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
                            color: lowStock.isNotEmpty ? HomeColors.dangerBg : HomeColors.successBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            lowStock.isNotEmpty ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                            color: lowStock.isNotEmpty ? AppColors.error : HomeColors.successText,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Stock Alerts',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
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
                          '${lowStock.length} items low',
                          style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: lowStock.isEmpty
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
                              const Text(
                                'All inventory is healthy',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'No items are currently below 5 units in stock.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.label, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: lowStock.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _AlertCard(product: lowStock[i]),
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

class _AlertCard extends StatelessWidget {
  final Product product;
  const _AlertCard({required this.product});

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOut ? HomeColors.dangerBg : HomeColors.warningBg,
              borderRadius: BorderRadius.circular(12),
              image: product.imageBytes != null
                  ? DecorationImage(image: MemoryImage(product.imageBytes!), fit: BoxFit.cover)
                  : null,
            ),
            child: product.imageBytes == null
                ? Icon(
                    isOut ? Icons.remove_shopping_cart_outlined : Icons.inventory_2_outlined,
                    color: isOut ? AppColors.error : HomeColors.warningText,
                    size: 20,
                  )
                : null,
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
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(product.category, style: const TextStyle(color: AppColors.label, fontSize: 12)),
                    const SizedBox(width: 6),
                    Text('• ₱${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.purpleLight, fontSize: 12, fontWeight: FontWeight.w700)),
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddEditProductScreen(existing: product)),
                ),
                child: const Text(
                  'Restock →',
                  style: TextStyle(color: AppColors.purpleLight, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

