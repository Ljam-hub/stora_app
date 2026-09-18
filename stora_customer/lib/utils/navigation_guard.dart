import 'package:flutter/material.dart';

/// Mixin for [StatefulWidget] states to prevent rapid double-taps
/// from triggering concurrent or duplicate navigations, plus static pushSafely.
mixin NavigationGuard<T extends StatefulWidget> on State<T> {
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;

  Future<void> guardedNavigate(Future<void> Function() action) async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      await action();
    } finally {
      if (mounted) {
        _isNavigating = false;
      }
    }
  }

  static bool _globalNavigating = false;

  static Future<R?> pushSafely<R>(BuildContext context, Route<R> route) {
    if (_globalNavigating) return Future.value(null);
    _globalNavigating = true;
    Future.delayed(const Duration(milliseconds: 350), () {
      _globalNavigating = false;
    });
    return Navigator.of(context).push<R>(route);
  }
}
