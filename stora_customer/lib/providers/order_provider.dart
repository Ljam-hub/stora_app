import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<CustomerOrder> _orders = [];
  String _selectedStatusFilter = 'all';
  bool _isLoading = false;
  String? _errorMessage;

  List<CustomerOrder> get orders => _filteredOrders();
  List<CustomerOrder> get rawOrders => _orders;
  String get selectedStatusFilter => _selectedStatusFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
    notifyListeners();
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await CustomerApiService.instance.fetchMyOrders();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _orders = await CustomerApiService.instance.fetchMyOrders();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing orders: $e');
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
