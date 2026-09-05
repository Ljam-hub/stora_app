import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../theme/app_theme.dart';

class CartItemTile extends StatelessWidget {
  final CartItemModel item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  Widget _buildThumbnail() {
    if (item.product.image != null && item.product.image!.isNotEmpty) {
      try {
        if (item.product.image!.startsWith('data:image') || item.product.image!.length > 100) {
          final cleanBase64 = item.product.image!.contains(',')
              ? item.product.image!.split(',').last
              : item.product.image!;
          final bytes = base64Decode(cleanBase64);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(),
          );
        } else if (item.product.image!.startsWith('http')) {
          return Image.network(
            item.product.image!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(),
          );
        }
      } catch (_) {}
    }
    return _buildFallbackThumbnail();
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      color: AppColors.cardElevated,
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, size: 24, color: AppColors.primaryLight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Product Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 60,
              height: 60,
              child: _buildThumbnail(),
            ),
          ),
          const SizedBox(width: 12),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.product.formattedPrice,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subtotal: ${item.formattedSubtotal}',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Quantity Stepper & Remove
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onRemove,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: onDecrement,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.remove, size: 16, color: Colors.white),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: item.quantity < item.product.stock ? onIncrement : null,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: item.quantity < item.product.stock
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
