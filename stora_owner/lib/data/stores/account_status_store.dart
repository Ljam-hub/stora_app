import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/account_status.dart';

class AccountStatusStore extends ChangeNotifier {
  AccountStatusStore._();
  static final AccountStatusStore instance = AccountStatusStore._();

  AccountStatus _status = AccountStatus.fallback;
  bool _loading = false;
  String? _error;
  double? _lastKnownPrice;
  String? _priceChangePrompt;

  AccountStatus get status => _status;
  bool get loading => _loading;
  String? get error => _error;
  String? get priceChangePrompt => _priceChangePrompt;

  bool get canAddProduct {
    if (_status.isPremium) return true;
    final trialEnds = _status.trialEndsAt;
    if (trialEnds != null && DateTime.now().toUtc().isAfter(trialEnds.toUtc())) {
      return false;
    }
    if (_status.productLimit > 0 && _status.productCount >= _status.productLimit) {
      return false;
    }
    return _status.canAddProduct;
  }
  bool get isPremium => _status.isPremium;
  int get daysLeft => _status.daysLeft;
  int get productCount => _status.productCount;
  int get productLimit => _status.productLimit;
  double get monthlyPrice => _status.monthlyPrice;
  String get gcashNumber => _status.gcashNumber;
  String get gcashName => _status.gcashName;

  void clearPriceChangePrompt() {
    _priceChangePrompt = null;
    notifyListeners();
  }

  Future<void> fetchStatus() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.getAccountStatus();
      final previousPrice = _lastKnownPrice ?? _status.monthlyPrice;
      _status = AccountStatus.fromJson(data);

      if (_lastKnownPrice != null && _status.monthlyPrice != previousPrice) {
        _priceChangePrompt =
            'Subscription Price Update: Premium is now ₱${_status.monthlyPrice.toStringAsFixed(2)}/mo (previously ₱${previousPrice.toStringAsFixed(2)}/mo).';
      }
      _lastKnownPrice = _status.monthlyPrice;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Could not load account status';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void reset() {
    _status = AccountStatus.fallback;
    _error = null;
    _loading = false;
    _priceChangePrompt = null;
    _lastKnownPrice = null;
    notifyListeners();
  }
}