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

  final String? customerName;
  final String? receiptNumber;
  final int? orderId;
  final String? channel;

  Sale({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    this.cashTendered,
    this.changeAmount,
    this.customerName,
    this.receiptNumber,
    this.orderId,
    this.channel,
  });

  bool get isOnlineOrder =>
      orderId != null ||
      (receiptNumber != null && receiptNumber!.startsWith('ORD-')) ||
      channel == 'online_order';

  String get displayCustomerName {
    if (customerName != null && customerName!.trim().isNotEmpty) {
      return customerName!.trim();
    }
    return isOnlineOrder ? 'Customer' : 'Walk-in Customer';
  }

  String get displayReceiptNumber {
    if (receiptNumber != null && receiptNumber!.trim().isNotEmpty) {
      return receiptNumber!.trim();
    }
    if (orderId != null) {
      return 'ORD-$orderId';
    }
    if (id.startsWith('local-')) {
      final suffix = id.replaceFirst('local-', '');
      final shortId = suffix.length > 6 ? suffix.substring(suffix.length - 6) : suffix;
      return 'POS-OFF-$shortId';
    }
    return 'POS-$id';
  }

  Sale copyWith({
    String? id,
    DateTime? date,
    List<CartItem>? items,
    double? total,
    double? cashTendered,
    double? changeAmount,
    String? customerName,
    String? receiptNumber,
    int? orderId,
    String? channel,
  }) {
    return Sale(
      id: id ?? this.id,
      date: date ?? this.date,
      items: items ?? this.items,
      total: total ?? this.total,
      cashTendered: cashTendered ?? this.cashTendered,
      changeAmount: changeAmount ?? this.changeAmount,
      customerName: customerName ?? this.customerName,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      orderId: orderId ?? this.orderId,
      channel: channel ?? this.channel,
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

    final rawCustomerName = json['customer_name']?.toString();
    final rawReceiptNumber = json['receipt_number']?.toString();
    final rawOrderId = json['order_id'] ?? json['order'];
    final int? orderId = (rawOrderId is num)
        ? rawOrderId.toInt()
        : (rawOrderId != null ? int.tryParse(rawOrderId.toString()) : null);
    final rawChannel = json['channel']?.toString();

    return Sale(
      id: json['id']?.toString() ?? '',
      date: parsedDate,
      items: items,
      total: total,
      cashTendered: cashTendered,
      changeAmount: changeAmount,
      customerName: rawCustomerName,
      receiptNumber: rawReceiptNumber,
      orderId: orderId,
      channel: rawChannel,
    );
  }

  /// Serialize to a JSON map suitable for the Django API.
  Map<String, dynamic> toJson() {
    return {
      'total': total.toStringAsFixed(2),
      if (cashTendered != null) 'cash_tendered': cashTendered!.toStringAsFixed(2),
      if (changeAmount != null) 'change_amount': changeAmount!.toStringAsFixed(2),
      if (customerName != null) 'customer_name': customerName,
      if (receiptNumber != null) 'receipt_number': receiptNumber,
      if (orderId != null) 'order_id': orderId,
      if (channel != null) 'channel': channel,
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
