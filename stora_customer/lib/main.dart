import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/order_provider.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.resolve();

  final authProvider = AuthProvider();
  final loggedIn = await authProvider.tryAutoLogin();

  await CustomerThemeController.instance.init();

  final initialRoute = !loggedIn
      ? '/login'
      : (authProvider.currentUser?.isEmailVerified == false ? '/verify-email' : '/home');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CustomerThemeController>.value(value: CustomerThemeController.instance),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CatalogProvider>(create: (_) => CatalogProvider()),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
      ],
      child: StoraCustomerApp(initialRoute: initialRoute),
    ),
  );
}

class StoraCustomerApp extends StatelessWidget {
  final String initialRoute;

  const StoraCustomerApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<CustomerThemeController>();

    return MaterialApp(
      title: 'Stora Customer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.themeMode,
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/verify-email': (context) => EmailVerificationScreen(
              email: context.read<AuthProvider>().currentUser?.email ?? '',
            ),
        '/home': (context) => const MainShell(),
      },
    );
  }
}
