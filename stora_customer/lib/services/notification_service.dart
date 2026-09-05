import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;

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
          debugPrint('FCM Token: $token');
          await CustomerApiService.instance.updateFcmToken(token);
        }

        messaging.onTokenRefresh.listen((newToken) {
          CustomerApiService.instance.updateFcmToken(newToken);
        });

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Foreground notification received: ${message.notification?.title}');
        });
      }

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error (safe to ignore if Firebase is not yet configured): $e');
    }
  }
}
