import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/stores/account_status_store.dart';

import '../../data/api/api_client.dart';
import '../../data/db/stora_database.dart';
import '../models/product.dart';
import '../utils/constants.dart';

/// Inventory store: Drift is the local source of truth; the Django API is
/// synced when the device is online.
class InventoryStore extends ChangeNotifier {
  InventoryStore._internal();
  static final InventoryStore instance = InventoryStore._internal();

  final _db = AppDatabase.instance;
  final _api = ApiClient.instance;

  List<Product> _products = [];
  bool _loading = false;
  String? _error;

  List<Product> get products => _products;
  bool get loading => _loading;
  String? get error => _error;

  int get totalStock => _products.fold(0, (sum, p) => sum + p.stock);

  List<Product> get lowStock => _products.where((p) => p.stock < 5).toList();

  Future<void> loadProducts() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _products = await _db.productDao.loadProducts();
      notifyListeners();
      final remote = await _api.listProducts();
      _products = remote.map(Product.fromJson).toList();
      await _db.productDao.replaceProducts(_products);
    } on ApiException catch (e) {
      if (_products.isEmpty) _error = e.message;
    } catch (e) {
      if (_products.isEmpty) _error = 'Network error: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  bool _savingProduct = false;
  final Set<String> _pendingProductDeletions = <String>{};

  Future<bool> addProduct(Product p) async {
    if (_savingProduct) return false;
    _savingProduct = true;
    try {
      p.stock = p.stock.clamp(0, kMaxStock);

    // Enforce cached plan limits before saving locally or online
    final accountStatus = AccountStatusStore.instance.status;
    if (!accountStatus.isPremium) {
      final trialEnds = accountStatus.trialEndsAt;
      if (trialEnds != null && DateTime.now().toUtc().isAfter(trialEnds.toUtc())) {
        _error = 'Your free trial has expired. Please upgrade to premium.';
        notifyListeners();
        return false;
      }
      if (accountStatus.productLimit > 0 && _products.length >= accountStatus.productLimit) {
        _error = 'Free plan limit reached (${accountStatus.productLimit} products). Please upgrade to premium.';
        notifyListeners();
        return false;
      }
    }

    try {
      final created = Product.fromJson(await _api.createProduct(p.toJson()));
      _products.add(created);
      await _db.productDao.upsertProduct(created);
      _error = null;
      notifyListeners();
      AccountStatusStore.instance.fetchStatus();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode != null && e.statusCode! < 500) {
        _error = e.message;
        notifyListeners();
        return false;
      }
      // If network error (statusCode == null or 5xx), fall through to offline save
    } catch (_) {
      // Offline fallback
    }

    // Offline fallback: save locally with temporary local ID and queue sync
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    p.id = localId;
    _products.add(p);
    await _db.productDao.upsertProduct(p);
    await _db.syncDao.enqueueSync(
      entityType: 'product',
      action: 'create',
      entityId: localId,
      payload: jsonEncode(p.toJson()),
    );
    _error = null;
    notifyListeners();
    return true;
    } finally {
      _savingProduct = false;
    }
  }

  Future<bool> updateProduct(Product p) async {
    p.stock = p.stock.clamp(0, kMaxStock);
    final isLocal = p.id.startsWith('local-');

    if (!isLocal) {
      try {
        final updated = Product.fromJson(await _api.updateProduct(p.id, p.toJson()));
        final idx = _products.indexWhere((item) => item.id == p.id);
        if (idx != -1) {
          _products[idx] = updated;
        }
        await _db.productDao.upsertProduct(updated);
        _error = null;
        notifyListeners();
        return true;
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          // If not found on server, re-create on server seamlessly
          try {
            final created = Product.fromJson(await _api.createProduct(p.toJson()));
            final idx = _products.indexWhere((item) => item.id == p.id);
            if (idx != -1) {
              _products[idx] = created;
            }
            await _db.productDao.deleteProduct(p.id);
            await _db.productDao.upsertProduct(created);
            _error = null;
            notifyListeners();
            return true;
          } catch (_) {}
        }
        if (e.statusCode != null && e.statusCode! < 500) {
          _error = e.message;
          notifyListeners();
          return false;
        }
        // Network failure: fall through to save locally and queue sync
      } catch (_) {
        // Network failure: fall through to save locally and queue sync
      }
    }

    // Local / Offline save
    final idx = _products.indexWhere((item) => item.id == p.id);
    if (idx != -1) {
      _products[idx] = p;
    }
    await _db.productDao.upsertProduct(p);
    await _db.syncDao.enqueueSync(
      entityType: 'product',
      action: 'update',
      entityId: p.id,
      payload: jsonEncode(p.toJson()),
    );
    _error = null;
    notifyListeners();
    return true;
  }

  Future<bool> removeProduct(String id) async {
    if (_pendingProductDeletions.contains(id)) return false;
    _pendingProductDeletions.add(id);
    try {
      final isLocal = id.startsWith('local-');

      bool remoteDeleted = false;
      if (!isLocal) {
        try {
          await _api.deleteProduct(id);
          remoteDeleted = true;
        } on ApiException catch (e) {
          if (e.statusCode == 404) {
            // Already removed from server — continue with local deletion
            remoteDeleted = true;
          } else if (e.statusCode != null && e.statusCode! < 500) {
            _error = e.message;
            notifyListeners();
            return false;
          }
          // Network failure: fall through to delete locally and queue sync
        } catch (_) {
          // Network failure: fall through to delete locally and queue sync
        }
      }

      _products.removeWhere((p) => p.id == id);
      await _db.productDao.deleteProduct(id);
      if (!isLocal && !remoteDeleted) {
        await _db.syncDao.enqueueSync(
          entityType: 'product',
          action: 'delete',
          entityId: id,
        );
      }
      _error = null;
      notifyListeners();
      AccountStatusStore.instance.fetchStatus();
      return true;
    } finally {
      _pendingProductDeletions.remove(id);
    }
  }


  Future<void> adjustStock(String id, int delta) async {
    final idx = _products.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _products[idx].stock = (_products[idx].stock + delta).clamp(0, kMaxStock);
      notifyListeners();
    }

    try {
      final res = await _api.adjustStock(id, delta);
      final currentIdx = _products.indexWhere((p) => p.id == id);
      if (res != null) {
        final updated = Product.fromJson(res);
        if (currentIdx != -1) {
          _products[currentIdx] = updated;
          notifyListeners();
        }
        await _db.productDao.upsertProduct(updated);
      } else {
        if (currentIdx != -1) {
          await _db.productDao.upsertProduct(_products[currentIdx]);
        }
      }
    } catch (_) {
      await loadProducts();
    }
  }

  Future<void> applyLocalStockDelta(String id, int delta) async {
    final idx = _products.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    _products[idx].stock = (_products[idx].stock + delta).clamp(0, kMaxStock);
    await _db.productDao.upsertProduct(_products[idx]);
    notifyListeners();
  }

  void reset() {
    _products = [];
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void touch() => notifyListeners();
}
