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
    if (product.stock <= 0) return false;

    // Check if adding from different store
    if (_items.isNotEmpty && product.ownerId != null) {
      final currentStore = storeId;
      if (currentStore != null && currentStore != product.ownerId) {
        // Will need user confirmation if from another store
        return false;
      }
    }

    if (_items.containsKey(product.id)) {
      final current = _items[product.id]!;
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
}
