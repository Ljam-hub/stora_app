import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../screens/cart/cart_screen.dart';
import '../theme/app_theme.dart';

Future<bool> showCrossStoreCartDialog({
  required BuildContext context,
  required CartProvider cart,
  required ProductModel product,
  int quantity = 1,
}) async {
  final currentStore = cart.storeName ?? 'another store';
  final newStore = product.storeName ?? 'this store';

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Replace Cart Items?',
        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: Text(
        'Your cart already contains items from "$currentStore". Would you like to clear your cart and start a new order from "$newStore"?',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Clear & Add', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  if (confirm == true && context.mounted) {
    cart.clear();
    final added = cart.addItem(product, quantity);
    if (added && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.secondaryLight, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cart cleared & added $quantity "${product.name}"',
                  style: TextStyle(
                    color: CustomerThemeController.instance.isDarkMode ? Colors.white : const Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.successBg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.4)),
          ),
          action: SnackBarAction(
            label: 'View Cart',
            textColor: AppColors.primary,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return true;
    }
  }
  return false;
}
