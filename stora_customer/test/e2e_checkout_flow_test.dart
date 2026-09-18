import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stora_customer/main.dart';
import 'package:stora_customer/models/order_model.dart';
import 'package:stora_customer/models/product_model.dart';
import 'package:stora_customer/models/store_model.dart';
import 'package:stora_customer/models/user_model.dart';
import 'package:stora_customer/providers/auth_provider.dart';
import 'package:stora_customer/providers/cart_provider.dart';
import 'package:stora_customer/providers/catalog_provider.dart';
import 'package:stora_customer/providers/chat_provider.dart';
import 'package:stora_customer/providers/order_provider.dart';
import 'package:stora_customer/theme/theme_controller.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TimeoutException('Timed out waiting for finder');
}

Future<void> pumpSteps(
  WidgetTester tester, {
  int steps = 5,
  Duration stepDuration = const Duration(milliseconds: 100),
}) async {
  for (int i = 0; i < steps; i++) {
    await tester.pump(stepDuration);
  }
}

void main() {
  group('Customer End-to-End Integration Flow', () {
    testWidgets(
      'Full User Journey: Login -> Browse & Add to Cart -> View Cart -> Checkout & Place Order',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final authProvider = AuthProvider();
        final catalogProvider = CatalogProvider();
        final cartProvider = CartProvider();
        final orderProvider = OrderProvider();
        final chatProvider = ChatProvider();

        addTearDown(() {
          orderProvider.stopPolling();
          chatProvider.stopPolling();
        });

        final testUser = UserModel(
          id: 42,
          email: 'customer@stora.com',
          name: 'Maria Santos',
          isEmailVerified: true,
        );

        final testStore = StoreModel(
          id: 101,
          businessName: 'Stora Express',
          email: 'store101@stora.com',
          isOpen: true,
        );

        final testProduct = ProductModel(
          id: 1,
          name: 'Fresh Milk 1L',
          price: 95.0,
          stock: 10,
          ownerId: 101,
          storeName: 'Stora Express',
          categoryName: 'Beverages',
        );

        catalogProvider.setCatalogDataForTesting(
          stores: [testStore],
          products: [testProduct],
          selectedStore: testStore,
          lock: true,
        );

        authProvider.mockLoginHandler = (email, password) async {
          if (email == 'customer@stora.com' && password == 'password123') {
            authProvider.setUserForTesting(
              testUser,
              token: 'mock-jwt-token',
              phone: '09123456789',
              address: '123 Stora Ave, City',
            );
            return true;
          }
          return false;
        };

        orderProvider.mockPlaceOrderHandler = ({
          required int ownerId,
          required String customerName,
          required String customerPhone,
          required String customerAddress,
          String notes = '',
          required List<CustomerOrderItem> items,
        }) async {
          return CustomerOrder(
            id: 555,
            ownerId: ownerId,
            storeName: 'Stora Express',
            customerName: customerName,
            customerPhone: customerPhone,
            customerAddress: customerAddress,
            notes: notes,
            status: 'pending',
            totalAmount: 95.0,
            items: items,
          );
        };

        // 1. Pump App at /login
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CustomerThemeController>.value(
                value: CustomerThemeController.instance,
              ),
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<CatalogProvider>.value(value: catalogProvider),
              ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
              ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
              ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ],
            child: const StoraCustomerApp(initialRoute: '/login'),
          ),
        );
        await pumpSteps(tester, steps: 5);

        // Verify Login Screen
        expect(find.text('Welcome to Stora'), findsOneWidget);
        expect(find.byKey(const Key('login_email_input')), findsOneWidget);
        expect(find.byKey(const Key('login_password_input')), findsOneWidget);
        expect(find.byKey(const Key('login_submit_button')), findsOneWidget);

        // 2. Perform Login
        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'customer@stora.com',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'password123',
        );
        await pumpSteps(tester, steps: 3);

        await tester.tap(find.byKey(const Key('login_submit_button')));
        // Wait until navigation transitions to MainShell
        await pumpUntilFound(tester, find.text('Browse Stores'));

        // 3. Verify Navigation to Main Shell (Shop Tab)
        expect(find.text('Browse Stores'), findsOneWidget);
        expect(find.text('Fresh Milk 1L'), findsOneWidget);

        // 4. Add Product to Cart
        final addButton = find.byKey(const ValueKey('product_add_button_1'));
        expect(addButton, findsOneWidget);
        await tester.tap(addButton);
        await pumpSteps(tester, steps: 5);

        expect(cartProvider.totalItemCount, 1);
        expect(cartProvider.totalAmount, 95.0);

        // 5. Navigate to Cart Screen
        final cartTab = find.byKey(const Key('nav_tab_cart'));
        expect(cartTab, findsOneWidget);
        await tester.tap(cartTab);
        await pumpUntilFound(tester, find.text('My Shopping Cart'));

        expect(find.text('My Shopping Cart'), findsOneWidget);
        expect(find.text('Subtotal (1 items)'), findsOneWidget);
        expect(find.byKey(const Key('cart_checkout_button')), findsOneWidget);

        // 6. Proceed to Checkout
        await tester.tap(find.byKey(const Key('cart_checkout_button')));
        await pumpUntilFound(tester, find.text('Delivery Information'));

        expect(find.text('Delivery Information'), findsOneWidget);
        expect(find.byKey(const Key('checkout_place_order_button')), findsOneWidget);

        // 7. Place Order
        await tester.tap(find.byKey(const Key('checkout_place_order_button')));
        await pumpUntilFound(tester, find.text('Order Placed!'));
        // Allow the 400ms elastic dialog entrance animation to complete
        await pumpSteps(tester, steps: 6, stepDuration: const Duration(milliseconds: 100));

        // 8. Verify Order Confirmation Dialog
        expect(find.text('Order Placed!'), findsOneWidget);
        expect(find.textContaining('Order #555 has been submitted'), findsOneWidget);
        final trackButton = find.byKey(const Key('checkout_track_order_button'));
        expect(trackButton, findsOneWidget);

        // 9. Tap Track Order and Verify
        await tester.tap(trackButton);
        await pumpUntilFound(tester, find.text('My Orders'));

        // Cart is cleared after successful order
        expect(cartProvider.isEmpty, isTrue);
        // Arrived at Orders screen
        expect(find.text('My Orders'), findsOneWidget);
      },
    );
  });
}
