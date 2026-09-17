import 'dart:convert';
import 'dart:typed_data';
import '../../data/api/api_config.dart';

class Product {
  String id;
  String name;
  String category;
  double price;
  int stock;
  String? barcode;
  Uint8List? imageBytes;
  String? imageUrl;
  String bio;
  bool isImageCleared;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.barcode,
    this.imageBytes,
    this.imageUrl,
    this.bio = '',
    this.isImageCleared = false,
  });

  /// Create a [Product] from a JSON map returned by the Django API.
  factory Product.fromJson(Map<String, dynamic> json) {
    Uint8List? imageBytes;
    String? imageUrl;
    final image = json['image'] ?? json['image_url'];
    if (image is String && image.trim().isNotEmpty) {
      final img = image.trim();
      if (img.startsWith('http://') ||
          img.startsWith('https://') ||
          img.startsWith('//') ||
          img.startsWith('/media/') ||
          img.startsWith('media/') ||
          img.startsWith('/static/') ||
          img.startsWith('static/')) {
        imageUrl = ApiConfig.resolveMediaUrl(img);
      } else {
        try {
          var clean = img.contains(',') ? img.split(',').last.trim() : img;
          clean = clean.replaceAll(RegExp(r'\s+'), '');
          while (clean.length % 4 != 0) {
            clean += '=';
          }
          imageBytes = base64Decode(clean);
        } catch (_) {
          imageBytes = null;
        }
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
      imageUrl: imageUrl,
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
    } else if (isImageCleared) {
      map['image'] = '';
    }
    return map;
  }
}
