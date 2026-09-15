import 'cart_item.dart';
import 'product.dart';
import '../utils/date_utils.dart';

class Sale {
  final String id;
  final DateTime date;
  final List<CartItem> items;
  final double total;

  final double? cashTendered;
  final double? changeAmount;

  Sale({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    this.cashTendered,
    this.changeAmount,
  });

  Sale copyWith({
    String? id,
    DateTime? date,
    List<CartItem>? items,
    double? total,
    double? cashTendered,
    double? changeAmount,
  }) {
    return Sale(
      id: id ?? this.id,
      date: date ?? this.date,
      items: items ?? this.items,
      total: total ?? this.total,
      cashTendered: cashTendered ?? this.cashTendered,
      changeAmount: changeAmount ?? this.changeAmount,
    );
  }

  /// Create a [Sale] from a JSON map returned by the Django API.
  factory Sale.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?) ?? [];
    final items = itemsList.map((itemJson) {
      if (itemJson is! Map<String, dynamic>) {
        return CartItem(
          product: Product(
            id: '',
            name: 'Unknown Item',
            category: '',
            price: 0.0,
            stock: 0,
          ),
          quantity: 1,
        );
      }
      final map = itemJson;
      final rawPrice = map['product_price'] ?? map['unit_price'];
      final price = (rawPrice is num)
          ? rawPrice.toDouble()
          : (double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0);
      final rawQty = map['quantity'];
      final quantity = (rawQty is num)
          ? rawQty.toInt()
          : (int.tryParse(rawQty?.toString() ?? '1') ?? 1);
      final product = Product(
        id: '',
        name: map['product_name']?.toString() ?? 'Unknown Item',
        category: '',
        price: price,
        stock: 0,
      );
      return CartItem(
        product: product,
        quantity: quantity,
      );
    }).toList();

    final rawDate = (json['date'] ?? json['created_at'])?.toString();
    DateTime parsedDate;
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        parsedDate = parseApiDateTime(rawDate);
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    final rawTotal = json['total'];
    final total = (rawTotal is num)
        ? rawTotal.toDouble()
        : (double.tryParse(rawTotal?.toString() ?? '0') ?? 0.0);

    final rawTendered = json['cash_tendered'];
    final cashTendered = (rawTendered is num)
        ? rawTendered.toDouble()
        : (rawTendered != null ? double.tryParse(rawTendered.toString()) : null);

    final rawChange = json['change_amount'];
    final changeAmount = (rawChange is num)
        ? rawChange.toDouble()
        : (rawChange != null ? double.tryParse(rawChange.toString()) : null);

    return Sale(
      id: json['id']?.toString() ?? '',
      date: parsedDate,
      items: items,
      total: total,
      cashTendered: cashTendered,
      changeAmount: changeAmount,
    );
  }

  /// Serialize to a JSON map suitable for the Django API.
  Map<String, dynamic> toJson() {
    return {
      'total': total.toStringAsFixed(2),
      if (cashTendered != null) 'cash_tendered': cashTendered!.toStringAsFixed(2),
      if (changeAmount != null) 'change_amount': changeAmount!.toStringAsFixed(2),
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
