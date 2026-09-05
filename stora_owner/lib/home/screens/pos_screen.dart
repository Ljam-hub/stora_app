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
import '../widgets/category_filter_row.dart';
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
      title: const Text('Clear cart?', style: TextStyle(color: Colors.white)),
      content: const Text('This removes every item from the cart. Stock is not affected until checkout.',
          style: TextStyle(color: AppColors.label)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
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
        if (!isPremium && i >= 20) {
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
      if (matched.stock <= 0) {
        if (!mounted) return;
        showStoraSnackBar(context, '"${matched.name}" is out of stock');
        return;
      }
      CartStore.instance.add(matched);
      _searchController.clear();
      if (mounted) {
        setState(() => _query = '');
        showStoraSnackBar(context, 'Added "${matched.name}" to cart', isError: false);
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
    final cart = CartStore.instance;
    if (cart.items.isEmpty) {
      showStoraSnackBar(context, 'Your cart is empty');
      return;
    }
    final items = List<CartItem>.from(cart.items);
    final total = cart.total;
    Sale? recordedSale;
    try {
      recordedSale = await SalesStore.instance.recordSale(items, total);
      cart.clear();
      if (!mounted) return;
      ReceiptDialog.show(context, recordedSale);
    } on ApiException catch (e) {
      if (!mounted) return;
      showStoraSnackBar(context, e.message);
    } catch (_) {
      cart.clear();
      if (!mounted) return;
      showStoraSnackBar(context, 'Sale recorded offline', isError: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([InventoryStore.instance, CartStore.instance, AccountStatusStore.instance]),
      builder: (context, _) {
        final categoryFiltered = _selectedCategory == 'All'
            ? InventoryStore.instance.products
            : InventoryStore.instance.products.where((p) => p.category == _selectedCategory).toList();
        // Typing a search narrows further; picking a category with no
        // search text browses every product in that category directly.
        final results = _query.isEmpty
            ? (_selectedCategory == 'All' ? const <Product>[] : categoryFiltered)
            : categoryFiltered.where((p) => p.name.toLowerCase().contains(_query.toLowerCase())).toList();
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
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: HomeColors.cardBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const Expanded(
                      child: Text('New Sale',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
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
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search Product or Scan Barcode',
                  hintStyle: const TextStyle(color: AppColors.hint),
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
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final p = results[i];
                    return _PosProductCard(
                      product: p,
                      onTap: () {
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
                            const Text(
                              'Virtual cart is empty',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Search above or scan a barcode to add products directly.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.label, fontSize: 13),
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
                border: const Border(top: BorderSide(color: HomeColors.cardBorder)),
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
                          const Text('Total Amount', style: TextStyle(color: AppColors.label, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          if (cart.items.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.fieldBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: HomeColors.cardBorder),
                              ),
                              child: Text(
                                '${cart.items.fold(0, (sum, i) => sum + i.quantity)} items',
                                style: const TextStyle(color: AppColors.purpleLight, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      Text('₱${cart.total.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StoraGradientButton(label: 'CHECKOUT', onPressed: _checkout),
                ],
              ),
            ),
          ],
        );

        return widget.isStandalone
            ? Scaffold(backgroundColor: AppColors.background, body: SafeArea(child: body))
            : SafeArea(child: body);
      },
    );
  }
}

class _PosProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _PosProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: HomeColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HomeColors.cardBorder),
          boxShadow: HomeColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.fieldBackground,
                  borderRadius: BorderRadius.circular(10),
                  image: product.imageBytes != null
                      ? DecorationImage(image: MemoryImage(product.imageBytes!), fit: BoxFit.cover)
                      : null,
                ),
                child: product.imageBytes == null
                    ? const Icon(Icons.image_outlined, color: AppColors.hint, size: 20)
                    : null,
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
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('₱${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.purpleLight, fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.fieldBackground,
              borderRadius: BorderRadius.circular(10),
              image: item.product.imageBytes != null
                  ? DecorationImage(image: MemoryImage(item.product.imageBytes!), fit: BoxFit.cover)
                  : null,
            ),
            child: item.product.imageBytes == null
                ? const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.purpleLight)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
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
            onTap: () => CartStore.instance.incrementQty(item.product.id),
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
