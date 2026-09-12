import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/api/api_client.dart';
import '../../data/services/notification_service.dart';
import 'inventory_store.dart';
import 'sales_store.dart';

class OrdersStore extends ChangeNotifier {
  OrdersStore._();
  static final OrdersStore instance = OrdersStore._();

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;
  final Set<int> _knownOrderIds = {};
  bool _hasInitialFetch = false;
  Timer? _pollingTimer;

  ValueChanged<Map<String, dynamic>>? onNewOrderReceived;

  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get pendingCount =>
      _orders.where((o) => o['status'] == 'pending').length;

  int get activeCount =>
      _orders.where((o) => o['status'] == 'pending' || o['status'] == 'counter_offer' || o['status'] == 'accepted').length;

  void startPolling({Duration interval = const Duration(seconds: 12)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => fetchOrders(isSilent: true));
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> fetchOrders({bool isSilent = false}) async {
    if (!isSilent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final fetched = await ApiClient.instance.fetchOrders();

      // Check for newly arrived customer orders
      if (_hasInitialFetch) {
        for (final o in fetched) {
          final id = o['id'] as int?;
          final status = o['status'] as String?;
          if (id != null && !_knownOrderIds.contains(id) && status == 'pending') {
            final custName = (o['customer_name'] as String?)?.trim();
            final nameText = (custName != null && custName.isNotEmpty) ? custName : 'A customer';
            final amount = o['total_amount']?.toString() ?? '0.00';

            // 1. Android Heads-Up System Notification
            OwnerNotificationService.instance.showNotification(
              title: '🔔 New Order #$id Received!',
              body: '🛒 $nameText placed an order for ₱$amount. Tap to review and prepare!',
              payload: id.toString(),
            );

            // 2. In-App Pop-up notification callback
            onNewOrderReceived?.call(o);
          }
        }
      }

      _orders = fetched;
      for (final o in _orders) {
        final id = o['id'] as int?;
        if (id != null) _knownOrderIds.add(id);
      }
      _hasInitialFetch = true;
    } catch (e) {
      if (!isSilent) _error = e.toString();
    } finally {
      if (!isSilent) {
        _isLoading = false;
      }
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

  Future<void> markOrderReady(int orderId) async {
    await ApiClient.instance.markOrderReady(orderId);
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

  void clear() {
    stopPolling();
    _orders.clear();
    _knownOrderIds.clear();
    _hasInitialFetch = false;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
