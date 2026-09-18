import 'package:flutter_test/flutter_test.dart';
import 'package:stora_customer/models/order_model.dart';
import 'package:stora_customer/providers/order_provider.dart';

void main() {
  group('OrderProvider Filtering and Status Tests', () {
    late OrderProvider orderProvider;

    setUp(() {
      orderProvider = OrderProvider();
    });

    test('Initial orderProvider is empty and not loading', () {
      expect(orderProvider.rawOrders, isEmpty);
      expect(orderProvider.orders, isEmpty);
      expect(orderProvider.isLoading, isFalse);
      expect(orderProvider.selectedStatusFilter, 'all');
    });

    test('Status filtering correctly returns matching subset', () {
      final sampleOrders = [
        CustomerOrder(id: 1, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'pending', totalAmount: 100, items: []),
        CustomerOrder(id: 2, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'accepted', totalAmount: 150, items: []),
        CustomerOrder(id: 3, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'ready', totalAmount: 200, items: []),
        CustomerOrder(id: 4, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'completed', totalAmount: 250, items: []),
        CustomerOrder(id: 5, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'declined', totalAmount: 300, items: []),
        CustomerOrder(id: 6, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'auto_declined', totalAmount: 350, items: []),
        CustomerOrder(id: 7, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'counter_offer', totalAmount: 400, items: []),
      ];

      orderProvider.setOrdersForTesting(sampleOrders);

      // 'all' filter
      orderProvider.setFilter('all');
      expect(orderProvider.orders.length, 7);

      // 'pending' filter
      orderProvider.setFilter('pending');
      expect(orderProvider.orders.length, 1);
      expect(orderProvider.orders.first.id, 1);

      // 'accepted' filter (includes accepted and ready)
      orderProvider.setFilter('accepted');
      expect(orderProvider.orders.length, 2);
      expect(orderProvider.orders.map((o) => o.id), containsAll([2, 3]));

      // 'completed' filter
      orderProvider.setFilter('completed');
      expect(orderProvider.orders.length, 1);
      expect(orderProvider.orders.first.id, 4);

      // 'declined' filter (includes declined and auto_declined)
      orderProvider.setFilter('declined');
      expect(orderProvider.orders.length, 2);
      expect(orderProvider.orders.map((o) => o.id), containsAll([5, 6]));

      // 'counter_offer' filter
      orderProvider.setFilter('counter_offer');
      expect(orderProvider.orders.length, 1);
      expect(orderProvider.orders.first.id, 7);
    });

    test('Unread counts calculate correctly based on seen filters', () {
      final sampleOrders = [
        CustomerOrder(id: 1, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'pending', totalAmount: 100, items: []),
        CustomerOrder(id: 2, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'counter_offer', totalAmount: 150, items: []),
        CustomerOrder(id: 3, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'accepted', totalAmount: 200, items: []),
        CustomerOrder(id: 4, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'completed', totalAmount: 250, items: []),
      ];

      orderProvider.setOrdersForTesting(sampleOrders);

      expect(orderProvider.unreadPendingCount, 1);
      expect(orderProvider.unreadCounterOfferCount, 1);
      expect(orderProvider.unreadAcceptedCount, 1);
      expect(orderProvider.unreadCompletedCount, 1);

      // Marking filter seen zeroes that filter's unread badge
      orderProvider.markFilterSeen('pending');
      expect(orderProvider.unreadPendingCount, 0);

      orderProvider.markFilterSeen('counter_offer');
      expect(orderProvider.unreadCounterOfferCount, 0);
    });

    test('reset clears state cleanly', () {
      final sampleOrders = [
        CustomerOrder(id: 1, ownerId: 1, storeName: 'S1', customerName: 'A', customerPhone: 'P', customerAddress: 'Addr', notes: '', status: 'pending', totalAmount: 100, items: []),
      ];
      orderProvider.setOrdersForTesting(sampleOrders);
      expect(orderProvider.rawOrders.length, 1);

      orderProvider.reset();
      expect(orderProvider.rawOrders, isEmpty);
      expect(orderProvider.orders, isEmpty);
      expect(orderProvider.unreadAllCount, 0);
      expect(orderProvider.unreadActiveOrdersCount, 0);
    });
  });
}
