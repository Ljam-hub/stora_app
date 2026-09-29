import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import 'inventory_store.dart';

class CartStore extends ChangeNotifier {
  CartStore._internal();
  static final CartStore instance = CartStore._internal();

  final Map<String, CartItem> _items = {};
  List<CartItem>? _cachedItems;
  
  List<CartItem> get items => _cachedItems ??= _items.values.toList();
  double get total => _items.values.fold(0.0, (sum, i) => sum + i.subtotal);

  int getQuantity(String productId) => _items[productId]?.quantity ?? 0;
  CartItem? getItem(String productId) => _items[productId];

  void add(Product product) {
    final currentStock = InventoryStore.instance.products
        .firstWhere((p) => p.id == product.id, orElse: () => product)
        .stock;
    if (currentStock <= 0) return;
    if (_items.containsKey(product.id)) {
      if (_items[product.id]!.quantity < currentStock) {
        _items[product.id]!.quantity++;
        _cachedItems = null;
      }
    } else {
      _items[product.id] = CartItem(product: product);
      _cachedItems = null;
    }
    notifyListeners();
  }

  void remove(String productId) {
    _items.remove(productId);
    _cachedItems = null;
    notifyListeners();
  }

  void incrementQty(String productId) {
    final item = _items[productId];
    if (item == null) return;
    final currentStock = InventoryStore.instance.products
        .firstWhere((p) => p.id == productId, orElse: () => item.product)
        .stock;
    if (item.quantity < currentStock) {
      item.quantity++;
      _cachedItems = null;
      notifyListeners();
    }
  }

  /// Decrements quantity by 1; removes the line entirely once it hits 0.
  void decrementQty(String productId) {
    final item = _items[productId];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(productId);
      _cachedItems = null;
    } else {
      item.quantity--;
      _cachedItems = null;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _cachedItems = null;
    notifyListeners();
  }
}
