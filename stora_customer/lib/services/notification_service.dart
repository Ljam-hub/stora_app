import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;
  Function(RemoteMessage message)? onForegroundMessageReceived;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android notification channel for high-importance order updates.
  static const AndroidNotificationChannel _orderChannel =
      AndroidNotificationChannel(
    'stora_customer_orders',
    'Order Updates',
    description: 'Important order status updates from stores',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  Future<void> init() async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // ── Initialize flutter_local_notifications ──
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(initSettings);

      // Create the high-importance notification channel on Android
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_orderChannel);
      }

      // ── Firebase Messaging setup ──
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

        // ── Foreground message handler ──
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint(
              'Foreground notification received: ${message.notification?.title}');

          // Show a system heads-up banner with sound even while the app is open
          _showLocalNotification(message);

          // Also trigger in-app callback (SnackBar, order refresh, etc.)
          if (onForegroundMessageReceived != null) {
            onForegroundMessageReceived!(message);
          }
        });
      }

      _initialized = true;
    } catch (e) {
      debugPrint(
          'NotificationService init error (safe to ignore if Firebase is not yet configured): $e');
    }
  }

  /// Displays a local heads-up notification banner with sound and vibration.
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _orderChannel.id,
      _orderChannel.name,
      channelDescription: _orderChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: androidDetails),
    );
  }
}
