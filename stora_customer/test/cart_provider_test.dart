import 'package:flutter_test/flutter_test.dart';
import 'package:stora_customer/models/order_model.dart';
import 'package:stora_customer/models/product_model.dart';
import 'package:stora_customer/providers/cart_provider.dart';

void main() {
  group('CartProvider Unit Tests', () {
    late CartProvider cart;

    setUp(() {
      cart = CartProvider();
    });

    test('Initial cart is empty', () {
      expect(cart.isEmpty, isTrue);
      expect(cart.isNotEmpty, isFalse);
      expect(cart.totalItemCount, 0);
      expect(cart.totalAmount, 0.0);
      expect(cart.storeId, isNull);
    });

    test('Adding item within stock updates items and total', () {
      final product = ProductModel(
        id: 101,
        name: 'Organic Milk',
        price: 95.0,
        stock: 5,
        ownerId: 1,
        storeName: 'Farm Fresh',
      );

      final added = cart.addItem(product, 2);
      expect(added, isTrue);
      expect(cart.isEmpty, isFalse);
      expect(cart.totalItemCount, 2);
      expect(cart.totalAmount, 190.0);
      expect(cart.storeId, 1);
      expect(cart.storeName, 'Farm Fresh');
      expect(cart.getQuantity(101), 2);
    });

    test('Cannot add out of stock product or exceed stock', () {
      final product = ProductModel(
        id: 102,
        name: 'Rare Item',
        price: 50.0,
        stock: 2,
        ownerId: 1,
      );

      expect(cart.addItem(product, 2), isTrue);
      expect(cart.addItem(product, 1), isFalse); // Stock limit reached
      expect(cart.getQuantity(102), 2);

      final outOfStockProduct = ProductModel(
        id: 103,
        name: 'Sold Out',
        price: 50.0,
        stock: 0,
        ownerId: 1,
      );
      expect(cart.addItem(outOfStockProduct, 1), isFalse);
    });

    test('Increment, decrement, and updateQuantity', () {
      final product = ProductModel(
        id: 104,
        name: 'Bread',
        price: 45.0,
        stock: 3,
        ownerId: 1,
      );

      cart.addItem(product, 1);
      expect(cart.getQuantity(104), 1);

      cart.increment(104);
      expect(cart.getQuantity(104), 2);

      // Cannot increment past stock
      cart.increment(104);
      expect(cart.getQuantity(104), 3);
      cart.increment(104);
      expect(cart.getQuantity(104), 3);

      cart.decrement(104);
      expect(cart.getQuantity(104), 2);

      cart.updateQuantity(104, 1);
      expect(cart.getQuantity(104), 1);

      cart.updateQuantity(104, 0); // Removes item
      expect(cart.getQuantity(104), 0);
      expect(cart.isEmpty, isTrue);
    });

    test('Cross-store conflict prevents adding item from another store', () {
      final prodStore1 = ProductModel(
        id: 105,
        name: 'Store 1 Item',
        price: 20.0,
        stock: 5,
        ownerId: 1,
      );
      final prodStore2 = ProductModel(
        id: 106,
        name: 'Store 2 Item',
        price: 30.0,
        stock: 5,
        ownerId: 2,
      );

      expect(cart.addItem(prodStore1, 1), isTrue);
      expect(cart.addItem(prodStore2, 1), isFalse); // Conflict
      expect(cart.items.length, 1);
    });

    test('addOrderItems handles cross-store conflict and clearExisting', () {
      final prodStore1 = ProductModel(
        id: 107,
        name: 'Store 1 Item',
        price: 20.0,
        stock: 5,
        ownerId: 1,
      );
      cart.addItem(prodStore1, 1);

      final orderFromStore2 = CustomerOrder(
        id: 50,
        ownerId: 2,
        storeName: 'Store 2',
        customerName: 'Juan',
        customerPhone: '09123456789',
        customerAddress: 'Manila',
        notes: '',
        status: 'completed',
        totalAmount: 100.0,
        items: [
          CustomerOrderItem(id: 1, productId: 201, productName: 'S2 Item 1', quantity: 2, unitPrice: 50.0),
        ],
      );

      // Without clearing, should return -1
      expect(cart.addOrderItems(orderFromStore2, clearExisting: false), -1);

      // With clearing, replaces and adds
      final count = cart.addOrderItems(orderFromStore2, clearExisting: true);
      expect(count, 1);
      expect(cart.storeId, 2);
      expect(cart.getQuantity(201), 2);
    });

    test('addOrderItems with freshProducts uses latest stock and prices', () {
      final order = CustomerOrder(
        id: 51,
        ownerId: 1,
        storeName: 'Store 1',
        customerName: 'Juan',
        customerPhone: '09123456789',
        customerAddress: 'Manila',
        notes: '',
        status: 'completed',
        totalAmount: 100.0,
        items: [
          CustomerOrderItem(id: 1, productId: 301, productName: 'Coffee', quantity: 5, unitPrice: 50.0),
        ],
      );

      // Fresh product only has 3 in stock and updated price of 60.0
      final freshProducts = [
        ProductModel(
          id: 301,
          name: 'Coffee',
          price: 60.0,
          stock: 3,
          ownerId: 1,
        ),
      ];

      final count = cart.addOrderItems(order, freshProducts: freshProducts);
      expect(count, 1);
      expect(cart.getQuantity(301), 3); // Capped to stock 3
      expect(cart.totalAmount, 180.0); // 3 * 60.0
    });
  });
}
