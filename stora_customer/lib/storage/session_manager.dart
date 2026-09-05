import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';

class CustomerSession {
  final String accessToken;
  final String refreshToken;
  final UserModel user;
  final String? savedPhone;
  final String? savedAddress;

  CustomerSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.savedPhone,
    this.savedAddress,
  });
}

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    String dbPath;
    if (kIsWeb) {
      dbPath = 'stora_customer.db';
    } else {
      final databasesPath = await getDatabasesPath();
      dbPath = '$databasesPath/stora_customer.db';
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE session (
            id INTEGER PRIMARY KEY,
            access_token TEXT NOT NULL,
            refresh_token TEXT NOT NULL,
            user_json TEXT NOT NULL,
            saved_phone TEXT,
            saved_address TEXT,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required UserModel user,
    String? savedPhone,
    String? savedAddress,
  }) async {
    try {
      final db = await database;
      await db.insert(
        'session',
        {
          'id': 1,
          'access_token': accessToken,
          'refresh_token': refreshToken,
          'user_json': jsonEncode(user.toJson()),
          'saved_phone': savedPhone,
          'saved_address': savedAddress,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  Future<CustomerSession?> getSession() async {
    try {
      final db = await database;
      final results = await db.query('session', where: 'id = 1', limit: 1);
      if (results.isEmpty) return null;

      final row = results.first;
      final accessToken = row['access_token'] as String;
      final refreshToken = row['refresh_token'] as String;
      final userJson = jsonDecode(row['user_json'] as String) as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);
      final savedPhone = row['saved_phone'] as String?;
      final savedAddress = row['saved_address'] as String?;

      return CustomerSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
        savedPhone: savedPhone,
        savedAddress: savedAddress,
      );
    } catch (e) {
      debugPrint('Error loading session: $e');
      return null;
    }
  }

  Future<void> updateDeliveryInfo({String? phone, String? address}) async {
    try {
      final db = await database;
      final values = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (phone != null) values['saved_phone'] = phone;
      if (address != null) values['saved_address'] = address;
      await db.update('session', values, where: 'id = 1');
    } catch (e) {
      debugPrint('Error updating delivery info: $e');
    }
  }

  Future<void> clearSession() async {
    try {
      final db = await database;
      await db.delete('session');
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }
}
