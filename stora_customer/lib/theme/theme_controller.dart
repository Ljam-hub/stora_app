import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../storage/session_manager.dart';

class CustomerThemeController extends ChangeNotifier {
  CustomerThemeController._();
  static final CustomerThemeController instance = CustomerThemeController._();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> init() async {
    try {
      final db = await SessionManager.instance.database;
      // Ensure settings table exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      final rows = await db.query('app_settings', where: 'key = ?', whereArgs: ['theme_mode']);
      if (rows.isNotEmpty) {
        final val = rows.first['value'] as String;
        if (val == 'light') {
          _themeMode = ThemeMode.light;
        } else if (val == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (val == 'system') {
          _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final db = await SessionManager.instance.database;
      String val = 'dark';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.system) val = 'system';
      await db.insert(
        'app_settings',
        {'key': 'theme_mode', 'value': val},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}
