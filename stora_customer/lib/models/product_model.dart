import '../config/api_config.dart';

class ProductModel {
  final int id;
  final String name;
  final int? categoryId;
  final String categoryName;
  final double price;
  final int stock;
  final String? barcode;
  final String? image;
  final int? ownerId;
  final String? storeName;
  final String? storeAvatarUrl;
  final String bio;

  ProductModel({
    required this.id,
    required this.name,
    this.categoryId,
    this.categoryName = '',
    required this.price,
    this.stock = 0,
    this.barcode,
    this.image,
    this.ownerId,
    this.storeName,
    this.storeAvatarUrl,
    this.bio = '',
  });

  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= 5;
  String get formattedPrice => '₱${price.toStringAsFixed(2)}';

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    int? parseId(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is Map && val['id'] != null) return parseId(val['id']);
      return int.tryParse(val.toString());
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

    return ProductModel(
      id: parseId(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      categoryId: parseId(json['category']),
      categoryName: json['category_name']?.toString() ??
          (json['category'] is String && int.tryParse(json['category'].toString()) == null
              ? json['category'].toString()
              : ''),
      price: parsedPrice,
      stock: parsedStock,
      barcode: json['barcode']?.toString(),
      image: (json['image'] != null && json['image'].toString().isNotEmpty)
          ? json['image'].toString()
          : json['image_url']?.toString(),
      ownerId: parseId(json['owner']),
      storeName: json['store_name']?.toString() ?? '',
      storeAvatarUrl: ApiConfig.resolveMediaUrl(json['store_avatar_url']?.toString()),
      bio: json['bio']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': categoryId,
      'category_name': categoryName,
      'price': price.toStringAsFixed(2),
      'stock': stock,
      'barcode': barcode,
      'image': image,
      'owner': ownerId,
      'store_name': storeName,
      'store_avatar_url': storeAvatarUrl,
      'bio': bio,
    };
  }
}
