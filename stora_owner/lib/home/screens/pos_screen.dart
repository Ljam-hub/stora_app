import 'package:flutter/material.dart';
import '../../stora_login/stora_login.dart';
import '../../data/api/api_client.dart';
import '../../data/stores/account_status_store.dart';
import 'barcode_scanner_screen.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../stores/cart_store.dart';
import '../stores/inventory_store.dart';
import '../stores/sales_store.dart';
import '../theme/home_colors.dart';
import '../theme/theme_mode_controller.dart';
import '../widgets/category_filter_row.dart';
import '../widgets/product_image_widget.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/stock_step_button.dart';

// ---------------------------------------------------------------------
// POS / Sales — search-or-scan + virtual cart + checkout. Search
// results render as horizontal quick-pick cards; tapping a card adds
// it to the cart. Category filtering here shares the exact same
// CategoryFilterRow (and CategoryStore) as Inventory, so hide/delete
// applied on either screen shows up on both.
// ---------------------------------------------------------------------
class PosScreen extends StatefulWidget {
  /// True when pushed on top of the shell (e.g. from the Dashboard's
  /// "New Sale" button) so we can show a back arrow.
  final bool isStandalone;
  const PosScreen({super.key, this.isStandalone = false});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

void confirmClearCart(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: HomeColors.cardBackground,
      title: Text('Clear cart?', style: TextStyle(color: HomeColors.textPrimary)),
      content: Text('This removes every item from the cart. Stock is not affected until checkout.',
          style: TextStyle(color: HomeColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            CartStore.instance.clear();
            Navigator.of(ctx).pop();
          },
          child: const Text('Clear', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';
  bool _isCheckingOut = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    final inventory = InventoryStore.instance;
    final accountStatus = AccountStatusStore.instance.status;
    final isPremium = accountStatus.isPremium;

    // 1. Search in local inventory products
    Product? matched;
    for (int i = 0; i < inventory.products.length; i++) {
      final p = inventory.products[i];
      if ((p.barcode != null && p.barcode!.trim().toLowerCase() == code.toLowerCase()) ||
          p.id == code ||
          p.name.trim().toLowerCase() == code.toLowerCase()) {
        final freeLimit = accountStatus.productLimit > 0 ? accountStatus.productLimit : 20;
        if (!isPremium && i >= freeLimit) {
          if (!mounted) return;
          showStoraSnackBar(
            context,
            '"${p.name}" is locked. Upgrade to Premium to unlock all items.',
          );
          return;
        }
        matched = p;
        break;
      }
    }

    // 2. If not found locally, try remote barcode lookup if online
    if (matched == null) {
      try {
        final remote = await ApiClient.instance.lookupBarcode(code);
        if (remote != null) {
          matched = Product.fromJson(remote);
        }
      } catch (_) {}
    }

    if (matched != null) {
      final product = matched;
      if (product.stock <= 0) {
        if (!mounted) return;
        showStoraSnackBar(context, '"${product.name}" is out of stock');
        return;
      }
      final inCart = CartStore.instance.items.firstWhere(
        (it) => it.product.id == product.id,
        orElse: () => CartItem(product: product, quantity: 0),
      );
      if (inCart.quantity >= product.stock) {
        if (!mounted) return;
        showStoraSnackBar(
          context,
          'Maximum available stock for "${product.name}" (${product.stock}) already in cart',
        );
        return;
      }
      CartStore.instance.add(product);
      _searchController.clear();
      if (mounted) {
        setState(() => _query = '');
        showStoraSnackBar(context, 'Added "${product.name}" to cart', isError: false);
      }
    } else {
      if (!mounted) return;
      showStoraSnackBar(context, 'No product found with barcode "$code"');
    }
  }

  Future<void> _onScan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && code.isNotEmpty) {
      await _handleBarcode(code);
    }
  }

