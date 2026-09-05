import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../db/stora_database.dart';
import '../stores/account_status_store.dart';
import '../../home/models/product.dart';
import '../../home/models/sale.dart';
import '../../home/stores/inventory_store.dart';
import '../../home/stores/sales_store.dart';

class SyncManager {
  SyncManager._();
  static final SyncManager instance = SyncManager._();

  final _db = AppDatabase.instance;
  final _api = ApiClient.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  void init() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        syncNow();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    final token = await _db.authDao.readAccessToken();
    if (token == null || token.isEmpty) return;

    _isSyncing = true;
    try {
      final entries = await _db.syncDao.getPendingSyncEntries();
      if (entries.isEmpty) {
        _isSyncing = false;
        return;
      }

      // 1. Sync Product changes in order
      final productEntries = entries.where((e) => e.entityType == 'product').toList();
      for (final entry in productEntries) {
        final success = await _syncProductEntry(entry);
        if (success) {
          await _db.syncDao.removeSyncEntry(entry.id);
        }
      }

      // 2. Sync Sale changes in order
      final remainingEntries = await _db.syncDao.getPendingSyncEntries();
      final saleEntries = remainingEntries.where((e) => e.entityType == 'sale').toList();
      for (final entry in saleEntries) {
        final success = await _syncSaleEntry(entry);
        if (success) {
          await _db.syncDao.removeSyncEntry(entry.id);
        }
      }

      // 3. Re-fetch account status & reload stores after syncing
      try {
        await AccountStatusStore.instance.fetchStatus();
      } catch (_) {}

      try {
        await InventoryStore.instance.loadProducts();
      } catch (_) {}

      try {
        await SalesStore.instance.loadSales();
      } catch (_) {}
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _syncProductEntry(SyncQueueEntry entry) async {
    try {
      if (entry.action == 'create') {
        if (entry.payload == null) return true;
        final body = Map<String, dynamic>.from(jsonDecode(entry.payload!) as Map);
        body.remove('id');
        final res = await _api.createProduct(body);
        final serverProduct = Product.fromJson(res);
        await _db.syncDao.reconcileProductId(entry.entityId, serverProduct);
        return true;
      } else if (entry.action == 'update') {
        if (entry.entityId.startsWith('local-')) {
          // Unsynced local product not yet assigned a server ID — skip until created
          return false;
        }
        if (entry.payload == null) return true;
        final body = Map<String, dynamic>.from(jsonDecode(entry.payload!) as Map);
        body.remove('id');
        await _api.updateProduct(entry.entityId, body);
        return true;
      } else if (entry.action == 'delete') {
        if (entry.entityId.startsWith('local-')) {
          return true;
        }
        try {
          await _api.deleteProduct(entry.entityId);
        } on ApiException catch (e) {
          if (e.statusCode == 404) return true;
          rethrow;
        }
        return true;
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('Product sync API error for #${entry.id}: ${e.message}');
      if (e.statusCode == 403 || (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500)) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _syncSaleEntry(SyncQueueEntry entry) async {
    try {
      if (entry.action == 'create') {
        if (entry.payload == null) return true;
        final body = Map<String, dynamic>.from(jsonDecode(entry.payload!) as Map);
        final rawItems = (body['items'] as List?) ?? [];
        final itemsPayload = <Map<String, dynamic>>[];

        for (final item in rawItems) {
          final prodIdStr = item['product'].toString();
          if (prodIdStr.startsWith('local-')) {
            // Product not yet assigned server ID; wait for product sync
            return false;
          }
          final prodId = int.tryParse(prodIdStr);
          if (prodId == null) return false;
          itemsPayload.add({
            'product': prodId,
            'quantity': item['quantity'],
          });
        }

        final res = await _api.createSale({'items': itemsPayload});
        final serverSale = Sale.fromJson(res);
        await _db.salesDao.deleteSale(entry.entityId);
        await _db.salesDao.upsertSale(serverSale);
        return true;
      } else if (entry.action == 'delete') {
        if (!entry.entityId.startsWith('local-')) {
          try {
            await _api.deleteSale(entry.entityId);
          } on ApiException catch (e) {
            if (e.statusCode == 404) return true;
            rethrow;
          }
        }
        return true;
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('Sale sync API error for #${entry.id}: ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }
}
