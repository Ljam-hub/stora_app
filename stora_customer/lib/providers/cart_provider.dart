import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final Map<int, CartItemModel> _items = {};

  List<CartItemModel> get items => _items.values.toList();
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get totalItemCount {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalAmount {
    return _items.values.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  String get formattedTotal => '₱${totalAmount.toStringAsFixed(2)}';

  int? get storeId {
    if (_items.isEmpty) return null;
    return _items.values.first.product.ownerId;
  }

  String? get storeName {
    if (_items.isEmpty) return null;
    return _items.values.first.product.storeName;
  }

  int getQuantity(int productId) {
    return _items[productId]?.quantity ?? 0;
  }

  bool addItem(ProductModel product, [int quantity = 1]) {
    if (product.stock <= 0 || quantity <= 0) return false;
    if (product.ownerId == null) return false;

    // Multi-cart: items from multiple stores can coexist simultaneously

    if (_items.containsKey(product.id)) {
      final current = _items[product.id]!;
      if (current.quantity >= product.stock) return false;
      final newQty = current.quantity + quantity;
      if (newQty <= product.stock) {
        current.quantity = newQty;
      } else {
        current.quantity = product.stock;
      }
    } else {
      final addQty = quantity <= product.stock ? quantity : product.stock;
      _items[product.id] = CartItemModel(
        product: product,
        quantity: addQty,
      );
    }
    notifyListeners();
    return true;
  }

  /// Map of items grouped by store ownerId
  Map<int, List<CartItemModel>> get itemsByStore {
    final grouped = <int, List<CartItemModel>>{};
    for (final item in _items.values) {
      final sId = item.product.ownerId ?? 0;
      grouped.putIfAbsent(sId, () => []).add(item);
    }
    return grouped;
  }

  /// List of distinct store IDs present in the cart
  List<int> get storeIds => itemsByStore.keys.toList();

  /// Whether the cart contains items from more than one store
  bool get hasMultipleStores => storeIds.length > 1;

  /// Items belonging to a specific store
  List<CartItemModel> itemsForStore(int storeId) {
    return itemsByStore[storeId] ?? [];
  }

  /// Store name for a specific storeId
  String storeNameFor(int storeId) {
    final storeItems = itemsByStore[storeId];
    if (storeItems == null || storeItems.isEmpty) return 'Store';
    final name = storeItems.first.product.storeName;
    return (name != null && name.trim().isNotEmpty) ? name.trim() : 'Store #$storeId';
  }

  /// Total amount for a specific store
  double totalAmountFor(int storeId) {
    final storeItems = itemsByStore[storeId] ?? [];
    return storeItems.fold(0.0, (sum, i) => sum + i.subtotal);
  }

  /// Formatted total for a specific store
  String formattedTotalFor(int storeId) {
    return '₱${totalAmountFor(storeId).toStringAsFixed(2)}';
  }

  /// Total item count for a specific store
  int itemCountFor(int storeId) {
    final storeItems = itemsByStore[storeId] ?? [];
    return storeItems.fold(0, (sum, i) => sum + i.quantity);
  }

  /// Convert items of a specific store to CustomerOrderItem list for checkout
  List<CustomerOrderItem> toOrderItemsFor(int storeId) {
    final storeItems = itemsByStore[storeId] ?? [];
    return storeItems.map((item) {
      return CustomerOrderItem(
        productId: item.product.id,
        productName: item.product.name,
        quantity: item.quantity,
        unitPrice: item.product.price,
      );
    }).toList();
  }

  /// Remove all items belonging to a specific store
  void clearStore(int storeId) {
    _items.removeWhere((key, value) => (value.product.ownerId ?? 0) == storeId);
    notifyListeners();
  }

  void updateQuantity(int productId, int newQuantity) {
    if (!_items.containsKey(productId)) return;

    if (newQuantity <= 0) {
      _items.remove(productId);
    } else {
      final item = _items[productId]!;
      if (newQuantity <= item.product.stock) {
        item.quantity = newQuantity;
      } else {
        item.quantity = item.product.stock;
      }
    }
    notifyListeners();
  }

  void increment(int productId) {
    if (!_items.containsKey(productId)) return;
    final item = _items[productId]!;
    if (item.quantity < item.product.stock) {
      item.quantity++;
      notifyListeners();
    }
  }

  void decrement(int productId) {
    if (!_items.containsKey(productId)) return;
    final item = _items[productId]!;
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  List<CustomerOrderItem> toOrderItems() {
    return _items.values.map((item) {
      return CustomerOrderItem(
        productId: item.product.id,
        productName: item.product.name,
        quantity: item.quantity,
        unitPrice: item.product.price,
      );
    }).toList();
  }

  /// Reorder items from a previous order into the cart.
  /// If [freshProducts] is provided, uses real stock limits and latest pricing.
  /// Returns count of items added, or -1 if there is a store conflict without clearing.
  int addOrderItems(
    CustomerOrder order, {
    bool clearExisting = false,
    List<ProductModel>? freshProducts,
  }) {
    if (clearExisting) {
      clear();
    }

    final productMap = <int, ProductModel>{};
    if (freshProducts != null) {
      for (final p in freshProducts) {
        productMap[p.id] = p;
      }
    }

    int count = 0;
    for (final item in order.items) {
      if (item.productId == null || item.productId! <= 0) continue;
      final fresh = productMap[item.productId!];
      final productToAdd = fresh ??
          ProductModel(
            id: item.productId!,
            name: item.productName,
            price: item.unitPrice,
            stock: 999,
            ownerId: order.ownerId,
            storeName: order.storeName,
          );
      final qty = fresh != null
          ? (item.quantity <= fresh.stock ? item.quantity : fresh.stock)
          : item.quantity;
      if (qty > 0) {
        final added = addItem(productToAdd, qty);
        if (added) count++;
      }
    }
    return count;
  }
}
