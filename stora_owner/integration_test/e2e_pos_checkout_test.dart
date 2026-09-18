import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:stora/auth/auth_store.dart';
import 'package:stora/data/api/api_client.dart';
import 'package:stora/home/models/cart_item.dart';
import 'package:stora/home/models/product.dart';
import 'package:stora/home/models/sale.dart';
import 'package:stora/home/stores/cart_store.dart';
import 'package:stora/home/stores/chat_store.dart';
import 'package:stora/home/stores/inventory_store.dart';
import 'package:stora/home/stores/orders_store.dart';
import 'package:stora/home/stores/sales_store.dart';
import 'package:stora/main.dart';

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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  group('Owner End-to-End Integration Flow', () {
    testWidgets(
      'Full Owner Journey: Login -> Navigate to POS -> Add Product to Cart -> Checkout & Complete Cash Payment -> Verify Receipt',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final auth = AuthStore.instance;
        final inventory = InventoryStore.instance;
        final cart = CartStore.instance;
        final sales = SalesStore.instance;
        final orders = OrdersStore.instance;
        final chat = ChatStore.instance;

        addTearDown(() {
          orders.stopPolling();
          chat.stopPolling();
          cart.clear();
          sales.reset();
          inventory.reset();
        });

        final testProduct = Product(
          id: '1',
          name: 'Instant Noodles Spicy',
          category: 'Grocery',
          price: 35.0,
          stock: 15,
          barcode: '4801234567890',
        );

        inventory.setProductsForTesting([testProduct], lock: true);

        auth.mockLoginHandler = ({required String email, required String password}) async {
          if (email == 'owner@stora.com' && password == 'ownerpass123') {
            auth.setUserForTesting(
              email: email,
              businessName: 'Nena Sari-Sari Store',
              isEmailVerified: true,
            );
            return;
          }
          throw ApiException('Invalid credentials');
        };

        sales.mockRecordSaleHandler = (
          items,
          total, {
          cashTendered,
          changeAmount,
          customerName,
        }) async {
          return Sale(
            id: 'sale-999',
            date: DateTime.now(),
            items: items.map((i) => CartItem(product: i.product, quantity: i.quantity)).toList(),
            total: total,
            cashTendered: cashTendered ?? 50.0,
            changeAmount: changeAmount ?? (50.0 - total),
            customerName: customerName ?? 'Walk-in Customer',
            receiptNumber: 'POS-TEST-999',
            channel: 'in_store',
          );
        };

        // 1. Pump App at /login
        await tester.pumpWidget(const MyApp(initialRoute: '/login'));
        await pumpSteps(tester, steps: 5);

        // Verify Login Screen Elements
        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.byKey(const Key('loginEmailField')), findsOneWidget);
        expect(find.byKey(const Key('loginPasswordField')), findsOneWidget);
        expect(find.byKey(const Key('loginSubmitButton')), findsOneWidget);

        // 2. Perform Owner Login
        await tester.enterText(
          find.byKey(const Key('loginEmailField')),
          'owner@stora.com',
        );
        await tester.enterText(
          find.byKey(const Key('loginPasswordField')),
          'ownerpass123',
        );
        await pumpSteps(tester, steps: 3);

        await tester.tap(find.byKey(const Key('loginSubmitButton')));

        // Wait until navigation transitions to StoraShell
        await pumpUntilFound(tester, find.byKey(const Key('nav_tab_sales')));
        orders.stopPolling();
        chat.stopPolling();

        // 3. Navigate to POS / Sales Tab
        final salesTab = find.byKey(const Key('nav_tab_sales'));
        expect(salesTab, findsOneWidget);
        await tester.tap(salesTab);
        await pumpUntilFound(tester, find.text('Virtual Cart'));

        // Verify POS Screen and Product Card
        expect(find.text('Virtual Cart'), findsOneWidget);
        expect(find.text('Virtual cart is empty'), findsOneWidget);
        expect(find.text('Instant Noodles Spicy'), findsOneWidget);
        expect(find.text('₱35.00'), findsWidgets);

        // 4. Add Product to Virtual Cart
        final productCard = find.byKey(const ValueKey('pos_product_1'));
        expect(productCard, findsOneWidget);
        await tester.tap(productCard);
        await pumpSteps(tester, steps: 5);

        expect(cart.items.length, 1);
        expect(cart.total, 35.0);
        expect(find.byKey(const Key('pos_checkout_button')), findsOneWidget);

        // 5. Tap Checkout to open Cash Payment Bottom Sheet
        await tester.tap(find.byKey(const Key('pos_checkout_button')));
        await pumpUntilFound(tester, find.text('Cash Payment'));
        await pumpSteps(tester, steps: 6, stepDuration: const Duration(milliseconds: 100));

        // Verify Cash Payment Sheet
        expect(find.text('Cash Payment'), findsOneWidget);
        expect(find.text('TOTAL DUE'), findsOneWidget);
        expect(find.byKey(const Key('confirm_payment_button')), findsOneWidget);

        // 6. Complete Cash Payment
        await tester.tap(find.byKey(const Key('confirm_payment_button')));
        await pumpUntilFound(tester, find.text('OFFICIAL RECEIPT'));
        await pumpSteps(tester, steps: 6, stepDuration: const Duration(milliseconds: 100));

        // 7. Verify Official Receipt Dialog
        expect(find.text('OFFICIAL RECEIPT'), findsOneWidget);
        expect(find.textContaining('POS-TEST-999'), findsOneWidget);
        expect(find.text('NENA SARI-SARI STORE'), findsOneWidget);
        expect(find.byKey(const Key('receipt_done_button')), findsOneWidget);

        // Verify Sale State
        expect(cart.items.isEmpty, isTrue);
        expect(sales.sales.length, 1);
        expect(sales.sales.first.receiptNumber, 'POS-TEST-999');
        expect(inventory.products.first.stock, 14);

        // 8. Close Receipt Dialog
        await tester.tap(find.byKey(const Key('receipt_done_button')));
        await pumpSteps(tester, steps: 5);

        // Back on POS Screen with Empty Cart
        expect(find.text('Virtual cart is empty'), findsOneWidget);
      },
    );
  });
}
