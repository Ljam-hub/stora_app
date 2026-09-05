import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../storage/session_manager.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  String? _token;
  String? _savedPhone;
  String? _savedAddress;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  String? get savedPhone => _savedPhone;
  String? get savedAddress => _savedAddress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null && _token != null && _token!.isNotEmpty;

  String get greetingName {
    if (_currentUser == null) return 'Customer';
    return _currentUser!.displayName;
  }

  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final session = await SessionManager.instance.getSession();
      if (session != null && session.accessToken.isNotEmpty) {
        _token = session.accessToken;
        _currentUser = session.user;
        _savedPhone = session.savedPhone;
        _savedAddress = session.savedAddress;
        CustomerApiService.instance.accessToken = _token;

        // Verify and refresh profile in background
        try {
          final profile = await CustomerApiService.instance.fetchProfile();
          _currentUser = profile;
        } catch (_) {}

        NotificationService.instance.init();
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Auto login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await CustomerApiService.instance.login(email, password);
      final accessToken = res['access'] as String;
      final refreshToken = (res['refresh'] as String?) ?? '';
      final userJson = res['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);

      _token = accessToken;
      _currentUser = user;
      CustomerApiService.instance.accessToken = accessToken;

      final existingSession = await SessionManager.instance.getSession();
      _savedPhone = existingSession?.savedPhone;
      _savedAddress = existingSession?.savedAddress;

      await SessionManager.instance.saveSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
        savedPhone: _savedPhone,
        savedAddress: _savedAddress,
      );

      NotificationService.instance.init();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await CustomerApiService.instance.register(
        email: email,
        password: password,
        name: name,
      );
      final accessToken = res['access'] as String;
      final refreshToken = (res['refresh'] as String?) ?? '';
      final userJson = res['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);

      _token = accessToken;
      _currentUser = user;
      CustomerApiService.instance.accessToken = accessToken;

      await SessionManager.instance.saveSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );

      NotificationService.instance.init();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> saveDeliveryDetails({required String phone, required String address}) async {
    _savedPhone = phone;
    _savedAddress = address;
    await SessionManager.instance.updateDeliveryInfo(phone: phone, address: address);
    notifyListeners();
  }

  Future<bool> updateProfile({String? name, String? email}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await CustomerApiService.instance.updateProfile(name: name, email: email);
      _currentUser = updated;

      final session = await SessionManager.instance.getSession();
      if (session != null) {
        await SessionManager.instance.saveSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          user: updated,
          savedPhone: _savedPhone,
          savedAddress: _savedAddress,
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await SessionManager.instance.clearSession();
    _token = null;
    _currentUser = null;
    CustomerApiService.instance.accessToken = null;
    notifyListeners();
  }
}
