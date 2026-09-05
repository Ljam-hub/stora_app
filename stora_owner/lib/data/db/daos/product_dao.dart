import 'package:drift/drift.dart';

import '../stora_database.dart';
import '../../../home/models/product.dart';

/// Data Access Object for product operations.
class ProductDao {
  ProductDao(this._db);
  final AppDatabase _db;

  Future<List<Product>> loadProducts() async {
    final rows = await _db.select(_db.products).get();
    return rows.map(_productFromRow).toList();
  }

  Future<void> replaceProducts(List<Product> items) async {
    await _db.transaction(() async {
      await _db.delete(_db.products).go();
      for (final item in items) {
        await _db.into(_db.products).insert(_productToCompanion(item));
      }
    });
  }

  Future<void> upsertProduct(Product item) {
    return _db.into(_db.products).insertOnConflictUpdate(
      _productToCompanion(item),
    );
  }

  Future<void> deleteProduct(String id) {
    return (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();
  }

  ProductsCompanion _productToCompanion(Product item) {
    return ProductsCompanion(
      id: Value(item.id),
      name: Value(item.name),
      category: Value(item.category),
      price: Value(item.price),
      stock: Value(item.stock),
      barcode: Value(item.barcode),
      imageBytes: Value(item.imageBytes),
    );
  }

  Product _productFromRow(ProductRow row) {
    return Product(
      id: row.id,
      name: row.name,
      category: row.category,
      price: row.price,
      stock: row.stock,
      barcode: row.barcode,
      imageBytes: row.imageBytes,
    );
  }
}
