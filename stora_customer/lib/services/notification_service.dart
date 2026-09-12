import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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
    importance: Importance.max,
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
        // Explicitly request notification permission for Android 13+ (API 33+)
        await androidPlugin.requestNotificationsPermission();
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
          debugPrint('Customer FCM Token: $token');
          await CustomerApiService.instance.updateFcmToken(token);
        }

        messaging.onTokenRefresh.listen((newToken) {
          CustomerApiService.instance.updateFcmToken(newToken);
        });

        // ── Foreground message handler ──
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint(
              'Foreground customer notification received: ${message.notification?.title ?? message.data['title']}');

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

  /// Explicitly displays a local heads-up notification banner with Stora branding.
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _orderChannel.id,
        _orderChannel.name,
        channelDescription: _orderChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_notification',
        color: const Color(0xFFFF6B00),
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Stora Orders',
        ),
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing customer local notification: $e');
    }
  }

  /// Clears all active notifications from the Android notification shade.
  Future<void> cancelAll() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling customer notifications: $e');
    }
  }

  /// Clears a specific notification by ID.
  Future<void> cancel(int id) async {
    try {
      await _localNotifications.cancel(id);
    } catch (e) {
      debugPrint('Error cancelling customer notification #$id: $e');
    }
  }

  /// Displays a local heads-up notification banner with sound and vibration.
  void _showLocalNotification(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'Order Update';
    final body = message.notification?.body ?? message.data['body'] ?? 'Your order status has changed';

    final androidDetails = AndroidNotificationDetails(
      _orderChannel.id,
      _orderChannel.name,
      channelDescription: _orderChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@drawable/ic_notification',
      color: const Color(0xFFFF6B00),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Stora Orders',
      ),
    );

    _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }
}
