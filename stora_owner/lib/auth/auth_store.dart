import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../data/api/api_client.dart';
import '../data/db/stora_database.dart';
import '../data/services/notification_service.dart';
import '../home/stores/orders_store.dart';

class AuthStore extends ChangeNotifier {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  String? email;
  String? businessName;
  String? avatarUrl;
  bool isEmailVerified = false;
  bool get isLoggedIn => email != null && email!.isNotEmpty;

  String get greetingName {
    final name = (businessName ?? '').trim();
    if (name.isEmpty) {
      final mail = email ?? '';
      if (mail.contains('@')) return mail.split('@').first;
      return 'Store Owner';
    }
    return name;
  }

  Future<bool> init() async {
    final session = await AppDatabase.instance.authDao.readSession();
    if (session == null) return false;
    email = session.email;
    businessName = session.businessName;
    try {
      final me = await ApiClient.instance.getMe();
      isEmailVerified = me['is_email_verified'] == true;
      avatarUrl = me['avatar_url'] as String?;
    } catch (_) {}
    OwnerNotificationService.instance.init();
    notifyListeners();
    return true;
  }

  Future<bool> restore() => init();

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
    if (result.accessToken.isNotEmpty) {
      await _persist(result);
    } else {
      this.email = email;
      this.businessName = businessName;
      isEmailVerified = false;
      notifyListeners();
    }
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

  Future<void> verifyEmail(String code, {String? targetEmail}) async {
    final mail = (targetEmail != null && targetEmail.trim().isNotEmpty)
        ? targetEmail.trim()
        : email;
    if (mail == null || mail.isEmpty) {
      throw ApiException('No registered email found to verify.');
    }
    final result = await ApiClient.instance.verifyEmail(
      email: mail,
      code: code,
    );
    await _persist(result);
  }

  Future<void> resendVerification({String? targetEmail}) async {
    final mail = (targetEmail != null && targetEmail.trim().isNotEmpty)
        ? targetEmail.trim()
        : email;
    if (mail == null || mail.isEmpty) {
      throw ApiException('No registered email found.');
    }
    await ApiClient.instance.resendVerification(email: mail);
  }

  Future<void> uploadAvatar(Uint8List imageBytes, String filename) async {
    final res = await ApiClient.instance.uploadAvatar(imageBytes, filename);
    avatarUrl = res['avatar_url'] as String?;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.clearFcmToken();
    } catch (_) {}
    OrdersStore.instance.clear();
    await AppDatabase.instance.authDao.clearSession();
    email = null;
    businessName = null;
    avatarUrl = null;
    isEmailVerified = false;
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
    avatarUrl = result.avatarUrl;
    isEmailVerified = result.isEmailVerified;
    OwnerNotificationService.instance.init();
    notifyListeners();
  }
}
