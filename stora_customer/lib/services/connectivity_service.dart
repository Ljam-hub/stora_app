import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  StreamSubscription<dynamic>? _subscription;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    _checkInitial();
    _subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  Future<void> _checkInitial() async {
    try {
      final dynamic result = await Connectivity().checkConnectivity();
      _updateStatus(result);
    } catch (_) {
      isOnline.value = true;
    }
  }

  void _updateStatus(dynamic result) {
    if (result is List) {
      final hasConnection = result.any((r) => r != ConnectivityResult.none);
      isOnline.value = hasConnection;
    } else if (result is ConnectivityResult) {
      isOnline.value = result != ConnectivityResult.none;
    } else {
      isOnline.value = true;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
