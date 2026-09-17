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
  String bio;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.barcode,
    this.imageBytes,
    this.bio = '',
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

    final rawStock = json['stock'];
    final parsedStock = (rawStock is num)
        ? rawStock.toInt()
        : (int.tryParse(rawStock?.toString() ?? '0') ??
            (double.tryParse(rawStock?.toString() ?? '0')?.toInt() ?? 0));

    final rawPrice = json['price'];
    final parsedPrice = (rawPrice is num)
        ? rawPrice.toDouble()
        : (double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0);

    final rawCatName = json['category_name']?.toString();
    final rawCat = json['category'];
    String category = '';
    if (rawCatName != null && rawCatName.trim().isNotEmpty && int.tryParse(rawCatName.trim()) == null) {
      category = rawCatName.trim();
    } else if (rawCat is String && rawCat.trim().isNotEmpty && int.tryParse(rawCat.trim()) == null) {
      category = rawCat.trim();
    }

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: category,
      price: parsedPrice,
      stock: parsedStock,
      barcode: json['barcode']?.toString(),
      imageBytes: imageBytes,
      bio: json['bio']?.toString() ?? '',
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
      'bio': bio,
    };
    if (imageBytes != null) {
      map['image'] = base64Encode(imageBytes!);
    }
    return map;
  }
}
