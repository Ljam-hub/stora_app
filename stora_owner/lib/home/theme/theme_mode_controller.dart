import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ThemeModeController extends ChangeNotifier {
  ThemeModeController._();
  static final ThemeModeController instance = ThemeModeController._();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  File? _settingsFile;

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _settingsFile = File(p.join(dir.path, 'theme_preference.txt'));
      if (await _settingsFile!.exists()) {
        final content = (await _settingsFile!.readAsString()).trim().toLowerCase();
        if (content == 'light') {
          _themeMode = ThemeMode.light;
        } else if (content == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (content == 'system') {
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
      if (_settingsFile != null) {
        String val = 'dark';
        if (mode == ThemeMode.light) val = 'light';
        if (mode == ThemeMode.system) val = 'system';
        await _settingsFile!.writeAsString(val);
      }
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}