  Future<void> _checkout() async {
    if (_isCheckingOut) return;
    final cart = CartStore.instance;
    if (cart.items.isEmpty) {
      showStoraSnackBar(context, 'Your cart is empty');
      return;
    }
    setState(() => _isCheckingOut = true);
    final items = List<CartItem>.from(cart.items);
    final total = cart.total;
    Sale? recordedSale;
    try {
      recordedSale = await SalesStore.instance.recordSale(items, total);
      cart.clear();
      if (!mounted) return;
      if (recordedSale.id.startsWith('local-')) {
        showStoraSnackBar(context, 'Sale recorded offline', isError: false);
      }
      ReceiptDialog.show(context, recordedSale);
    } on ApiException catch (e) {
      if (!mounted) return;
      showStoraSnackBar(context, e.message);
    } catch (e) {
      if (!mounted) return;
      showStoraSnackBar(context, 'Failed to complete sale: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        InventoryStore.instance,
        CartStore.instance,
        AccountStatusStore.instance,
        ThemeModeController.instance,
      ]),
      builder: (context, _) {
        final categoryFiltered = _selectedCategory.toLowerCase() == 'all'
            ? InventoryStore.instance.products
            : InventoryStore.instance.products
                .where((p) => p.category.toLowerCase() == _selectedCategory.toLowerCase())
                .toList();
        // Typing a search narrows further; browsing a category or 'All'
        // shows all matching products directly.
        final queryLower = _query.trim().toLowerCase();
        final results = queryLower.isEmpty
            ? categoryFiltered
            : categoryFiltered.where((p) {
                final nameMatch = p.name.toLowerCase().contains(queryLower);
                final barcodeMatch = p.barcode != null && p.barcode!.toLowerCase().contains(queryLower);
                return nameMatch || barcodeMatch;
              }).toList();
        final cart = CartStore.instance;

        final body = Column(
          children: [
            if (widget.isStandalone)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.chevron_left, color: HomeColors.textPrimary),
                      style: IconButton.styleFrom(
                        backgroundColor: HomeColors.cardBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    Expanded(
                      child: Text('New Sale',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (v) => _handleBarcode(v),
                style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search Product or Scan Barcode',
                  hintStyle: TextStyle(color: HomeColors.textSecondary),
                  filled: true,
                  fillColor: HomeColors.cardBackground,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_query.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.label, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        else
                          const Icon(Icons.search, color: AppColors.label, size: 18),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.purpleLight, size: 20),
                          tooltip: 'Scan Barcode',
                          onPressed: _onScan,
                        ),
                      ],
                    ),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            CategoryFilterRow(
              selected: _selectedCategory,
              onSelect: (cat) => setState(() => _selectedCategory = cat),
            ),
            if (results.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                // A little taller than the card's natural content height
                // as a buffer; the card itself uses Expanded + FittedBox
                // internally so it never overflows even if this buffer
                // isn't quite enough on a given platform's text scale.
                height: 124,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final p = results[i];
                    final freeLimit = AccountStatusStore.instance.productLimit > 0
                        ? AccountStatusStore.instance.productLimit
                        : 20;
                    final allIdx = InventoryStore.instance.products.indexOf(p);
                    final isLocked = !AccountStatusStore.instance.isPremium &&
                        (allIdx >= freeLimit || (allIdx == -1 && i >= freeLimit));
                    return _PosProductCard(
                      product: p,
                      isLocked: isLocked,
                      onTap: () {
                        if (isLocked) {
                          showStoraSnackBar(
                            context,
                            '"${p.name}" is locked. Upgrade to Premium to unlock all items.',
                          );
                          return;
                        }
                        if (p.stock <= 0) {
                          showStoraSnackBar(context, '"${p.name}" is out of stock');
                          return;
                        }
                        final inCart = cart.items.firstWhere(
                          (it) => it.product.id == p.id,
                          orElse: () => CartItem(product: p, quantity: 0),
                        );
                        if (inCart.quantity >= p.stock) {
                          showStoraSnackBar(
                            context,
                            'Maximum available stock for "${p.name}" (${p.stock}) already in cart',
                          );
                          return;
                        }
                        cart.add(p);
                        _searchController.clear();
                        setState(() => _query = '');
                        FocusScope.of(context).unfocus();
                      },
                    );
                  },
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Virtual Cart',
                      style: TextStyle(color: AppColors.label, fontSize: 13, fontWeight: FontWeight.w700)),
                  if (cart.items.isNotEmpty)
                    GestureDetector(
                      onTap: () => confirmClearCart(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.delete_sweep_outlined, size: 15, color: AppColors.error),
                          SizedBox(width: 4),
                          Text('Clear all',
                              style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: cart.items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: HomeColors.cardElevated,
                                shape: BoxShape.circle,
                                border: Border.all(color: HomeColors.cardBorder),
                              ),
                              child: const Icon(Icons.shopping_bag_outlined, size: 40, color: AppColors.purpleLight),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Virtual cart is empty',
                              style: TextStyle(color: HomeColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Search above or scan a barcode to add products directly.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _CartRow(item: cart.items[i]),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: HomeColors.navBackground,
                border: Border(top: BorderSide(color: HomeColors.cardBorder)),
                boxShadow: HomeColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('Total Amount', style: TextStyle(color: HomeColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          if (cart.items.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: HomeColors.cardElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: HomeColors.cardBorder),
                              ),
                              child: Text(
                                '${cart.items.fold(0, (sum, i) => sum + i.quantity)} items',
                                style: TextStyle(color: HomeColors.accentText, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      Text('₱${cart.total.toStringAsFixed(2)}',
                          style: TextStyle(color: HomeColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StoraGradientButton(
                    label: 'CHECKOUT',
                    isLoading: _isCheckingOut,
                    onPressed: (_isCheckingOut || cart.items.isEmpty) ? null : _checkout,
                  ),
                ],
              ),
            ),
          ],
        );

        return widget.isStandalone
            ? Scaffold(backgroundColor: HomeColors.background, body: SafeArea(child: body))
            : SafeArea(child: body);
      },
    );
  }
}

