import 'package:flutter/foundation.dart';
import '../../data/api/api_client.dart';
import 'inventory_store.dart';
import 'sales_store.dart';

class OrdersStore extends ChangeNotifier {
  OrdersStore._();
  static final OrdersStore instance = OrdersStore._();

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get pendingCount =>
      _orders.where((o) => o['status'] == 'pending' || o['status'] == 'counter_offer').length;

  Future<void> fetchOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _orders = await ApiClient.instance.fetchOrders();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptOrder(int orderId) async {
    await ApiClient.instance.acceptOrder(orderId);
    // Reload products & sales to sync decremented stock & new sale record
    await InventoryStore.instance.loadProducts();
    await SalesStore.instance.loadSales();
    await fetchOrders();
  }

  Future<void> declineOrder(int orderId, {String reason = ''}) async {
    await ApiClient.instance.declineOrder(orderId, reason: reason);
    await fetchOrders();
  }

  Future<void> counterOrder(
    int orderId, {
    required String notes,
    double? counterPrice,
  }) async {
    await ApiClient.instance.counterOrder(
      orderId,
      notes: notes,
      counterPrice: counterPrice,
    );
    await fetchOrders();
  }
}
