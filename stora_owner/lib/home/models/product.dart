import 'dart:convert';
import 'dart:typed_data';

class Product {
  String id;
  String name;
  String category;
  double price;
  int stock;
  String? barcode;
  Uint8List? imageBytes;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.barcode,
    this.imageBytes,
  });

  /// Create a [Product] from a JSON map returned by the Django API.
  factory Product.fromJson(Map<String, dynamic> json) {
    Uint8List? imageBytes;
    final image = json['image'];
    if (image is String && image.isNotEmpty && !image.startsWith('http')) {
      try {
        imageBytes = base64Decode(image);
      } catch (_) {
        imageBytes = null;
      }
    }

    return Product(
      id: json['id'].toString(),
      name: json['name'] as String,
      category: (json['category_name'] as String?) ?? '',
      price: double.parse(json['price'].toString()),
      stock: int.parse(json['stock'].toString()),
      barcode: json['barcode'] as String?,
      imageBytes: imageBytes,
    );
  }

  /// Serialize to a JSON map suitable for the Django API.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'category_name': category,
      'price': price.toStringAsFixed(2),
      'stock': stock,
      'barcode': barcode,
    };
    if (imageBytes != null) {
      map['image'] = base64Encode(imageBytes!);
    }
    return map;
  }
}
