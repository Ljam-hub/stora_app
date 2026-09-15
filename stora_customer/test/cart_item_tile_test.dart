import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stora_customer/models/cart_item_model.dart';
import 'package:stora_customer/models/product_model.dart';
import 'package:stora_customer/widgets/cart_item_tile.dart';

void main() {
  testWidgets('CartItemTile displays delete button to the left of quantity stepper', (WidgetTester tester) async {
    final product = ProductModel(
      id: 1,
      name: 'Cold Brew Coffee',
      price: 120.0,
      stock: 10,
      categoryName: 'Beverages',
    );
    final item = CartItemModel(product: product, quantity: 2);

    bool incrementPressed = false;
    bool decrementPressed = false;
    bool removePressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartItemTile(
            item: item,
            onIncrement: () => incrementPressed = true,
            onDecrement: () => decrementPressed = true,
            onRemove: () => removePressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Cold Brew Coffee'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Verify delete button is positioned to the left of the remove icon
    final deletePos = tester.getCenter(find.byIcon(Icons.delete_outline_rounded));
    final minusPos = tester.getCenter(find.byIcon(Icons.remove));
    expect(deletePos.dx, lessThan(minusPos.dx), reason: 'Delete button must be to the left of - 1 +');

    // Test actions
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    expect(removePressed, isTrue);

    await tester.tap(find.byIcon(Icons.add));
    expect(incrementPressed, isTrue);

    await tester.tap(find.byIcon(Icons.remove));
    expect(decrementPressed, isTrue);
  });
}
