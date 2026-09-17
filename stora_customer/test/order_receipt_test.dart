import 'package:flutter_test/flutter_test.dart';
import 'package:stora_customer/models/order_model.dart';

void main() {
  group('CustomerOrder receipt and customer display name tests', () {
    test('parses receipt_number from backend json', () {
      final json = {
        'id': 42,
        'owner': 1,
        'store_name': 'Super Mart',
        'customer_name': 'Juan Dela Cruz',
        'customer_phone': '09171234567',
        'customer_address': '123 Main St',
        'notes': 'Please call upon arrival',
        'status': 'accepted',
        'total_amount': '350.00',
        'receipt_number': 'ORD-42',
        'items': [
          {
            'id': 1,
            'product': 10,
            'product_name': 'Iced Coffee',
            'quantity': 2,
            'unit_price': '175.00',
          }
        ],
      };

      final order = CustomerOrder.fromJson(json);
      expect(order.id, 42);
      expect(order.receiptNumber, 'ORD-42');
      expect(order.customerDisplayName, 'Juan Dela Cruz');
      expect(order.totalAmount, 350.0);
      expect(order.items.length, 1);
      expect(order.items.first.subtotal, 350.0);
    });

    test('falls back to ORD-id when receipt_number is null or empty', () {
      final json = {
        'id': 99,
        'owner': 1,
        'customer_name': '',
        'customer_phone': '',
        'customer_address': '',
        'notes': '',
        'status': 'pending',
        'total_amount': '100.00',
        'items': [],
      };

      final order = CustomerOrder.fromJson(json);
      expect(order.id, 99);
      expect(order.receiptNumber, 'ORD-99');
      expect(order.customerDisplayName, 'Customer');
    });

    test('custom displayName trims extra whitespace correctly', () {
      final order = CustomerOrder(
        id: 15,
        ownerId: 2,
        customerName: '   Maria Santos   ',
        customerPhone: '',
        customerAddress: '',
        notes: '',
        status: 'ready',
        totalAmount: 200.0,
        items: [],
      );

      expect(order.customerDisplayName, 'Maria Santos');
      expect(order.receiptNumber, 'ORD-15');
    });

    test('uses counter_price as totalAmount when status is accepted or ready', () {
      final json = {
        'id': 105,
        'owner': 1,
        'status': 'accepted',
        'total_amount': '500.00',
        'counter_price': '450.00',
        'items': [],
      };

      final order = CustomerOrder.fromJson(json);
      expect(order.totalAmount, 450.0);
      expect(order.formattedTotal, '₱450.00');
    });
  });
}
