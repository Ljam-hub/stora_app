import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_item_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_button.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  final VoidCallback? onStartShopping;
  final VoidCallback? onOrderPlaced;

  const CartScreen({
    super.key,
    this.onStartShopping,
    this.onOrderPlaced,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shopping Cart'),
        actions: [
          if (cart.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: AppColors.danger),
              label: const Text('Clear', style: TextStyle(color: AppColors.danger)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.cardBackground,
                    title: const Text('Clear Cart?'),
                    content: const Text('Are you sure you want to remove all items from your cart?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () {
                          cart.clear();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear All', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your Cart is Empty',
              message: 'Explore our catalog and add items from your favorite store to get started.',
              buttonText: 'Start Shopping',
              onButtonPressed: onStartShopping,
            )
          : Column(
              children: [
                // Store banner
                if (cart.storeName != null && cart.storeName!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Store: ${cart.storeName}',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Item List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return CartItemTile(
                        item: item,
                        onIncrement: () => cart.increment(item.product.id),
                        onDecrement: () => cart.decrement(item.product.id),
                        onRemove: () => cart.removeItem(item.product.id),
                      );
                    },
                  ),
                ),

                // Cart Summary & Checkout Button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.cardBackground,
                    border: Border(top: BorderSide(color: AppColors.cardBorder)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal (${cart.totalItemCount} items)',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            ),
                            Text(
                              cart.formattedTotal,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GradientButton(
                          text: 'Proceed to Checkout',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CheckoutScreen(
                                  onOrderPlaced: onOrderPlaced,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
