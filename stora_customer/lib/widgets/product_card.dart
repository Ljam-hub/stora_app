import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  Widget _buildProductImage() {
    if (product.image != null && product.image!.isNotEmpty) {
      try {
        if (product.image!.startsWith('data:image') || product.image!.length > 100) {
          final cleanBase64 = product.image!.contains(',')
              ? product.image!.split(',').last
              : product.image!;
          final bytes = base64Decode(cleanBase64);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
          );
        } else if (product.image!.startsWith('http')) {
          return Image.network(
            product.image!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
          );
        }
      } catch (_) {}
    }
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    return Container(
      color: AppColors.cardElevated,
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 40,
          color: AppColors.primaryLight.withValues(alpha: 0.5),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inCartQty > 0 ? AppColors.primary.withValues(alpha: 0.5) : AppColors.cardBorder,
          width: inCartQty > 0 ? 1.5 : 1,
        ),
        boxShadow: inCartQty > 0
            ? AppColors.glowShadow(AppColors.primary, opacity: 0.15)
            : AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Badges
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildProductImage(),
                  // Store or Category Chip
                  if (product.categoryName.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder, width: 0.8),
                        ),
                        child: Text(
                          product.categoryName,
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Stock Status
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: product.isOutOfStock
                            ? AppColors.dangerBg
                            : (product.isLowStock ? AppColors.warningBg : AppColors.successBg),
                        borderRadius: BorderRadius.circular(6),
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
                              : (product.isLowStock ? AppColors.warning : AppColors.success),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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
                padding: const EdgeInsets.all(10),
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
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.isOutOfStock)
                          const SizedBox()
                        else if (inCartQty > 0)
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => cart.decrement(product.id),
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.remove, size: 14, color: Colors.white),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    '$inCartQty',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => cart.increment(product.id),
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.add, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Material(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () {
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
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.add_shopping_cart, size: 16, color: Colors.black),
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