class _PosProductCard extends StatelessWidget {
  final Product product;
  final bool isLocked;
  final VoidCallback onTap;
  const _PosProductCard({
    required this.product,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stock <= 0;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isLocked ? 0.45 : (isOutOfStock ? 0.6 : 1.0),
        child: Container(
          width: 116,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: HomeColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOutOfStock ? AppColors.error.withValues(alpha: 0.3) : HomeColors.cardBorder,
            ),
            boxShadow: HomeColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ProductImageWidget(
                        imageBytes: product.imageBytes,
                        productName: product.name,
                        category: product.category,
                        borderRadius: BorderRadius.circular(10),
                        iconSize: 20,
                      ),
                    ),
                    if (isLocked)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 12),
                        ),
                      )
                    else if (isOutOfStock)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: HomeColors.dangerBg.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NO STOCK',
                            style: TextStyle(color: AppColors.error, fontSize: 7, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: HomeColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('₱${product.price.toStringAsFixed(2)}',
                        style: TextStyle(color: HomeColors.accentText, fontSize: 11, fontWeight: FontWeight.w800)),
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

class _CartRow extends StatelessWidget {
  final CartItem item;
  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.cardBorder),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Row(
        children: [
          ProductImageWidget(
            imageBytes: item.product.imageBytes,
            productName: item.product.name,
            category: item.product.category,
            width: 36,
            height: 36,
            borderRadius: BorderRadius.circular(10),
            iconSize: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: HomeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('₱${item.product.price.toStringAsFixed(2)} · subtotal: ₱${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.label, fontSize: 11)),
              ],
            ),
          ),
          StockStepButton(
            icon: Icons.remove,
            onTap: () => CartStore.instance.decrementQty(item.product.id),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          StockStepButton(
            icon: Icons.add,
            onTap: () {
              if (item.quantity >= item.product.stock) {
                showStoraSnackBar(
                  context,
                  'Maximum available stock for "${item.product.name}" (${item.product.stock}) reached',
                );
                return;
              }
              CartStore.instance.incrementQty(item.product.id);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => CartStore.instance.remove(item.product.id),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: HomeColors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
