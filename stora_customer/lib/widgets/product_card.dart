import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'product_image.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../storage/hidden_products_store.dart';
import '../theme/app_theme.dart';
import 'product_report_dialog.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  void _showProductOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isReported = HiddenProductsStore.instance.isReported(product.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.cardBorder),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.storeName != null && product.storeName!.isNotEmpty)
                          Text(
                            product.storeName!,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          product.name,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isReported
                        ? AppColors.cardElevated
                        : AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isReported ? Icons.check_circle_outline_rounded : Icons.flag_rounded,
                    color: isReported ? AppColors.textMuted : AppColors.danger,
                    size: 20,
                  ),
                ),
                title: Text(
                  isReported ? 'Product Reported (24h Cooldown)' : 'Report Product',
                  style: TextStyle(
                    color: isReported ? AppColors.textMuted : AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  isReported
                      ? 'You have already submitted a report for this product today.'
                      : 'Flag inappropriate content, misleading details, or counterfeit items',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  if (isReported) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('You have already reported this product in the last 24 hours.'),
                        backgroundColor: AppColors.cardElevated,
                      ),
                    );
                  } else {
                    showProductReportDialog(context: context, product: product);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCartQty = cart.getQuantity(product.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: inCartQty > 0 ? AppColors.primary.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
          width: inCartQty > 0 ? 1.5 : 1,
        ),
        boxShadow: inCartQty > 0
            ? AppColors.glowShadow(AppColors.primary, opacity: 0.2)
            : AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showProductOptions(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Badges
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'product-image-${product.id}',
                    child: ProductImage(
                      imageData: product.image,
                      categoryName: product.categoryName,
                    ),
                  ),
                  // Category Badge
                  if (product.categoryName.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorder, width: 0.8),
                        ),
                        child: Text(
                          product.categoryName,
                          style: TextStyle(
                            color: AppColors.accentText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  // Stock Status Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: (product.isOutOfStock
                                ? AppColors.dangerBg
                                : (product.isLowStock ? AppColors.warningBg : AppColors.successBg))
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: product.isOutOfStock
                              ? AppColors.danger
                              : (product.isLowStock ? AppColors.warning : AppColors.success),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        product.isOutOfStock
                            ? 'Out of stock'
                            : (product.isLowStock ? '${product.stock} left' : '${product.stock} in stock'),
                        style: TextStyle(
                          color: product.isOutOfStock
                              ? AppColors.danger
                              : (product.isLowStock ? AppColors.warningText : AppColors.successText),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Details & Actions
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.storeName != null && product.storeName!.isNotEmpty)
                          Text(
                            product.storeName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              product.formattedPrice,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (product.isOutOfStock)
                          const SizedBox()
                        else if (inCartQty > 0)
                          Container(
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => cart.decrement(product.id),
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Icon(Icons.remove, size: 13, color: AppColors.textPrimary),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '$inCartQty',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => cart.increment(product.id),
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(15)),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Icon(Icons.add, size: 13, color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Material(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              key: ValueKey('product_add_button_${product.id}'),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                final added = cart.addItem(product, 1);
                                if (!added && cart.isNotEmpty && cart.storeId != product.ownerId) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Your cart contains items from another store. Clear cart first?',
                                      ),
                                      action: SnackBarAction(
                                        label: 'Clear & Add',
                                        onPressed: () {
                                          cart.clear();
                                          cart.addItem(product, 1);
                                        },
                                      ),
                                    ),
                                  );
                                } else if (!added) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Maximum available stock reached.'),
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded, size: 15, color: Colors.white),
                                    SizedBox(width: 2),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
