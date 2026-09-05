import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stora_customer/main.dart';
import 'package:stora_customer/providers/auth_provider.dart';
import 'package:stora_customer/providers/cart_provider.dart';
import 'package:stora_customer/providers/catalog_provider.dart';
import 'package:stora_customer/providers/order_provider.dart';

void main() {
  testWidgets('Stora Customer App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<CatalogProvider>(create: (_) => CatalogProvider()),
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
        ],
        child: const StoraCustomerApp(initialRoute: '/login'),
      ),
    );

    expect(find.text('Welcome to Stora'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
