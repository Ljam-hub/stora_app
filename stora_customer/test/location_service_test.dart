import 'package:flutter_test/flutter_test.dart';
import 'package:stora_customer/services/location_service.dart';

void main() {
  group('LocationResult tests', () {
    test('LocationResult.ok sets properties correctly', () {
      final res = LocationResult.ok(
        address: '123 Main St, City, Province',
        latitude: 14.5995,
        longitude: 120.9842,
      );

      expect(res.success, isTrue);
      expect(res.address, '123 Main St, City, Province');
      expect(res.latitude, 14.5995);
      expect(res.longitude, 120.9842);
      expect(res.errorMessage, isNull);
    });

    test('LocationResult.error sets error message', () {
      final res = LocationResult.error('GPS turned off');

      expect(res.success, isFalse);
      expect(res.address, isNull);
      expect(res.errorMessage, 'GPS turned off');
    });
  });
}
