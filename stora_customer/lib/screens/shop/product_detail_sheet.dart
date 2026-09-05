import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class ProductDetailSheet extends StatefulWidget {
  final ProductModel product;

  const ProductDetailSheet({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  int _quantity = 1;

  Widget _buildProductImage(ProductModel product) {
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
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primaryLight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cart = context.watch<CartProvider>();
    final maxAvailable = product.stock;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Hero Image
              SizedBox(
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildProductImage(product),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store & Category Tags
                    Row(
                      children: [
                        if (product.storeName != null && product.storeName!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  product.storeName!,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (product.categoryName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              product.categoryName,
                              style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Product Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Price & Stock
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: product.isOutOfStock
                                ? AppColors.dangerBg
                                : (product.isLowStock ? AppColors.warningBg : AppColors.successBg),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: product.isOutOfStock
                                  ? AppColors.danger
                                  : (product.isLowStock ? AppColors.warning : AppColors.success),
                            ),
                          ),
                          child: Text(
                            product.isOutOfStock
                                ? 'Out of stock'
                                : '${product.stock} in stock',
                            style: TextStyle(
                              color: product.isOutOfStock
                                  ? AppColors.danger
                                  : (product.isLowStock ? AppColors.warning : AppColors.success),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quantity Stepper (if in stock)
                    if (!product.isOutOfStock) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quantity',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorderLight),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, color: Colors.white, size: 18),
                                  onPressed: _quantity > 1
                                      ? () => setState(() => _quantity--)
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '$_quantity',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                  onPressed: _quantity < maxAvailable
                                      ? () => setState(() => _quantity++)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Total & Add to Cart Button
                    if (!product.isOutOfStock)
                      GradientButton(
                        text: 'Add to Cart • ₱${(product.price * _quantity).toStringAsFixed(2)}',
                        icon: Icons.add_shopping_cart,
                        onPressed: () {
                          final added = cart.addItem(product, _quantity);
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
                                    cart.addItem(product, _quantity);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            );
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added $_quantity "${product.name}" to cart'),
                                backgroundColor: AppColors.successBg,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardElevated,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'Currently Unavailable',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
