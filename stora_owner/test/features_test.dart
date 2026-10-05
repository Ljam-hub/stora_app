import 'package:flutter_test/flutter_test.dart';
import 'package:stora/data/models/account_status.dart';
import 'package:stora/home/models/product.dart';
import 'package:stora/home/models/sale.dart';
import 'package:stora/home/stores/cart_store.dart';
import 'package:stora/home/stores/sales_store.dart';

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

      // Decrement quantity
      CartStore.instance.decrementQty(p.id);
      expect(CartStore.instance.items.first.quantity, 1);
      expect(CartStore.instance.total, 50.0);

      // Decrement to zero removes item
      CartStore.instance.decrementQty(p.id);
      expect(CartStore.instance.items, isEmpty);
      expect(CartStore.instance.total, 0.0);
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

  group('Sale & Receipt model verification', () {
    test('parses in-store walk-in sale correctly', () {
      final json = {
        'id': '101',
        'date': '2026-09-17T10:00:00Z',
        'total': '150.00',
        'customer_name': 'Walk-in Customer',
        'receipt_number': 'POS-101',
        'channel': 'in_store',
        'items': [],
      };

      final sale = Sale.fromJson(json);
      expect(sale.id, '101');
      expect(sale.displayCustomerName, 'Walk-in Customer');
      expect(sale.displayReceiptNumber, 'POS-101');
      expect(sale.isOnlineOrder, isFalse);
      expect(sale.orderId, isNull);
    });

    test('parses online order sale correctly with ORD receipt number', () {
      final json = {
        'id': '102',
        'date': '2026-09-17T10:00:00Z',
        'total': '250.00',
        'customer_name': 'Maria Clara',
        'receipt_number': 'ORD-42',
        'order_id': 42,
        'channel': 'online_order',
        'items': [],
      };

      final sale = Sale.fromJson(json);
      expect(sale.id, '102');
      expect(sale.displayCustomerName, 'Maria Clara');
      expect(sale.displayReceiptNumber, 'ORD-42');
      expect(sale.isOnlineOrder, isTrue);
      expect(sale.orderId, 42);
    });

    test('fallbacks work when receipt_number and customer_name are missing', () {
      final sale = Sale(
        id: '103',
        date: DateTime.now(),
        items: [],
        total: 50.0,
      );
      expect(sale.displayCustomerName, 'Walk-in Customer');
      expect(sale.displayReceiptNumber, 'POS-103');

      final orderSale = Sale(
        id: '104',
        date: DateTime.now(),
        items: [],
        total: 50.0,
        orderId: 77,
      );
      expect(sale.displayCustomerName, 'Walk-in Customer');
      expect(orderSale.displayReceiptNumber, 'ORD-77');
    });

    test('detects utang payment method correctly', () {
      final cashSale = Sale(
        id: '105',
        date: DateTime.now(),
        items: [],
        total: 100.0,
        paymentMethod: 'cash',
      );
      final utangSale = Sale(
        id: '106',
        date: DateTime.now(),
        items: [],
        total: 150.0,
        paymentMethod: 'utang',
      );
      final creditSale = Sale(
        id: '107',
        date: DateTime.now(),
        items: [],
        total: 75.0,
        paymentMethod: 'credit',
      );

      expect(cashSale.isUtang, isFalse);
      expect(cashSale.isCollected, isTrue);

      expect(utangSale.isUtang, isTrue);
      expect(utangSale.isCollected, isFalse);

      expect(creditSale.isUtang, isTrue);
      expect(creditSale.isCollected, isFalse);
    });

    test('SalesStore excludes Utang sales from todaysTotal and todaysSalesCount', () {
      final now = DateTime.now();
      final cash1 = Sale(id: 'c1', date: now, items: [], total: 100.0, paymentMethod: 'cash');
      final online1 = Sale(id: 'o1', date: now, items: [], total: 50.0, paymentMethod: 'online');
      final utang1 = Sale(id: 'u1', date: now, items: [], total: 200.0, paymentMethod: 'utang');

      final store = SalesStore.instance;
      store.setSalesForTesting([cash1, online1, utang1]);

      // Total of all sales is 350, but earnings collected is 150
      expect(store.todaysSales.length, 3);
      expect(store.todaysCollectedSales.length, 2);
      expect(store.todaysTotal, 150.0);
      expect(store.todaysSalesCount, 2);
      expect(store.todaysAverage, 75.0);
      expect(store.todaysUtangTotal, 200.0);
      expect(store.allTimeTotal, 150.0);

      store.reset();
    });
  });

  group('Sales History Month & Period filtering logic', () {
    test('filters sales correctly by month and period', () {
      final sepSale1 = Sale(id: '1', date: DateTime(2026, 9, 15, 9, 30), items: [], total: 40.0);
      final sepSale2 = Sale(id: '2', date: DateTime(2026, 9, 17, 20, 0), items: [], total: 20.0);
      final augSale = Sale(id: '3', date: DateTime(2026, 8, 10, 14, 0), items: [], total: 100.0);
      final julSale = Sale(id: '4', date: DateTime(2026, 7, 5, 11, 0), items: [], total: 250.0);

      final allSales = [sepSale2, sepSale1, augSale, julSale];

      // All Time filter
      expect(allSales.length, 4);
      final allTotal = allSales.fold(0.0, (sum, s) => sum + s.total);
      expect(allTotal, 410.0);

      // September 2026 filter
      final sepSales = allSales.where((s) => s.date.year == 2026 && s.date.month == 9).toList();
      expect(sepSales.length, 2);
      final sepTotal = sepSales.fold(0.0, (sum, s) => sum + s.total);
      expect(sepTotal, 60.0);

      // August 2026 filter
      final augSales = allSales.where((s) => s.date.year == 2026 && s.date.month == 8).toList();
      expect(augSales.length, 1);
      expect(augSales.first.total, 100.0);

      // Non-existent month
      final janSales = allSales.where((s) => s.date.year == 2026 && s.date.month == 1).toList();
      expect(janSales, isEmpty);
    });

    test('sorts sales by newest date and oldest date correctly', () {
      final saleJuly = Sale(id: '1', date: DateTime(2026, 7, 10, 10, 0), items: [], total: 50.0);
      final saleAug = Sale(id: '2', date: DateTime(2026, 8, 15, 12, 0), items: [], total: 100.0);
      final saleSepOld = Sale(id: '3', date: DateTime(2026, 9, 1, 8, 0), items: [], total: 150.0);
      final saleSepNew = Sale(id: '4', date: DateTime(2026, 9, 20, 17, 30), items: [], total: 200.0);

      final unsorted = [saleAug, saleSepOld, saleJuly, saleSepNew];

      // Newest Date first (descending)
      final sortedNewest = List<Sale>.from(unsorted)..sort((a, b) => b.date.compareTo(a.date));
      expect(sortedNewest.map((s) => s.id).toList(), ['4', '3', '2', '1']);
      expect(sortedNewest.first.id, '4'); // Sept 20 is newest
      expect(sortedNewest.last.id, '1');  // July 10 is oldest

      // Oldest Date first (ascending)
      final sortedOldest = List<Sale>.from(unsorted)..sort((a, b) => a.date.compareTo(b.date));
      expect(sortedOldest.map((s) => s.id).toList(), ['1', '2', '3', '4']);
      expect(sortedOldest.first.id, '1'); // July 10 is oldest
      expect(sortedOldest.last.id, '4');  // Sept 20 is newest
    });
  });

  group('Product Image Serialization & Clearing', () {
    test('resolves relative media URL from json', () {
      final json = {
        'id': '1',
        'name': 'Test Item',
        'category': 'Drinks',
        'price': 10.0,
        'stock': 5,
        'image': '/media/products/test.jpg',
      };
      final p = Product.fromJson(json);
      expect(p.imageUrl, isNotNull);
      expect(p.imageUrl, contains('/media/products/test.jpg'));
      expect(p.imageUrl!.startsWith('http'), isTrue);
    });

    test('omits image field in toJson when image not changed', () {
      final p = Product(
        id: '1',
        name: 'Test Item',
        category: 'Drinks',
        price: 10.0,
        stock: 5,
        imageUrl: 'http://example.com/test.jpg',
      );
      final json = p.toJson();
      expect(json.containsKey('image'), isFalse);
    });

    test('emits empty string image field in toJson when isImageCleared is true', () {
      final p = Product(
        id: '1',
        name: 'Test Item',
        category: 'Drinks',
        price: 10.0,
        stock: 5,
        isImageCleared: true,
      );
      final json = p.toJson();
      expect(json.containsKey('image'), isTrue);
      expect(json['image'], equals(''));
    });
  });
}

