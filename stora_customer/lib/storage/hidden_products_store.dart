import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'session_manager.dart';

class HiddenProductsStore extends ChangeNotifier {
  HiddenProductsStore._();
  static final HiddenProductsStore instance = HiddenProductsStore._();

  final Set<int> _hiddenProductIds = {};
  final Map<int, DateTime> _reportedTimestamps = {};
  bool _initialized = false;

  Set<int> get hiddenProductIds => Set.unmodifiable(_hiddenProductIds);

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
    _reportedTimestamps.clear();
    _initialized = false;
    _initFuture = null;
    notifyListeners();
  }

  Future<void> hideProduct(int productId) async {
    if (productId <= 0) return;
    _hiddenProductIds.add(productId);
    notifyListeners();
    try {
      final raw = jsonEncode(_hiddenProductIds.toList());
      await SessionManager.instance.setSetting('hidden_product_ids', raw);
    } catch (_) {}
  }

  Future<void> unhideProduct(int productId) async {
    if (_hiddenProductIds.remove(productId)) {
      notifyListeners();
      try {
        final raw = jsonEncode(_hiddenProductIds.toList());
        await SessionManager.instance.setSetting('hidden_product_ids', raw);
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
