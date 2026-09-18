import 'package:flutter_test/flutter_test.dart';
import 'package:stora_customer/storage/hidden_products_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HiddenProductsStore Tests', () {
    final store = HiddenProductsStore.instance;

    setUp(() {
      store.clear();
    });

    tearDown(() {
      store.clear();
    });

    test('Initial state has no hidden products', () {
      expect(store.hiddenProductIds, isEmpty);
      expect(store.hiddenProductsList, isEmpty);
      expect(store.isHidden(42), isFalse);
      expect(store.isReported(42), isFalse);
    });

    test('hideProduct stores id and metadata and notifies listeners', () async {
      int notifyCount = 0;
      void listener() => notifyCount++;
      store.addListener(listener);

      await store.hideProduct(
        101,
        name: 'Fresh Apples',
        price: 45.0,
        imageUrl: 'https://example.com/apples.jpg',
        storeName: 'Fresh Mart',
        categoryName: 'Fruits',
      );

      expect(store.isHidden(101), isTrue);
      expect(store.hiddenProductIds.contains(101), isTrue);
      expect(store.hiddenProductsList.length, 1);

      final item = store.hiddenProductsList.first;
      expect(item['id'], 101);
      expect(item['name'], 'Fresh Apples');
      expect(item['price'], 45.0);
      expect(item['imageUrl'], 'https://example.com/apples.jpg');
      expect(item['storeName'], 'Fresh Mart');
      expect(notifyCount, greaterThanOrEqualTo(1));

      store.removeListener(listener);
    });

    test('unhideProduct removes specific item and retains others', () async {
      await store.hideProduct(1, name: 'Item 1');
      await store.hideProduct(2, name: 'Item 2');
      expect(store.hiddenProductIds.length, 2);

      await store.unhideProduct(1);
      expect(store.isHidden(1), isFalse);
      expect(store.isHidden(2), isTrue);
      expect(store.hiddenProductIds.length, 1);
      expect(store.hiddenProductsList.first['id'], 2);
    });

    test('unhideAll restores all hidden items at once', () async {
      await store.hideProduct(1, name: 'Item 1');
      await store.hideProduct(2, name: 'Item 2');
      await store.hideProduct(3, name: 'Item 3');
      expect(store.hiddenProductsList.length, 3);

      await store.unhideAll();
      expect(store.hiddenProductIds, isEmpty);
      expect(store.hiddenProductsList, isEmpty);
    });

    test('markReported updates report cooldown timestamp', () async {
      expect(store.isReported(99), isFalse);
      await store.markReported(99);
      expect(store.isReported(99), isTrue);
    });

    test('clear cleans up all in-memory state', () async {
      await store.hideProduct(50, name: 'Item 50');
      await store.markReported(50);
      expect(store.isHidden(50), isTrue);
      expect(store.isReported(50), isTrue);

      store.clear();
      expect(store.isHidden(50), isFalse);
      expect(store.isReported(50), isFalse);
      expect(store.hiddenProductIds, isEmpty);
      expect(store.hiddenProductsList, isEmpty);
    });
  });
}
