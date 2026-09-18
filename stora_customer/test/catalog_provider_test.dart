import 'package:flutter_test/flutter_test.dart';
import 'package:stora_customer/models/category_model.dart';
import 'package:stora_customer/models/product_model.dart';
import 'package:stora_customer/models/store_model.dart';
import 'package:stora_customer/providers/catalog_provider.dart';

void main() {
  group('CatalogProvider Filtering and Selection Tests', () {
    late CatalogProvider catalog;

    setUp(() {
      catalog = CatalogProvider();
    });

    test('Initial state is empty', () {
      expect(catalog.products, isEmpty);
      expect(catalog.categories, isEmpty);
      expect(catalog.stores, isEmpty);
      expect(catalog.selectedStore, isNull);
      expect(catalog.selectedCategory, isNull);
      expect(catalog.searchQuery, isEmpty);
      expect(catalog.isLoading, isFalse);
    });

    test('Filter products by category selection', () {
      final cat1 = CategoryModel(id: 1, name: 'Beverages');
      final cat2 = CategoryModel(id: 2, name: 'Snacks');
      final p1 = ProductModel(id: 1, name: 'Iced Tea', price: 25, stock: 10, categoryId: 1, categoryName: 'Beverages', ownerId: 1);
      final p2 = ProductModel(id: 2, name: 'Potato Chips', price: 35, stock: 5, categoryId: 2, categoryName: 'Snacks', ownerId: 1);
      final p3 = ProductModel(id: 3, name: 'Soda', price: 30, stock: 8, categoryId: 1, categoryName: 'Beverages', ownerId: 1);

      catalog.setCatalogDataForTesting(
        categories: [cat1, cat2],
        products: [p1, p2, p3],
      );

      expect(catalog.products.length, 3);

      catalog.selectCategory(cat1);
      expect(catalog.selectedCategory?.id, 1);
      expect(catalog.products.length, 2);
      expect(catalog.products.map((p) => p.name), containsAll(['Iced Tea', 'Soda']));

      // Tapping same category toggles off
      catalog.selectCategory(cat1);
      expect(catalog.selectedCategory, isNull);
      expect(catalog.products.length, 3);
    });

    test('Filter products by search query', () {
      final p1 = ProductModel(id: 1, name: 'Whole Wheat Bread', price: 60, stock: 4, barcode: '480111222', ownerId: 1);
      final p2 = ProductModel(id: 2, name: 'Chocolate Bar', price: 40, stock: 12, barcode: '480333444', ownerId: 1);
      final p3 = ProductModel(id: 3, name: 'White Bread', price: 50, stock: 6, barcode: '480555666', ownerId: 1);

      catalog.setCatalogDataForTesting(products: [p1, p2, p3]);

      catalog.setSearchQuery('Bread');
      expect(catalog.products.length, 2);
      expect(catalog.products.map((p) => p.name), containsAll(['Whole Wheat Bread', 'White Bread']));

      // Search by barcode
      catalog.setSearchQuery('333444');
      expect(catalog.products.length, 1);
      expect(catalog.products.first.name, 'Chocolate Bar');

      catalog.setSearchQuery('');
      expect(catalog.products.length, 3);
    });

    test('Filter products by selected store', () {
      final store1 = StoreModel(id: 1, businessName: 'Store One', email: 's1@store.com');
      final store2 = StoreModel(id: 2, businessName: 'Store Two', email: 's2@store.com');

      final p1 = ProductModel(id: 1, name: 'P1', price: 10, stock: 5, ownerId: 1);
      final p2 = ProductModel(id: 2, name: 'P2', price: 20, stock: 5, ownerId: 2);
      final p3 = ProductModel(id: 3, name: 'P3', price: 30, stock: 5, ownerId: 1);

      catalog.setCatalogDataForTesting(
        stores: [store1, store2],
        products: [p1, p2, p3],
        selectedStore: store1,
      );

      expect(catalog.products.length, 2);
      expect(catalog.products.map((p) => p.id), containsAll([1, 3]));
    });
  });
}
