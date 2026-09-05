import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../../home/stores/orders_store.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message for owner: ${message.messageId}');
}

class OwnerNotificationService {
  OwnerNotificationService._();
  static final OwnerNotificationService instance = OwnerNotificationService._();

  bool _initialized = false;
  Function(RemoteMessage message)? onForegroundMessageReceived;

  Future<void> init() async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await messaging.getToken();
        if (token != null) {
          debugPrint('Owner FCM Token: $token');
          await ApiClient.instance.updateFcmToken(token);
        }

        messaging.onTokenRefresh.listen((newToken) {
          ApiClient.instance.updateFcmToken(newToken);
        });

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Foreground owner notification received: ${message.notification?.title}');
          
          final action = message.data['action'];
          if (action == 'created') {
            // Automatically refresh owner orders list when a new order arrives
            OrdersStore.instance.fetchOrders();
          }

          if (onForegroundMessageReceived != null) {
            onForegroundMessageReceived!(message);
          }
        });
      }

      _initialized = true;
    } catch (e) {
      debugPrint('OwnerNotificationService init error (safe to ignore if Firebase is not yet configured): $e');
    }
  }
}
