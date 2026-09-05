import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  int quantity;

  CartItemModel({
    required this.product,
    this.quantity = 1,
  });

  double get subtotal => product.price * quantity;
  String get formattedSubtotal => '₱${subtotal.toStringAsFixed(2)}';

  Map<String, dynamic> toJson() {
    return {
      'product_id': product.id,
      'product_name': product.name,
      'price': product.price,
      'quantity': quantity,
    };
  }
}
