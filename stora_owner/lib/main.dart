import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:stora/auth/auth_store.dart';
import 'package:stora/data/api/api_config.dart';
import 'package:stora/data/sync/sync_manager.dart';
import 'package:stora/home/shell/stora_shell.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'stora_login/stora_login.dart';

Future<void> _initSqlite() async {
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await _initSqlite();
  await ApiConfig.resolve();
  SyncManager.instance.init();
  final loggedIn = await AuthStore.instance.restore();
  if (loggedIn) {
    SyncManager.instance.syncNow();
  }
  runApp(MyApp(initialRoute: loggedIn ? '/home' : '/login'));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialRoute = '/login'});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B87F5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const StoraShell(),
      },
    );
  }
}
