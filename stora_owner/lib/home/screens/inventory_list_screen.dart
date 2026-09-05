import 'package:flutter/material.dart';
import '../../stora_login/stora_login.dart';
import '../../data/api/api_client.dart';
import '../../data/stores/account_status_store.dart';
import 'barcode_scanner_screen.dart';
import '../models/product.dart';
import '../stores/inventory_store.dart';
import '../theme/home_colors.dart';
import '../utils/constants.dart';
import '../widgets/category_filter_row.dart';
import '../widgets/stock_step_button.dart';
import '../../subscription/subscription_screen.dart';
import 'add_edit_product_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onScan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null) return;
    try {
      final match = await ApiClient.instance.lookupBarcode(code);
      if (!mounted) return;
      if (match != null) {
        final local = InventoryStore.instance.products.firstWhere(
          (p) => p.id == match['id'],
          orElse: () => Product.fromJson(match),
        );
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddEditProductScreen(existing: local)),
        );
      } else {
        showStoraSnackBar(context, 'Product not found');
      }
    } catch (e) {
      if (!mounted) return;
      showStoraSnackBar(context, e.toString());
    }
  }


  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([InventoryStore.instance, AccountStatusStore.instance]),
      builder: (context, _) {
        final isPremium = AccountStatusStore.instance.isPremium;
        final categoryFiltered = _selectedCategory == 'All'
            ? InventoryStore.instance.products
            : InventoryStore.instance.products.where((p) => p.category == _selectedCategory).toList();
        final products = categoryFiltered
            .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: const TextStyle(color: AppColors.hint),
                      prefixIcon: const Icon(Icons.search, color: AppColors.label),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: AppColors.purple),
                        onPressed: _onScan,
                      ),
                      filled: true,
                      fillColor: HomeColors.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.fieldBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.purple),
                      ),
                    ),
                  ),
                ),
                CategoryFilterRow(
                  selected: _selectedCategory,
                  onSelect: (cat) => setState(() => _selectedCategory = cat),
                ),
                if (InventoryStore.instance.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      InventoryStore.instance.error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: products.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: HomeColors.cardElevated,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: HomeColors.cardBorder),
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.purpleLight),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _query.isNotEmpty ? 'No products match "$_query"' : 'No products in inventory yet',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _query.isNotEmpty
                                      ? 'Try searching with a different keyword or barcode'
                                      : 'Tap the button below to add your first product.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.label, fontSize: 13),
                                ),
                                if (_query.isEmpty) ...[
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (!AccountStatusStore.instance.canAddProduct) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => SubscriptionScreen(
                                              productsUsed: AccountStatusStore.instance.productCount,
                                              productsLimit: AccountStatusStore.instance.productLimit,
                                            ),
                                          ),
                                        );
                                      } else {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.add, size: 18, color: Colors.black),
                                    label: const Text('Add Product', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.purpleLight,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.74,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, i) {
                            // On free plan, items after first 20 products in the store are locked
                            final allIdx = InventoryStore.instance.products.indexOf(products[i]);
                            final isLocked = !isPremium && (allIdx >= 20 || (allIdx == -1 && i >= 20));
                            return ProductCard(
                              product: products[i],
                              isLocked: isLocked,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: Container(
            decoration: BoxDecoration(
              gradient: HomeColors.purpleGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: HomeColors.glowShadow(AppColors.purple, opacity: 0.35),
            ),
            child: FloatingActionButton(
              backgroundColor: Colors.transparent,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              onPressed: () {
                if (!AccountStatusStore.instance.canAddProduct) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SubscriptionScreen(
                        productsUsed: AccountStatusStore.instance.productCount,
                        productsLimit: AccountStatusStore.instance.productLimit,
                      ),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
                  );
                }
              },
              child: const Icon(Icons.add, color: Colors.black87, size: 28),
            ),
          ),
        );
      },
    );
  }
}

void confirmDeleteProduct(BuildContext context, Product product) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: HomeColors.cardBackground,
      title: const Text('Delete product?', style: TextStyle(color: Colors.white)),
      content: Text('This will remove "${product.name}" from your inventory. This can\'t be undone.',
          style: const TextStyle(color: AppColors.label)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
        ),
        TextButton(
          onPressed: () async {
            final ok = await InventoryStore.instance.removeProduct(product.id);
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (!ok && context.mounted) {
              showStoraSnackBar(
                context,
                InventoryStore.instance.error ?? 'Could not delete product',
              );
            }
          },
          child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

class ProductCard extends StatelessWidget {
  final Product product;
  final bool isLocked;
  const ProductCard({super.key, required this.product, this.isLocked = false});

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stock <= 0;
    final isLowStock = product.stock > 0 && product.stock < 5;

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (isLocked) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SubscriptionScreen(
                    productsUsed: AccountStatusStore.instance.productCount,
                    productsLimit: AccountStatusStore.instance.productLimit,
                  ),
                ),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AddEditProductScreen(existing: product)),
            );
          },
          child: Opacity(
            opacity: isLocked ? 0.45 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HomeColors.cardBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isOutOfStock ? AppColors.error.withValues(alpha: 0.3) : HomeColors.cardBorder),
                boxShadow: HomeColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.fieldBackground,
                        borderRadius: BorderRadius.circular(14),
                        image: product.imageBytes != null
                            ? DecorationImage(image: MemoryImage(product.imageBytes!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: product.imageBytes == null
                          ? const Center(
                              child: Icon(Icons.inventory_2_outlined, color: AppColors.hint, size: 30),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isOutOfStock)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: HomeColors.dangerBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('OUT OF STOCK',
                          style: TextStyle(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.w800)),
                    )
                  else if (isLowStock)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: HomeColors.warningBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('LOW STOCK (${product.stock})',
                          style: const TextStyle(color: HomeColors.warningText, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.label, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text('₱${product.price.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.purpleLight, fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StockStepButton(
                            icon: Icons.remove,
                            onTap: isLocked ? () {} : () => InventoryStore.instance.adjustStock(product.id, -1),
                            disabled: isLocked,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('${product.stock}',
                                style: TextStyle(
                                    color: isOutOfStock ? AppColors.error : isLowStock ? HomeColors.warningText : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ),
                          StockStepButton(
                            icon: Icons.add,
                            onTap: (isLocked || product.stock >= kMaxStock)
                                ? () {}
                                : () => InventoryStore.instance.adjustStock(product.id, 1),
                            disabled: isLocked || product.stock >= kMaxStock,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isLocked)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.purple, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 12, color: AppColors.purpleLight),
                  SizedBox(width: 4),
                  Text('LOCKED', style: TextStyle(color: AppColors.purpleLight, fontSize: 10, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        if (!isLocked)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => confirmDeleteProduct(context, product),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
