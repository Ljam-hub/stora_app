import 'cart_item.dart';
import 'product.dart';
import '../utils/date_utils.dart';

class Sale {
  final String id;
  final DateTime date;
  final List<CartItem> items;
  final double total;

  Sale({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
  });

  /// Create a [Sale] from a JSON map returned by the Django API.
  factory Sale.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?) ?? [];
    final items = itemsList.map((itemJson) {
      final map = itemJson as Map<String, dynamic>;
      // Build a lightweight Product from the snapshot fields.
      final product = Product(
        id: '',
        name: map['product_name'] as String,
        category: '',
        price: double.parse((map['product_price'] ?? map['unit_price']).toString()),
        stock: 0,
      );
      return CartItem(
        product: product,
        quantity: int.parse(map['quantity'].toString()),
      );
    }).toList();

    return Sale(
      id: json['id'].toString(),
      date: parseApiDateTime((json['date'] ?? json['created_at']) as String),
      items: items,
      total: double.parse(json['total'].toString()),
    );
  }

  /// Serialize to a JSON map suitable for the Django API.
  Map<String, dynamic> toJson() {
    return {
      'total': total.toStringAsFixed(2),
      'items': items
          .map((item) => <String, dynamic>{
                'product_name': item.product.name,
                'product_price': item.product.price.toStringAsFixed(2),
                'quantity': item.quantity,
              })
          .toList(),
    };
  }
}
