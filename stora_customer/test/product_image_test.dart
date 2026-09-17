import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stora_customer/widgets/product_image.dart';

void main() {
  group('ProductImage Widget Tests', () {
    // 1x1 transparent PNG in base64 (contains slashes like /fFcS and /2mNk)
    const pngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

    testWidgets('renders Image.memory for base64 image containing slashes', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageData: pngBase64,
              categoryName: 'Snacks',
            ),
          ),
        ),
      );

      // Verify that Image widget is rendered and not fallback Icon
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Icon), findsNothing);

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<MemoryImage>());
    });

    testWidgets('renders Image.memory when base64 has data URI prefix', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageData: 'data:image/png;base64,$pngBase64',
              categoryName: 'Drinks',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<MemoryImage>());
    });

    testWidgets('renders Image.network for full HTTP/HTTPS URL', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageData: 'https://images.unsplash.com/photo-example.jpg',
              categoryName: 'Food',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<NetworkImage>());
      final networkImage = imageWidget.image as NetworkImage;
      expect(networkImage.url, 'https://images.unsplash.com/photo-example.jpg');
    });

    testWidgets('renders Image.network for relative media URL', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageData: '/media/products/item123.jpg',
              categoryName: 'Household',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<NetworkImage>());
      final networkImage = imageWidget.image as NetworkImage;
      expect(networkImage.url, contains('/media/products/item123.jpg'));
    });

    testWidgets('renders fallback icon when imageData is null or empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageData: null,
              categoryName: 'Beverages',
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.local_drink_rounded), findsOneWidget);
    });
  });
}
