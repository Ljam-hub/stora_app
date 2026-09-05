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
  });

  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= 5;
  String get formattedPrice => '₱${price.toStringAsFixed(2)}';

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      name: (json['name'] as String?) ?? '',
      categoryId: json['category'] as int?,
      categoryName: (json['category_name'] as String?) ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      stock: (json['stock'] as int?) ?? 0,
      barcode: json['barcode'] as String?,
      image: json['image'] as String?,
      ownerId: json['owner'] as int?,
      storeName: (json['store_name'] as String?) ?? '',
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
    };
  }
}
