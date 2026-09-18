import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'session_manager.dart';

class HiddenProductsStore extends ChangeNotifier {
  HiddenProductsStore._();
  static final HiddenProductsStore instance = HiddenProductsStore._();

  final Set<int> _hiddenProductIds = {};
  final Map<int, Map<String, dynamic>> _hiddenProductDetails = {};
  final Map<int, DateTime> _reportedTimestamps = {};
  bool _initialized = false;

  Set<int> get hiddenProductIds => Set.unmodifiable(_hiddenProductIds);

  List<Map<String, dynamic>> get hiddenProductsList {
    return _hiddenProductIds.map((id) {
      return _hiddenProductDetails[id] ?? {
        'id': id,
        'name': 'Product #$id',
        'price': 0.0,
        'imageUrl': '',
        'storeName': '',
        'categoryName': '',
        'hiddenAt': DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  Future<void>? _initFuture;

  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    if (_initialized) return;
    try {
      final rawHidden = await SessionManager.instance.getSetting('hidden_product_ids');
      if (rawHidden != null && rawHidden.isNotEmpty) {
        final decoded = jsonDecode(rawHidden);
        if (decoded is List) {
          _hiddenProductIds.addAll(decoded.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0));
        }
      }

      final rawDetails = await SessionManager.instance.getSetting('hidden_product_details');
      if (rawDetails != null && rawDetails.isNotEmpty) {
        final decoded = jsonDecode(rawDetails);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final id = int.tryParse(entry.key.toString());
            if (id != null && entry.value is Map) {
              _hiddenProductDetails[id] = Map<String, dynamic>.from(entry.value as Map);
            }
          }
        }
      }

      final rawReported = await SessionManager.instance.getSetting('reported_product_timestamps');
      if (rawReported != null && rawReported.isNotEmpty) {
        final decoded = jsonDecode(rawReported);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final id = int.tryParse(entry.key.toString());
            final ts = DateTime.tryParse(entry.value.toString());
            if (id != null && ts != null) {
              _reportedTimestamps[id] = ts;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing HiddenProductsStore: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  bool isHidden(int productId) => _hiddenProductIds.contains(productId);

  /// Cooldown check: returns true if product was reported within the last 24 hours
  bool isReported(int productId) {
    final timestamp = _reportedTimestamps[productId];
    if (timestamp == null) return false;
    final diff = DateTime.now().difference(timestamp).abs();
    return diff.inHours < 24;
  }

  /// Reset all state — call on logout to prevent data leaking between sessions.
  void clear() {
    _hiddenProductIds.clear();
    _hiddenProductDetails.clear();
    _reportedTimestamps.clear();
    _initialized = false;
    _initFuture = null;
    notifyListeners();
  }

  Future<void> hideProduct(
    int productId, {
    String? name,
    double? price,
    String? imageUrl,
    String? storeName,
    String? categoryName,
  }) async {
    if (productId <= 0) return;
    _hiddenProductIds.add(productId);
    _hiddenProductDetails[productId] = {
      'id': productId,
      'name': name ?? 'Product #$productId',
      'price': price ?? 0.0,
      'imageUrl': imageUrl ?? '',
      'storeName': storeName ?? '',
      'categoryName': categoryName ?? '',
      'hiddenAt': DateTime.now().toIso8601String(),
    };
    notifyListeners();
    try {
      final raw = jsonEncode(_hiddenProductIds.toList());
      await SessionManager.instance.setSetting('hidden_product_ids', raw);
      final rawDetails = jsonEncode(_hiddenProductDetails);
      await SessionManager.instance.setSetting('hidden_product_details', rawDetails);
    } catch (_) {}
  }

  Future<void> unhideProduct(int productId) async {
    bool changed = _hiddenProductIds.remove(productId);
    _hiddenProductDetails.remove(productId);
    if (changed) {
      notifyListeners();
      try {
        final raw = jsonEncode(_hiddenProductIds.toList());
        await SessionManager.instance.setSetting('hidden_product_ids', raw);
        final rawDetails = jsonEncode(_hiddenProductDetails);
        await SessionManager.instance.setSetting('hidden_product_details', rawDetails);
      } catch (_) {}
    }
  }

  Future<void> unhideAll() async {
    if (_hiddenProductIds.isNotEmpty) {
      _hiddenProductIds.clear();
      _hiddenProductDetails.clear();
      notifyListeners();
      try {
        await SessionManager.instance.setSetting('hidden_product_ids', '[]');
        await SessionManager.instance.setSetting('hidden_product_details', '{}');
      } catch (_) {}
    }
  }

  Future<void> markReported(int productId) async {
    if (productId <= 0) return;
    _reportedTimestamps[productId] = DateTime.now();
    notifyListeners();
    try {
      final map = _reportedTimestamps.map((k, v) => MapEntry(k.toString(), v.toIso8601String()));
      await SessionManager.instance.setSetting('reported_product_timestamps', jsonEncode(map));
    } catch (_) {}
  }
}
