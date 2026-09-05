import 'package:flutter/material.dart';

import '../data/api/api_client.dart';
import '../data/db/stora_database.dart';
import '../data/services/notification_service.dart';

class AuthStore extends ChangeNotifier {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  String? email;
  String? businessName;
  bool get isLoggedIn => email != null && email!.isNotEmpty;

  String get greetingName {
    final name = (businessName ?? '').trim();
    if (name.isEmpty) {
      final mail = email ?? '';
      if (mail.contains('@')) return mail.split('@').first;
      return 'there';
    }
    return name.split(RegExp(r'\s+')).first;
  }

  Future<bool> restore() async {
    final session = await AppDatabase.instance.authDao.readSession();
    if (session == null || session.accessToken.isEmpty) return false;
    email = session.email;
    businessName = session.businessName;
    OwnerNotificationService.instance.init();
    notifyListeners();
    return true;
  }

  Future<void> login({required String email, required String password}) async {
    final result = await ApiClient.instance.login(email: email, password: password);
    await _persist(result);
  }

  Future<void> register({
    required String email,
    required String password,
    required String businessName,
  }) async {
    final result = await ApiClient.instance.register(
      email: email,
      password: password,
      businessName: businessName,
    );
    await _persist(result);
  }

  Future<void> updateProfile({String? newBusinessName, String? newEmail}) async {
    final res = await ApiClient.instance.updateProfile(
      businessName: newBusinessName,
      email: newEmail,
    );
    final updatedEmail = (res['email'] as String?) ?? email;
    final updatedBusinessName = (res['business_name'] as String?) ?? businessName;

    final session = await AppDatabase.instance.authDao.readSession();
    if (session != null) {
      await AppDatabase.instance.authDao.saveSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        email: updatedEmail ?? session.email,
        businessName: updatedBusinessName ?? session.businessName,
      );
    }
    email = updatedEmail;
    businessName = updatedBusinessName;
    notifyListeners();
  }

  Future<String> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return await ApiClient.instance.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  Future<void> logout() async {
    await AppDatabase.instance.authDao.clearSession();
    email = null;
    businessName = null;
    notifyListeners();
  }

  Future<void> _persist(AuthResult result) async {
    if (email != null && email != result.email) {
      await AppDatabase.instance.authDao.clearSession();
    }
    await AppDatabase.instance.authDao.saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      email: result.email,
      businessName: result.businessName,
    );
    email = result.email;
    businessName = result.businessName;
    OwnerNotificationService.instance.init();
    notifyListeners();
  }
}
