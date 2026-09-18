import 'package:flutter_test/flutter_test.dart';
import 'package:stora_customer/services/connectivity_service.dart';

void main() {
  group('ConnectivityService Tests', () {
    test('Initial isOnline defaults to true', () {
      expect(ConnectivityService.instance.isOnline.value, isTrue);
    });

    test('isOnline ValueNotifier reacts to value changes', () {
      bool notified = false;
      ConnectivityService.instance.isOnline.addListener(() {
        notified = true;
      });

      ConnectivityService.instance.isOnline.value = false;
      expect(notified, isTrue);
      expect(ConnectivityService.instance.isOnline.value, isFalse);

      ConnectivityService.instance.isOnline.value = true;
      expect(ConnectivityService.instance.isOnline.value, isTrue);
    });
  });
}
