import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/chat_provider.dart';
import '../../storage/hidden_products_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/navigation_guard.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/notification_badge.dart';
import '../../widgets/product_card.dart';
import '../../widgets/shimmer_product_card.dart';
import '../chat/customer_chat_screen.dart';
import 'product_detail_sheet.dart';

class ShopScreen extends StatefulWidget {
  final VoidCallback? onGoToCart;

  const ShopScreen({super.key, this.onGoToCart});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    HiddenProductsStore.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().loadInitial();
    });
  }

  void _onSearchChanged(String val) {
    if (mounted) setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        context.read<CatalogProvider>().setSearchQuery(val);
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (mounted) setState(() {});
    context.read<CatalogProvider>().setSearchQuery('');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _isOpeningDetail = false;
  bool _isNavigatingToChat = false;

  void _openProductDetail(ProductModel product) async {
    if (_isOpeningDetail) return;
    _isOpeningDetail = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProductDetailSheet(product: product),
      );
    } finally {
      _isOpeningDetail = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CustomerThemeController>();
    final catalog = context.watch<CatalogProvider>();
    final cart = context.watch<CartProvider>();
    final chat = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${auth.greetingName}',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
            ),
            Text(
              'Browse Stores',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          if (catalog.selectedStore != null)
            AppNotificationBadge(
              count: chat.unreadCount,
              top: 6,
              right: 6,
              borderColor: AppColors.cardBackground,
              child: IconButton(
                icon: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textPrimary),
                tooltip: 'Message Store',
                onPressed: () async {
                  final store = catalog.selectedStore;
                  if (store == null || _isNavigatingToChat) return;
                  setState(() => _isNavigatingToChat = true);
                  try {
                    await NavigationGuard.pushSafely(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerChatScreen(
                          storeOwnerId: store.id,
                          storeName: store.displayName,
                          storeAvatarUrl: store.avatarUrl,
                        ),
                      ),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _isNavigatingToChat = false);
                    }
                  }
                },
              ),
            ),
          // Cart action with badge
          AppNotificationBadge(
            count: cart.totalItemCount,
            top: 6,
            right: 6,
            borderColor: AppColors.cardBackground,
            child: IconButton(
              icon: Icon(Icons.shopping_cart_outlined, color: AppColors.textPrimary),
              onPressed: widget.onGoToCart,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.cardElevated,
        onRefresh: () => catalog.refresh(),
        child: Column(
          children: [
            // Search Bar & Store Selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search products by name or barcode...',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),

            // Category Filter Chips
            if (catalog.categories.isNotEmpty) ...[
              SizedBox(
                height: 44,
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
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                          backgroundColor: AppColors.cardBackground,
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.cardBorder,
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
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
              const SizedBox(height: 8),
            ],

            // List Shops section when no store selected
            if (catalog.selectedStore == null && catalog.stores.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing all items across stores. Tap any store below to shop from that store specifically.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                child: Row(
                  children: [
                    Icon(Icons.store_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Available Stores',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${catalog.stores.length} ${catalog.stores.length == 1 ? 'store' : 'stores'}',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 88,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: catalog.stores.length,
                  itemBuilder: (context, index) {
                    final store = catalog.stores[index];
                    final hasAvatar = store.avatarUrl != null && store.avatarUrl!.isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => catalog.selectStore(store),
                        child: Container(
                          width: 200,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.cardElevated,
                                  border: Border.all(
                                    color: store.isOpen
                                        ? AppColors.primary.withValues(alpha: 0.5)
                                        : AppColors.textMuted.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: hasAvatar
                                      ? Image.network(
                                          store.avatarUrl!,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                                        )
                                      : const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      store.displayName,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: store.isOpen ? AppColors.success : AppColors.danger,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          store.isOpen ? 'Open' : 'Closed',
                                          style: TextStyle(
                                            color: store.isOpen ? AppColors.success : AppColors.danger,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to browse →',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
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
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Store Info & Chat Card when a store IS selected
            if (catalog.selectedStore != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardElevated,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: ClipOval(
                          child: catalog.selectedStore!.avatarUrl != null && catalog.selectedStore!.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  catalog.selectedStore!.avatarUrl!,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                                )
                              : const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    catalog.selectedStore!.displayName,
                                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: catalog.selectedStore!.isOpen
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : AppColors.danger.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: catalog.selectedStore!.isOpen
                                          ? AppColors.success.withValues(alpha: 0.4)
                                          : AppColors.danger.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    catalog.selectedStore!.isOpen ? 'OPEN' : 'CLOSED',
                                    style: TextStyle(
                                      color: catalog.selectedStore!.isOpen ? AppColors.success : AppColors.danger,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              catalog.selectedStore!.isOpen
                                  ? 'Have questions about inventory?'
                                  : 'Store is temporarily closed for orders',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'View all stores',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.cardElevated,
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                        onPressed: () => catalog.selectStore(null),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          final store = catalog.selectedStore;
                          if (store == null) return;
                          NavigationGuard.pushSafely(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerChatScreen(
                                storeOwnerId: store.id,
                                storeName: store.displayName,
                                storeAvatarUrl: store.avatarUrl,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_rounded, size: 14, color: Colors.white),
                        label: const Text('Chat', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!catalog.selectedStore!.isOpen)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.store_mall_directory_outlined, color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This store is currently closed. New orders cannot be placed at this time.',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
            ],

            // Product Grid or Empty/Loading State
            Expanded(
              child: ListenableBuilder(
                listenable: HiddenProductsStore.instance,
                builder: (context, _) {
                  final visibleProducts = catalog.products
                      .where((p) => !HiddenProductsStore.instance.isHidden(p.id))
                      .toList();

                  if (catalog.isLoading && catalog.products.isEmpty) {
                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: 6,
                      itemBuilder: (_, index) => const ShimmerProductCard(),
                    );
                  }

                  if (visibleProducts.isEmpty) {
                    final hasStoreFilter = catalog.selectedStore != null;
                    final hasSearch = catalog.searchQuery.isNotEmpty;
                    final hasCategory = catalog.selectedCategory != null;

                    String emptyTitle = 'No Products Found';
                    String emptyMessage = 'There are no products listed here yet. Swipe down to refresh.';
                    String? btnText;
                    VoidCallback? btnAction;

                    if (hasSearch) {
                      emptyMessage = 'No items matched "${catalog.searchQuery}". Try a different keyword.';
                      btnText = 'Clear Search';
                      btnAction = _clearSearch;
                    } else if (hasCategory) {
                      emptyTitle = 'No Items in ${catalog.selectedCategory!.name}';
                      emptyMessage = 'This category doesn\'t have any products available right now.';
                      btnText = 'View All Categories';
                      btnAction = () => catalog.selectCategory(null);
                    } else if (hasStoreFilter) {
                      emptyTitle = '${catalog.selectedStore!.displayName} is Empty';
                      emptyMessage = 'This store hasn\'t listed any products yet.';
                      btnText = 'Browse Other Stores';
                      btnAction = () => catalog.selectStore(null);
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: EmptyState(
                            icon: hasSearch ? Icons.search_off_rounded : Icons.inventory_2_outlined,
                            title: emptyTitle,
                            message: emptyMessage,
                            buttonText: btnText,
                            onButtonPressed: btnAction,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          catalog.selectedStore != null
                                              ? catalog.selectedStore!.displayName
                                              : (catalog.selectedCategory != null
                                                  ? catalog.selectedCategory!.name
                                                  : 'All Items'),
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: catalog.selectedStore != null
                                              ? AppColors.success.withValues(alpha: 0.15)
                                              : AppColors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: catalog.selectedStore != null
                                                ? AppColors.success.withValues(alpha: 0.3)
                                                : AppColors.primary.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          catalog.selectedStore != null
                                              ? 'Single Store'
                                              : 'All Stores',
                                          style: TextStyle(
                                            color: catalog.selectedStore != null
                                                ? AppColors.success
                                                : AppColors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    catalog.selectedStore != null
                                        ? '${visibleProducts.length} items from this store'
                                        : '${visibleProducts.length} total items across stores',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (catalog.selectedStore != null)
                              TextButton(
                                onPressed: () => catalog.selectStore(null),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'View All',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else if (catalog.selectedCategory != null)
                              GestureDetector(
                                onTap: () => catalog.selectCategory(null),
                                child: Text(
                                  'Clear filter',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          cacheExtent: 600,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: visibleProducts.length,
                          itemBuilder: (context, index) {
                            final product = visibleProducts[index];
                            Widget card = ProductCard(
                              key: ValueKey('product-${product.id}'),
                              product: product,
                              onTap: () => _openProductDetail(product),
                            );

                            if (catalog.selectedStore == null &&
                                product.storeName != null &&
                                product.storeName!.isNotEmpty) {
                              card = Stack(
                                children: [
                                  card,
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    right: 4,
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          product.storeName!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return RepaintBoundary(
                              child: card,
                            );
                          },
                        ),
                      ),
                    ],
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
