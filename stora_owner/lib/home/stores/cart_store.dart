import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartStore extends ChangeNotifier {
  CartStore._internal();
  static final CartStore instance = CartStore._internal();

  final Map<String, CartItem> _items = {};
  List<CartItem> get items => _items.values.toList();
  double get total => _items.values.fold(0.0, (sum, i) => sum + i.subtotal);

  void add(Product product) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity++;
    } else {
      _items[product.id] = CartItem(product: product);
    }
    notifyListeners();
  }

  void remove(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void incrementQty(String productId) {
    _items[productId]?.quantity++;
    notifyListeners();
  }

  /// Decrements quantity by 1; removes the line entirely once it hits 0.
  void decrementQty(String productId) {
    final item = _items[productId];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(productId);
    } else {
      item.quantity--;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
