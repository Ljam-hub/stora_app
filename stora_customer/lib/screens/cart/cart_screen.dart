import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_item_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_button.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback? onStartShopping;
  final VoidCallback? onOrderPlaced;

  const CartScreen({
    super.key,
    this.onStartShopping,
    this.onOrderPlaced,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isNavigatingToCheckout = false;

  Future<void> _detectLocation(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Locating your current address...'),
          ],
        ),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await LocationService.instance.detectCurrentAddress();
    messenger.hideCurrentSnackBar();

    if (result.success && result.address != null && result.address!.isNotEmpty) {
      await auth.saveDeliveryDetails(address: result.address!);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Delivery address set: ${result.address!}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Unable to detect location. Please check GPS permissions.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CustomerThemeController>();
    final cart = context.watch<CartProvider>();
    final catalog = context.watch<CatalogProvider>();
    final auth = context.watch<AuthProvider>();
    final savedAddress = auth.savedAddress;

    final storeOwnerId = cart.storeId;
    if (storeOwnerId != null && catalog.stores.isEmpty && !catalog.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        catalog.fetchStores();
      });
    }
    final currentStore = catalog.stores.where((s) => s.id == storeOwnerId).firstOrNull ??
        (catalog.selectedStore?.id == storeOwnerId ? catalog.selectedStore : null);
    final isStoreClosed = currentStore != null && !currentStore.isOpen;

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
                        child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
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
              onButtonPressed: widget.onStartShopping,
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
                          style: TextStyle(
                            color: AppColors.accentText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Delivery location banner with auto-locate icon
                Container(
                  margin: EdgeInsets.fromLTRB(
                    16,
                    (cart.storeName != null && cart.storeName!.isNotEmpty) ? 0 : 8,
                    16,
                    8,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardElevated.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorderLight),
                  ),
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Detect current location',
                        child: InkWell(
                          onTap: () => _detectLocation(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => _detectLocation(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deliver To:',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                (savedAddress != null && savedAddress.isNotEmpty)
                                    ? savedAddress
                                    : 'Tap location icon to detect current address',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: (savedAddress != null && savedAddress.isNotEmpty)
                                      ? AppColors.textPrimary
                                      : AppColors.accentText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.my_location_rounded, size: 18, color: AppColors.primary),
                        tooltip: 'Locate me now',
                        onPressed: () => _detectLocation(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                  decoration: BoxDecoration(
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
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            ),
                            Text(
                              cart.formattedTotal,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (isStoreClosed)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.store_mall_directory_outlined, color: AppColors.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This store is currently closed. Checkout is paused until the store reopens.',
                                    style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        GradientButton(
                          text: isStoreClosed ? 'Store is Currently Closed' : 'Proceed to Checkout',
                          icon: isStoreClosed ? Icons.lock_outline_rounded : Icons.arrow_forward_rounded,
                          isLoading: _isNavigatingToCheckout,
                          onPressed: (isStoreClosed || _isNavigatingToCheckout)
                              ? null
                              : () async {
                                  if (_isNavigatingToCheckout) return;
                                  setState(() => _isNavigatingToCheckout = true);
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CheckoutScreen(
                                        onOrderPlaced: widget.onOrderPlaced,
                                      ),
                                    ),
                                  );
                                  if (mounted) {
                                    setState(() => _isNavigatingToCheckout = false);
                                  }
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
