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
      _sales = remote.map(Sale.fromJson).toList();
      await _db.salesDao.replaceSales(_sales);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> recordSale(List<CartItem> items, double total) async {
    try {
      final created = Sale.fromJson(
        await _api.createSale({
          'items': items
              .map(
                (item) => {
                  'product': int.parse(item.product.id),
                  'quantity': item.quantity,
                },
              )
              .toList(),
        }),
      );
      _sales.add(created);
      await _db.salesDao.upsertSale(created);
      await InventoryStore.instance.loadProducts();
    } on ApiException catch (e) {
      if (e.statusCode != null && e.statusCode! < 500) {
        rethrow;
      }
      await _recordOfflineSale(items, total);
    } catch (_) {
      await _recordOfflineSale(items, total);
    }
    notifyListeners();
  }

  Future<void> _recordOfflineSale(List<CartItem> items, double total) async {
    final local = Sale(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      date: DateTime.now(),
      items: items.map((i) => CartItem(product: i.product, quantity: i.quantity)).toList(),
      total: total,
    );
    _sales.add(local);
    await _db.salesDao.upsertSale(local);
    for (final item in items) {
      await InventoryStore.instance.applyLocalStockDelta(item.product.id, -item.quantity);
    }
    final payload = jsonEncode({
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
