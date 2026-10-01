import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../cart/cart_screen.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../storage/hidden_products_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/navigation_guard.dart';
import '../../widgets/cross_store_cart_dialog.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/product_image.dart';
import '../../widgets/product_report_dialog.dart';
import '../chat/customer_chat_screen.dart';

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
  bool _isActionInProgress = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final cart = context.watch<CartProvider>();
    final maxAvailable = product.stock - cart.getQuantity(product.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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

              // Hero Image with Modern Studio Stage
              Container(
                height: 250,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'product-image-${product.id}',
                      child: ProductImage(
                        imageData: product.image,
                        categoryName: product.categoryName,
                        borderRadius: BorderRadius.circular(22),
                        iconSize: 52,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.flag_outlined, color: Colors.white, size: 18),
                          tooltip: 'Report Product',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            if (HiddenProductsStore.instance.isReported(product.id)) {
                              ScaffoldMessenger.of(nav.context).showSnackBar(
                                SnackBar(
                                  content: const Text('You have already reported this product in the last 24 hours.'),
                                  backgroundColor: AppColors.cardElevated,
                                ),
                              );
                              return;
                            }
                            showProductReportDialog(context: nav.context, product: product);
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category & Store Meta Row
                    if (product.categoryName.isNotEmpty || (product.storeName != null && product.storeName!.isNotEmpty)) ...[
                      Row(
                        children: [
                          if (product.categoryName.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                product.categoryName.toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.accentText,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (product.storeName != null && product.storeName!.isNotEmpty)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: AppColors.cardElevated,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.storefront_rounded, size: 13, color: AppColors.textSecondary),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        product.storeName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Product Name
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Price & Stock
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        Builder(
                          builder: (context) {
                            final Color badgeBg;
                            final Color dotColor;
                            final Color textColor;
                            final Color borderColor;
                            final String stockLabel;

                            if (product.isOutOfStock) {
                              badgeBg = const Color(0xFF3B1219);
                              dotColor = const Color(0xFFFF4D4F);
                              textColor = const Color(0xFFFF7875);
                              borderColor = const Color(0xFFFF4D4F).withValues(alpha: 0.6);
                              stockLabel = 'Out of stock';
                            } else if (product.isLowStock) {
                              badgeBg = const Color(0xFF332008);
                              dotColor = const Color(0xFFFFA940);
                              textColor = const Color(0xFFFFD591);
                              borderColor = const Color(0xFFFA8C16).withValues(alpha: 0.6);
                              stockLabel = 'Only ${product.stock} left';
                            } else {
                              badgeBg = const Color(0xFF093B24);
                              dotColor = const Color(0xFF49E282);
                              textColor = Colors.white;
                              borderColor = const Color(0xFF36CF78).withValues(alpha: 0.6);
                              stockLabel = '${product.stock} in stock';
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: dotColor.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: dotColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: dotColor.withValues(alpha: 0.8),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    stockLabel,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    if (product.bio.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'PRODUCT DETAILS',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.bio,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Quantity Stepper (if in stock)
                    if (!product.isOutOfStock) ...[
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quantity',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                maxAvailable > 0 ? '$maxAvailable available' : 'Max quantity reached',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorderLight),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                                    onTap: _quantity > 1
                                        ? () {
                                            HapticFeedback.selectionClick();
                                            setState(() => _quantity--);
                                          }
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(9),
                                      child: Icon(
                                        Icons.remove_rounded,
                                        color: _quantity > 1 ? AppColors.textPrimary : AppColors.textMuted,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 36),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$_quantity',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                                    onTap: _quantity < maxAvailable
                                        ? () {
                                            HapticFeedback.selectionClick();
                                            setState(() => _quantity++);
                                          }
                                        : () {
                                            HapticFeedback.lightImpact();
                                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      maxAvailable <= 0
                                                          ? 'This item is out of stock'
                                                          : 'Only $maxAvailable item${maxAvailable == 1 ? "" : "s"} available in stock',
                                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                                duration: const Duration(milliseconds: 1500),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.all(9),
                                      child: Icon(
                                        Icons.add_rounded,
                                        color: _quantity < maxAvailable ? AppColors.textPrimary : AppColors.textMuted.withValues(alpha: 0.5),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Total & Add to Cart Button + Chat
                    if (!product.isOutOfStock)
                      Row(
                        children: [
                          if (product.ownerId != null) ...[
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.cardElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _isActionInProgress
                                      ? null
                                      : () {
                                          if (_isActionInProgress) return;
                                          setState(() => _isActionInProgress = true);
                                          final navigator = Navigator.of(context);
                                          navigator.pop();
                                          NavigationGuard.pushSafely(
                                            navigator.context,
                                            MaterialPageRoute(
                                              builder: (_) => CustomerChatScreen(
                                                storeOwnerId: product.ownerId!,
                                                storeName: product.storeName ?? 'Store Owner',
                                                storeAvatarUrl: product.storeAvatarUrl,
                                              ),
                                            ),
                                          );
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.accentText),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Chat',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: GradientButton(
                              text: 'Add to Cart • ₱${(product.price * _quantity).toStringAsFixed(2)}',
                              icon: Icons.add_shopping_cart,
                              onPressed: _isActionInProgress
                                  ? null
                                  : () async {
                                      if (_isActionInProgress) return;
                                      HapticFeedback.mediumImpact();
                                      setState(() => _isActionInProgress = true);
                                      final added = cart.addItem(product, _quantity);
                                      if (added) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.check_circle_rounded, color: AppColors.secondaryLight, size: 20),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    'Added $_quantity "${product.name}" to cart',
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
                                      } else if (cart.isNotEmpty && cart.storeId != product.ownerId) {
                                        setState(() => _isActionInProgress = false);
                                        final navigator = Navigator.of(context);
                                        final replaced = await showCrossStoreCartDialog(
                                          context: context,
                                          cart: cart,
                                          product: product,
                                          quantity: _quantity,
                                        );
                                        if (replaced && mounted) {
                                          navigator.pop();
                                        }
                                      } else {
                                        setState(() => _isActionInProgress = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to add item to cart.'),
                                            backgroundColor: AppColors.danger,
                                            duration: Duration(milliseconds: 1500),
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardElevated,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Currently Unavailable',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      if (product.ownerId != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isActionInProgress
                              ? null
                              : () {
                                  if (_isActionInProgress) return;
                                  setState(() => _isActionInProgress = true);
                                  final navigator = Navigator.of(context);
                                  navigator.pop();
                                  NavigationGuard.pushSafely(
                                    navigator.context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomerChatScreen(
                                        storeOwnerId: product.ownerId!,
                                        storeName: product.storeName ?? 'Store Owner',
                                        storeAvatarUrl: product.storeAvatarUrl,
                                      ),
                                    ),
                                  );
                                },
                          icon: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.accentText),
                          label: Text(
                            'Chat',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 14),
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            if (HiddenProductsStore.instance.isReported(product.id)) {
                              ScaffoldMessenger.of(nav.context).showSnackBar(
                                SnackBar(
                                  content: const Text('You have already reported this product in the last 24 hours.'),
                                  backgroundColor: AppColors.cardElevated,
                                ),
                              );
                              return;
                            }
                            showProductReportDialog(context: nav.context, product: product);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag_outlined, size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Report this product',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
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
