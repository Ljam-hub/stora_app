import 'package:flutter_test/flutter_test.dart';
import 'package:stora/data/models/account_status.dart';
import 'package:stora/home/models/product.dart';
import 'package:stora/home/stores/cart_store.dart';

void main() {
  group('CartStore & Barcode scanning direct cart addition', () {
    setUp(() {
      CartStore.instance.clear();
    });

    test('adding product directly increments cart total and quantity', () {
      final p = Product(
        id: '1',
        name: 'Test Milk',
        category: 'Beverages',
        price: 50.0,
        stock: 10,
        barcode: '4800012345678',
      );

      CartStore.instance.add(p);
      expect(CartStore.instance.items.length, 1);
      expect(CartStore.instance.items.first.product.name, 'Test Milk');
      expect(CartStore.instance.items.first.quantity, 1);
      expect(CartStore.instance.total, 50.0);

      // Adding again increments quantity
      CartStore.instance.add(p);
      expect(CartStore.instance.items.length, 1);
      expect(CartStore.instance.items.first.quantity, 2);
      expect(CartStore.instance.total, 100.0);
    });
  });

  group('AccountStatusStore Dynamic Pricing & 31-day model', () {
    test('parses dynamic monthly price and GCash config from backend json', () {
      final json = {
        'is_premium': true,
        'premium_until': '2026-10-01T00:00:00Z',
        'product_count': 15,
        'product_limit': 0,
        'days_left': 31,
        'can_add_product': true,
        'monthly_price': 85.50,
        'gcash_number': '0918 888 9999',
        'gcash_name': 'STORA Payments',
      };

      final status = AccountStatus.fromJson(json);
      expect(status.isPremium, isTrue);
      expect(status.daysLeft, 31);
      expect(status.monthlyPrice, 85.50);
      expect(status.gcashNumber, '0918 888 9999');
      expect(status.gcashName, 'STORA Payments');
    });
  });
}
