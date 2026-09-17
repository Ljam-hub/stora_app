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

  Future<void> loadSales() async {
    _sales = await _db.salesDao.loadSales();
    notifyListeners();
    try {
      final remote = await _api.listSales();
      final remoteSales = remote.map(Sale.fromJson).toList();
      final pendingLocal = _sales.where((s) => s.id.startsWith('local-')).toList();
      _sales = [...remoteSales, ...pendingLocal];
      await _db.salesDao.replaceSales(remoteSales);
    } catch (_) {}
    notifyListeners();
  }

  bool _recording = false;
  bool get recording => _recording;

  Future<Sale> recordSale(
    List<CartItem> items,
    double total, {
    double? cashTendered,
    double? changeAmount,
    String? customerName,
  }) async {
    if (_recording) {
      throw ApiException('A sale is already being processed.');
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
        );
      } finally {
        _recording = false;
      }
      notifyListeners();
      return sale;
    }
    try {
      final created = Sale.fromJson(
        await _api.createSale({
          'customer_name': customerName ?? 'Walk-in Customer',
          'items': items
              .map(
                (item) => {
                  'product': int.tryParse(item.product.id) ?? 0,
                  'quantity': item.quantity,
                },
              )
              .toList(),
        }),
      );
      final withCashDetails = created.copyWith(
        cashTendered: cashTendered,
        changeAmount: changeAmount,
        customerName: created.customerName ?? customerName ?? 'Walk-in Customer',
      );
      _sales.add(withCashDetails);
      await _db.salesDao.upsertSale(withCashDetails);
      for (final item in items) {
        InventoryStore.instance.decrementStockLocally(item.product.id, item.quantity);
      }
      unawaited(InventoryStore.instance.loadProducts());
      sale = withCashDetails;
    } on ApiException catch (e) {
      if (e.statusCode != null && e.statusCode! < 500) {
        rethrow;
      }
      sale = await _recordOfflineSale(
        items,
        total,
        cashTendered: cashTendered,
        changeAmount: changeAmount,
        customerName: customerName,
      );
    } catch (_) {
      sale = await _recordOfflineSale(
        items,
        total,
        cashTendered: cashTendered,
        changeAmount: changeAmount,
        customerName: customerName,
      );
    } finally {
      _recording = false;
    }
    notifyListeners();
    return sale;
  }

  Future<Sale> _recordOfflineSale(
    List<CartItem> items,
    double total, {
    double? cashTendered,
    double? changeAmount,
    String? customerName,
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
    );
    _sales.add(local);
    await _db.salesDao.upsertSale(local);
    for (final item in items) {
      await InventoryStore.instance.applyLocalStockDelta(item.product.id, -item.quantity);
    }
    final payload = jsonEncode({
      'customer_name': customerName ?? 'Walk-in Customer',
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
    notifyListeners();
  }

  List<Sale> get todaysSales =>
      _sales.where((s) => isSameDay(s.date, DateTime.now())).toList();

  double get todaysTotal => todaysSales.fold(0.0, (sum, s) => sum + s.total);

  int get todaysSalesCount => todaysSales.length;

  double get todaysAverage => todaysSalesCount == 0 ? 0 : todaysTotal / todaysSalesCount;

  double get allTimeTotal => _sales.fold(0.0, (sum, s) => sum + s.total);

  String get changeBadge {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yTotal =
        _sales.where((s) => isSameDay(s.date, yesterday)).fold(0.0, (sum, s) => sum + s.total);
    if (yTotal == 0) {
      return todaysTotal > 0 ? '↗ +100%' : '0%';
    }
    final pct = ((todaysTotal - yTotal) / yTotal) * 100;
    final sign = pct >= 0 ? '↗ +' : '↘ ';
    return '$sign${pct.abs().toStringAsFixed(0)}%';
  }
}
