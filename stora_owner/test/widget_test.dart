import 'package:flutter_test/flutter_test.dart';
import 'package:stora/main.dart';

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Log in'), findsWidgets);
  });
}
