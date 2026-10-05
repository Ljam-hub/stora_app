import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../../data/db/stora_database.dart';
import '../models/cart_item.dart';
import '../models/sale.dart';
import '../stores/inventory_store.dart';
import '../utils/date_utils.dart';

/// Sales history — every completed checkout is recorded here so the
/// dashboard's "Today's Total Earnings" is a real, computed number.
class SalesStore extends ChangeNotifier {
  SalesStore._internal();
  static final SalesStore instance = SalesStore._internal();

  final _db = AppDatabase.instance;
  final _api = ApiClient.instance;

  List<Sale> _sales = [];

  /// Most recent sale first.
  List<Sale> get sales => List.unmodifiable(_sales.reversed);

  bool _isSyncing = false;

  Future<void> loadSales() async {
    if (_isSyncing) return;
    _sales = await _db.salesDao.loadSales();
    notifyListeners();
    _isSyncing = true;
    try {
      final remote = await _api.listSales();
      final remoteSales = remote.map(Sale.fromJson).toList();
      final pendingLocal = _sales.where((s) => s.id.startsWith('local-')).toList();
      _sales = [...remoteSales, ...pendingLocal];
      await _db.salesDao.replaceSales(remoteSales);
    } catch (_) {
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  bool _recording = false;
  bool get recording => _recording;

  @visibleForTesting
  Future<Sale> Function(
    List<CartItem> items,
    double total, {
    double? cashTendered,
    double? changeAmount,
    String? customerName,
    String? notes,
    String? paymentMethod,
    String? referenceNumber,
  })? mockRecordSaleHandler;

  Future<Sale> recordSale(
    List<CartItem> items,
    double total, {
    double? cashTendered,
    double? changeAmount,
    String? customerName,
    String? notes,
    String? paymentMethod,
    String? referenceNumber,
  }) async {
    if (mockRecordSaleHandler != null) {
      final sale = await mockRecordSaleHandler!(
        items,
        total,
        cashTendered: cashTendered,
        changeAmount: changeAmount,
        customerName: customerName,
        notes: notes,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
      );
      _sales.add(sale);
      for (final item in items) {
        InventoryStore.instance.decrementStockLocally(item.product.id, item.quantity);
      }
      notifyListeners();
      return sale;
    }

    if (_recording || _isSyncing) {
      throw ApiException('A sale or sync is currently in progress. Please try again in a moment.');
    }
    _recording = true;
    Sale sale;
    final hasLocalItems = items.any((it) => it.product.id.startsWith('local-') || int.tryParse(it.product.id) == null);
    if (hasLocalItems) {
      try {
        sale = await _recordOfflineSale(
          items,
          total,
          cashTendered: cashTendered,
          changeAmount: changeAmount,
          customerName: customerName,
          notes: notes,
          paymentMethod: paymentMethod,
          referenceNumber: referenceNumber,
        );
      } finally {
        _recording = false;
      }
      notifyListeners();
      return sale;
    }
    Map<String, dynamic>? apiData;
    try {
      apiData = await _api.createSale({
        'customer_name': customerName ?? 'Walk-in Customer',
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (paymentMethod != null && paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
        if (referenceNumber != null && referenceNumber.isNotEmpty) 'reference_number': referenceNumber,
        'items': items
            .map(
              (item) => {
                'product': int.tryParse(item.product.id) ?? 0,
                'quantity': item.quantity,
              },
            )
            .toList(),
      });
    } on ApiException catch (e) {
      if (e.statusCode != null && e.statusCode! < 500) {
        _recording = false;
        rethrow;
      }
    } catch (_) {}

    if (apiData != null) {
      try {
        final created = Sale.fromJson(apiData);
        final withCashDetails = created.copyWith(
          cashTendered: cashTendered,
          changeAmount: changeAmount,
          customerName: created.customerName ?? customerName ?? 'Walk-in Customer',
          notes: created.notes ?? notes,
          paymentMethod: created.paymentMethod ?? paymentMethod,
          referenceNumber: created.referenceNumber ?? referenceNumber,
        );
        _sales.add(withCashDetails);
        await _db.salesDao.upsertSale(withCashDetails);
        for (final item in items) {
          InventoryStore.instance.decrementStockLocally(item.product.id, item.quantity);
        }
        unawaited(InventoryStore.instance.loadProducts());
        sale = withCashDetails;
      } catch (e) {
        _recording = false;
        throw ApiException('Failed to parse sale response: $e');
      }
    } else {
      sale = await _recordOfflineSale(
        items,
        total,
        cashTendered: cashTendered,
        changeAmount: changeAmount,
        customerName: customerName,
        notes: notes,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
      );
    }
    _recording = false;
    notifyListeners();
    return sale;
  }

  Future<Sale> _recordOfflineSale(
    List<CartItem> items,
    double total, {
    double? cashTendered,
    double? changeAmount,
    String? customerName,
    String? notes,
    String? paymentMethod,
    String? referenceNumber,
  }) async {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final shortId = (timestamp % 1000000).toString().padLeft(6, '0');
    final local = Sale(
      id: 'local-$timestamp',
      date: DateTime.now(),
      items: items.map((i) => CartItem(product: i.product, quantity: i.quantity)).toList(),
      total: total,
      cashTendered: cashTendered,
      changeAmount: changeAmount,
      customerName: customerName ?? 'Walk-in Customer',
      receiptNumber: 'POS-OFF-$shortId',
      channel: 'in_store',
      notes: notes,
      paymentMethod: paymentMethod,
      referenceNumber: referenceNumber,
    );
    _sales.add(local);
    await _db.salesDao.upsertSale(local);
    for (final item in items) {
      await InventoryStore.instance.applyLocalStockDelta(item.product.id, -item.quantity);
    }
    final payload = jsonEncode({
      'customer_name': customerName ?? 'Walk-in Customer',
      'cash_tendered': cashTendered,
      'change_amount': changeAmount,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (paymentMethod != null && paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
      if (referenceNumber != null && referenceNumber.isNotEmpty) 'reference_number': referenceNumber,
      'items': items
          .map(
            (item) => {
              'product': item.product.id,
              'quantity': item.quantity,
            },
          )
          .toList(),
    });
    await _db.syncDao.enqueueSync(
      entityType: 'sale',
      action: 'create',
      entityId: local.id,
      payload: payload,
    );
    return local;
  }

  Future<void> deleteSale(String id) async {
    try {
      if (!id.startsWith('local-')) {
        await _api.deleteSale(id);
        await InventoryStore.instance.loadProducts();
      }
    } catch (_) {
      await _db.syncDao.enqueueSync(entityType: 'sale', action: 'delete', entityId: id);
    }
    _sales.removeWhere((s) => s.id == id);
    await _db.salesDao.deleteSale(id);
    notifyListeners();
  }

  Future<void> clearAllSales() async {
    final snapshot = List<Sale>.from(_sales);
    for (final sale in snapshot) {
      try {
        if (!sale.id.startsWith('local-')) {
          await _api.deleteSale(sale.id);
        }
      } catch (_) {}
    }
    _sales.clear();
    await _db.salesDao.clearSales();
    await InventoryStore.instance.loadProducts();
    notifyListeners();
  }

  void reset() {
    _sales = [];
    mockRecordSaleHandler = null;
    notifyListeners();
  }

  @visibleForTesting
  void setSalesForTesting(List<Sale> sales) {
    _sales = List.from(sales);
    notifyListeners();
  }

  List<Sale> get todaysSales =>
      _sales.where((s) => isSameDay(s.date, DateTime.now())).toList();

  /// Sales completed and collected today (cash / online). Excludes unpaid Utang transactions.
  List<Sale> get todaysCollectedSales =>
      todaysSales.where((s) => !s.isUtang).toList();

  /// Total collected earnings today (excludes unpaid Utang/Credit).
  double get todaysTotal =>
      todaysCollectedSales.fold(0.0, (sum, s) => sum + s.total);

  int get todaysSalesCount => todaysCollectedSales.length;

  double get todaysAverage =>
      todaysSalesCount == 0 ? 0 : todaysTotal / todaysSalesCount;

  /// All-time collected revenue (excludes unpaid Utang).
  double get allTimeTotal =>
      _sales.where((s) => !s.isUtang).fold(0.0, (sum, s) => sum + s.total);

  /// Total Utang charged today (unpaid credit receivable).
  double get todaysUtangTotal =>
      todaysSales.where((s) => s.isUtang).fold(0.0, (sum, s) => sum + s.total);

  String get changeBadge {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yTotal = _sales
        .where((s) => isSameDay(s.date, yesterday) && !s.isUtang)
        .fold(0.0, (sum, s) => sum + s.total);
    if (yTotal == 0) {
      return todaysTotal > 0 ? '↗ +100%' : '0%';
    }
    final pct = ((todaysTotal - yTotal) / yTotal) * 100;
    final sign = pct >= 0 ? '↗ +' : '↘ ';
    return '$sign${pct.abs().toStringAsFixed(0)}%';
  }
}
