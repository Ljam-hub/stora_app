import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class OrderProvider extends ChangeNotifier {
  List<CustomerOrder> _orders = [];
  String _selectedStatusFilter = 'all';
  bool _isLoading = false;
  String? _errorMessage;

  final Map<int, String> _knownStatuses = {};
  bool _hasInitialFetch = false;
  Timer? _pollingTimer;

  void Function(CustomerOrder order, String newStatus)? onOrderStatusChanged;

  List<CustomerOrder> get orders => _filteredOrders();
  List<CustomerOrder> get rawOrders => _orders;
  String get selectedStatusFilter => _selectedStatusFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get activePendingCount => _orders.where((o) =>
      o.status == 'pending' ||
      o.status == 'counter_offer' ||
      o.status == 'accepted' ||
      o.status == 'ready'
  ).length;

  int get pendingCount => _orders.where((o) => o.status == 'pending').length;
  int get counterOfferCount => _orders.where((o) => o.status == 'counter_offer').length;
  int get acceptedCount => _orders.where((o) => o.status == 'accepted').length;
  int get readyCount => _orders.where((o) => o.status == 'ready').length;

  bool _ordersTabSeen = false;
  final Set<String> _seenFilters = {};
  int _lastSeenPendingCount = 0;
  int _lastSeenCounterOfferCount = 0;
  int _lastSeenActiveOrdersCount = 0;

  void markOrdersTabSeen() {
    _ordersTabSeen = true;
    _lastSeenActiveOrdersCount = activePendingCount;
    notifyListeners();
  }

  void markFilterSeen(String filterId) {
    _seenFilters.add(filterId);
    if (filterId == 'pending') {
      _lastSeenPendingCount = pendingCount;
    } else if (filterId == 'counter_offer') {
      _lastSeenCounterOfferCount = counterOfferCount;
    }
    notifyListeners();
  }

  int get unreadPendingCount {
    if (_seenFilters.contains('pending') && pendingCount <= _lastSeenPendingCount) {
      return 0;
    }
    return pendingCount;
  }

  int get unreadCounterOfferCount {
    if (_seenFilters.contains('counter_offer') && counterOfferCount <= _lastSeenCounterOfferCount) {
      return 0;
    }
    return counterOfferCount;
  }

  int get unreadActiveOrdersCount {
    if (_ordersTabSeen && activePendingCount <= _lastSeenActiveOrdersCount) {
      return 0;
    }
    return activePendingCount;
  }

  void startPolling({Duration interval = const Duration(seconds: 12)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => refresh(isSilent: true));
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _checkStatusTransitions(List<CustomerOrder> newOrders) {
    if (!_hasInitialFetch) {
      for (final o in newOrders) {
        _knownStatuses[o.id] = o.status;
      }
      _hasInitialFetch = true;
      return;
    }

    for (final o in newOrders) {
      final oldStatus = _knownStatuses[o.id];
      if (oldStatus != null && oldStatus != o.status) {
        if (o.status == 'accepted') {
          NotificationService.instance.showNotification(
            title: '👨‍🍳 Order #${o.id} Accepted!',
            body: 'The store is now preparing your items! We will notify you when it is ready.',
            payload: o.id.toString(),
          );
          onOrderStatusChanged?.call(o, 'accepted');
        } else if (o.status == 'ready') {
          NotificationService.instance.showNotification(
            title: '🎉 Order #${o.id} Ready for Pickup!',
            body: 'Your items are packed and ready for pickup! Tap to view details.',
            payload: o.id.toString(),
          );
          onOrderStatusChanged?.call(o, 'ready');
        } else if (o.status == 'declined' || o.status == 'auto_declined') {
          final reason = o.declineReason?.isNotEmpty == true ? ': ${o.declineReason}' : '.';
          NotificationService.instance.showNotification(
            title: 'Order #${o.id} Declined',
            body: 'Your order was declined by the store$reason',
            payload: o.id.toString(),
          );
          onOrderStatusChanged?.call(o, 'declined');
        } else if (o.status == 'counter_offer') {
          final priceText = o.counterPrice != null ? ' (₱${o.counterPrice!.toStringAsFixed(2)})' : '';
          NotificationService.instance.showNotification(
            title: '💬 Counter-Offer on Order #${o.id}',
            body: 'The store suggested an update$priceText. Tap to view notes.',
            payload: o.id.toString(),
          );
          onOrderStatusChanged?.call(o, 'counter_offer');
        }
      }
      _knownStatuses[o.id] = o.status;
    }
  }

  List<CustomerOrder> _filteredOrders() {
    if (_selectedStatusFilter == 'all') {
      return _orders;
    }
    return _orders.where((o) {
      if (_selectedStatusFilter == 'pending') {
        return o.status == 'pending';
      }
      if (_selectedStatusFilter == 'counter_offer') {
        return o.status == 'counter_offer';
      }
      if (_selectedStatusFilter == 'accepted') {
        return o.status == 'accepted';
      }
      if (_selectedStatusFilter == 'declined') {
        return o.status == 'declined' || o.status == 'auto_declined';
      }
      return true;
    }).toList();
  }

  void setFilter(String filter) {
    _selectedStatusFilter = filter;
    markFilterSeen(filter);
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await CustomerApiService.instance.fetchMyOrders();
      _checkStatusTransitions(fetched);
      _orders = fetched;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh({bool isSilent = false}) async {
    try {
      final fetched = await CustomerApiService.instance.fetchMyOrders();
      _checkStatusTransitions(fetched);
      _orders = fetched;
      notifyListeners();
    } catch (e) {
      if (!isSilent) debugPrint('Error refreshing orders: $e');
    }
  }

  Future<CustomerOrder> placeOrder({
    required int ownerId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    String notes = '',
    required List<CustomerOrderItem> items,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await CustomerApiService.instance.placeOrder(
        ownerId: ownerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        notes: notes,
        items: items,
      );
      _orders.insert(0, order);
      _knownStatuses[order.id] = order.status;

      // Pop up system notification for order placed
      NotificationService.instance.showNotification(
        title: '🛍️ Order #${order.id} Placed!',
        body: 'Your order has been sent to the store! Waiting for confirmation.',
        payload: order.id.toString(),
      );

      _isLoading = false;
      notifyListeners();
      return order;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
