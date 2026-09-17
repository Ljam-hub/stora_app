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
  final Set<int> _processingOrderIds = <int>{};
  bool _hasInitialFetch = false;
  Timer? _pollingTimer;

  ValueChanged<Map<String, dynamic>>? onNewOrderReceived;

  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool isOrderProcessing(int orderId) => _processingOrderIds.contains(orderId);

  int get pendingCount =>
      _orders.where((o) => o['status'] == 'pending').length;

  int get activeCount =>
      _orders.where((o) => o['status'] == 'pending' || o['status'] == 'counter_offer' || o['status'] == 'accepted' || o['status'] == 'ready').length;

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
          final id = _parseOrderId(o['id']);
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
        final id = _parseOrderId(o['id']);
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
    if (_processingOrderIds.contains(orderId)) return;
    _processingOrderIds.add(orderId);
    notifyListeners();
    try {
      final response = await ApiClient.instance.acceptOrder(orderId);
      final updatedOrder = (response['order'] as Map<String, dynamic>?) ?? response;
      final idx = _orders.indexWhere((o) => _parseOrderId(o['id']) == orderId);
      if (idx != -1) {
        _orders[idx] = Map<String, dynamic>.from(_orders[idx])
          ..addAll(updatedOrder)
          ..['status'] = 'accepted';
      }

      // Parallel non-blocking background sync
      unawaited(Future.wait([
        InventoryStore.instance.loadProducts(),
        SalesStore.instance.loadSales(),
        fetchOrders(isSilent: true),
      ]));
    } finally {
      _processingOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  Future<void> markOrderReady(int orderId) async {
    if (_processingOrderIds.contains(orderId)) return;
    _processingOrderIds.add(orderId);
    notifyListeners();
    try {
      final response = await ApiClient.instance.markOrderReady(orderId);
      final updatedOrder = (response['order'] as Map<String, dynamic>?) ?? response;
      final idx = _orders.indexWhere((o) => _parseOrderId(o['id']) == orderId);
      if (idx != -1) {
        _orders[idx] = Map<String, dynamic>.from(_orders[idx])
          ..addAll(updatedOrder)
          ..['status'] = 'ready';
      }

      unawaited(fetchOrders(isSilent: true));
    } finally {
      _processingOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  Future<void> declineOrder(int orderId, {String reason = ''}) async {
    if (_processingOrderIds.contains(orderId)) return;
    _processingOrderIds.add(orderId);
    notifyListeners();
    try {
      final response = await ApiClient.instance.declineOrder(orderId, reason: reason);
      final updatedOrder = (response['order'] as Map<String, dynamic>?) ?? response;
      final idx = _orders.indexWhere((o) => _parseOrderId(o['id']) == orderId);
      if (idx != -1) {
        _orders[idx] = Map<String, dynamic>.from(_orders[idx])
          ..addAll(updatedOrder)
          ..['status'] = 'declined';
      }

      unawaited(fetchOrders(isSilent: true));
    } finally {
      _processingOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  Future<void> counterOrder(
    int orderId, {
    required String notes,
    double? counterPrice,
  }) async {
    if (_processingOrderIds.contains(orderId)) return;
    _processingOrderIds.add(orderId);
    notifyListeners();
    try {
      final response = await ApiClient.instance.counterOrder(
        orderId,
        notes: notes,
        counterPrice: counterPrice,
      );
      final updatedOrder = (response['order'] as Map<String, dynamic>?) ?? response;
      final idx = _orders.indexWhere((o) => _parseOrderId(o['id']) == orderId);
      if (idx != -1) {
        _orders[idx] = Map<String, dynamic>.from(_orders[idx])
          ..addAll(updatedOrder)
          ..['status'] = 'counter_offer';
      }

      unawaited(fetchOrders(isSilent: true));
    } finally {
      _processingOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  void clear() {
    stopPolling();
    _orders.clear();
    _knownOrderIds.clear();
    _processingOrderIds.clear();
    _hasInitialFetch = false;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

int? _parseOrderId(dynamic rawId) {
  if (rawId == null) return null;
  if (rawId is int) return rawId;
  if (rawId is num) return rawId.toInt();
  return int.tryParse(rawId.toString());
}

