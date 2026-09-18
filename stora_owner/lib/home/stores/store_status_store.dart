import 'package:flutter/material.dart';
import '../../data/api/api_client.dart';

class StoreStatusStore extends ChangeNotifier {
  StoreStatusStore._();
  static final StoreStatusStore instance = StoreStatusStore._();

  bool _isOpen = true;
  bool _isLoaded = false;
  bool _isUpdating = false;
  double _latitude = 14.5995;
  double _longitude = 120.9842;
  String _address = '';

  bool get isOpen => _isOpen;
  bool get isLoaded => _isLoaded;
  bool get isUpdating => _isUpdating;
  double get latitude => _latitude;
  double get longitude => _longitude;
  String get address => _address;

  bool get hasValidLocation {
    if (!_isLoaded) return true;
    if (_latitude == 0 && _longitude == 0) return false;
    final isDefaultManila = (_latitude - 14.5995).abs() < 0.0001 &&
                            (_longitude - 120.9842).abs() < 0.0001;
    if (isDefaultManila && (_address.isEmpty || _address == 'Metro Manila, Philippines')) {
      return false;
    }
    return true;
  }

  static bool _parseBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return fallback;
  }

  Future<void> fetchStatus() async {
    if (_isUpdating) return;
    try {
      final data = await ApiClient.instance.getStoreLocation();
      if (!_isUpdating) {
        _isOpen = _parseBool(data['is_open'], _isOpen);
      }
      _latitude = (data['latitude'] is num)
          ? (data['latitude'] as num).toDouble()
          : (double.tryParse(data['latitude']?.toString() ?? '14.5995') ?? 14.5995);
      _longitude = (data['longitude'] is num)
          ? (data['longitude'] as num).toDouble()
          : (double.tryParse(data['longitude']?.toString() ?? '120.9842') ?? 120.9842);
      _address = data['address']?.toString() ?? '';
      _isLoaded = true;
      notifyListeners();
    } catch (_) {
      // Keep existing values on network/offline error
    }
  }

  Future<bool> setOpenStatus(bool open) async {
    if (_isUpdating) return _isOpen;
    final previous = _isOpen;
    _isOpen = open;
    _isUpdating = true;
    notifyListeners();

    try {
      final data = await ApiClient.instance.updateStoreOpenStatus(open);
      _isOpen = _parseBool(data['is_open'], open);
      return _isOpen;
    } catch (e) {
      // Rollback on error
      _isOpen = previous;
      rethrow;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  void updateLocalCoordinates({
    required double latitude,
    required double longitude,
    required String address,
    bool? isOpen,
  }) {
    _latitude = latitude;
    _longitude = longitude;
    _address = address;
    if (isOpen != null) _isOpen = isOpen;
    notifyListeners();
  }

  void reset() {
    _isOpen = true;
    _isLoaded = false;
    _isUpdating = false;
    _latitude = 14.5995;
    _longitude = 120.9842;
    _address = '';
    notifyListeners();
  }
}
