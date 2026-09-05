import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_card.dart';
import 'product_detail_sheet.dart';

class ShopScreen extends StatefulWidget {
  final VoidCallback? onGoToCart;

  const ShopScreen({super.key, this.onGoToCart});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadInitial();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openProductDetail(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductDetailSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${auth.greetingName}',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
            ),
            const Text(
              'Browse Stores',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          // Cart action with badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                onPressed: widget.onGoToCart,
              ),
              if (cart.totalItemCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${cart.totalItemCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => catalog.refresh(),
        child: Column(
          children: [
            // Search Bar & Store Selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => catalog.setSearchQuery(val),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search products by name or barcode...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            catalog.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
            ),

            // Store Filter Row (if multiple stores exist)
            if (catalog.stores.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: catalog.stores.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = catalog.selectedStore == null;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All Stores'),
                          selected: isSelected,
                          onSelected: (_) => catalog.selectStore(null),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          backgroundColor: AppColors.cardBackground,
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.cardBorder,
                          ),
                        ),
                      );
                    }
                    final store = catalog.stores[index - 1];
                    final isSelected = catalog.selectedStore?.id == store.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          Icons.storefront,
                          size: 14,
                          color: isSelected ? Colors.black : AppColors.primaryLight,
                        ),
                        label: Text(store.displayName),
                        selected: isSelected,
                        onSelected: (_) => catalog.selectStore(store),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        backgroundColor: AppColors.cardBackground,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.cardBorder,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Category Filter Chips
            if (catalog.categories.isNotEmpty) ...[
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: catalog.categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = catalog.selectedCategory == null;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('All Categories'),
                          selected: isSelected,
                          onSelected: (_) => catalog.selectCategory(null),
                          selectedColor: AppColors.cardElevated,
                          checkmarkColor: AppColors.primaryLight,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          backgroundColor: AppColors.cardBackground,
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryLight : AppColors.cardBorder,
                          ),
                        ),
                      );
                    }
                    final cat = catalog.categories[index - 1];
                    final isSelected = catalog.selectedCategory?.id == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (_) => catalog.selectCategory(cat),
                        selectedColor: AppColors.cardElevated,
                        checkmarkColor: AppColors.primaryLight,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        backgroundColor: AppColors.cardBackground,
                        side: BorderSide(
                          color: isSelected ? AppColors.primaryLight : AppColors.cardBorder,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Product Grid or Empty/Loading State
            Expanded(
              child: catalog.isLoading && catalog.products.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : catalog.products.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No Products Found',
                          message: catalog.searchQuery.isNotEmpty
                              ? 'No items matched "${catalog.searchQuery}". Try a different keyword.'
                              : 'There are no products listed in this category or store yet.',
                          buttonText: catalog.searchQuery.isNotEmpty ? 'Clear Search' : 'Refresh',
                          onButtonPressed: () {
                            if (catalog.searchQuery.isNotEmpty) {
                              _searchController.clear();
                              catalog.setSearchQuery('');
                            } else {
                              catalog.refresh();
                            }
                          },
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: catalog.products.length,
                          itemBuilder: (context, index) {
                            final product = catalog.products[index];
                            return ProductCard(
                              product: product,
                              onTap: () => _openProductDetail(product),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
