import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../api/api_client.dart';
import '../stores/account_status_store.dart';
import '../../home/stores/orders_store.dart';
import '../../home/stores/utang_store.dart';
import 'utang_reminder_helper.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message for owner: ${message.messageId}');
}

class OwnerNotificationService {
  OwnerNotificationService._();
  static final OwnerNotificationService instance =
      OwnerNotificationService._();

  bool _initialized = false;
  Function(RemoteMessage message)? onForegroundMessageReceived;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android notification channel for high-importance incoming orders.
  static const AndroidNotificationChannel _orderChannel =
      AndroidNotificationChannel(
    'stora_owner_orders',
    'Store Orders',
    description: 'New incoming customer orders and updates',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Android notification channel for loan and utang reminders.
  static const AndroidNotificationChannel _utangChannel =
      AndroidNotificationChannel(
    'stora_owner_utang',
    'Loan & Utang Reminders',
    description: 'Alerts for upcoming, due, and overdue utang payments',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Android notification channel for owner notes and personal reminders.
  static const AndroidNotificationChannel _notesChannel =
      AndroidNotificationChannel(
    'stora_owner_notes',
    'Owner Notes & Reminders',
    description: 'Scheduled reminders for owner notes and store tasks',
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

      // Create the high-importance notification channels on Android
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_orderChannel);
        await androidPlugin.createNotificationChannel(_utangChannel);
        await androidPlugin.createNotificationChannel(_notesChannel);
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
          debugPrint('Owner FCM Token: $token');
          await ApiClient.instance.updateFcmToken(token);
        }

        messaging.onTokenRefresh.listen((newToken) async {
          try {
            await ApiClient.instance.updateFcmToken(newToken);
          } catch (e) {
            debugPrint('Failed to send refreshed FCM token: $e');
          }
        });

        // ── Foreground message handler ──
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint(
              'Foreground owner notification received: ${message.notification?.title ?? message.data['title']}');

          final action = message.data['action'];
          final type = message.data['type'];
          final status = message.data['status'];
          if (action == 'created') {
            // Automatically refresh owner orders list when a new order arrives
            OrdersStore.instance.fetchOrders();
          }
          if (type == 'credit_reminder') {
            UtangStore.instance.syncWithBackend();
          }
          if (type == 'subscription_approved' ||
              type == 'subscription_rejected' ||
              action == 'subscription_approved' ||
              action == 'subscription_rejected' ||
              status == 'approved' ||
              status == 'rejected') {
            // Automatically refresh account/subscription status when admin approves or rejects
            AccountStatusStore.instance.fetchStatus();
          }

          // Show a system heads-up banner with sound even while the app is open
          _showLocalNotification(message);

          // Also trigger in-app callback (SnackBar, order refresh, etc.)
          if (onForegroundMessageReceived != null) {
            onForegroundMessageReceived!(message);
          }
        });

        // ── Notification tap handler (opened from background) ──
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final action = message.data['action'];
          final type = message.data['type'];
          final status = message.data['status'];
          if (action == 'created') {
            OrdersStore.instance.fetchOrders();
          }
          if (type == 'credit_reminder') {
            UtangStore.instance.syncWithBackend();
          }
          if (type == 'subscription_approved' ||
              type == 'subscription_rejected' ||
              action == 'subscription_approved' ||
              action == 'subscription_rejected' ||
              status == 'approved' ||
              status == 'rejected') {
            AccountStatusStore.instance.fetchStatus();
          }
        });

        // ── App opened from terminated state via notification ──
        messaging.getInitialMessage().then((message) {
          if (message != null) {
            final action = message.data['action'];
            final type = message.data['type'];
            final status = message.data['status'];
            if (action == 'created') {
              OrdersStore.instance.fetchOrders();
            }
            if (type == 'credit_reminder') {
              UtangStore.instance.syncWithBackend();
            }
            if (type == 'subscription_approved' ||
                type == 'subscription_rejected' ||
                action == 'subscription_approved' ||
                action == 'subscription_rejected' ||
                status == 'approved' ||
                status == 'rejected') {
              AccountStatusStore.instance.fetchStatus();
            }
          }
        });
      }

      _initialized = true;
    } catch (e) {
      debugPrint(
          'OwnerNotificationService init error (safe to ignore if Firebase is not yet configured): $e');
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
      debugPrint('Error showing owner local notification: $e');
    }
  }

  /// Clears all active notifications from the Android notification shade.
  Future<void> cancelAll() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling notifications: $e');
    }
  }

  /// Clears a specific notification by ID.
  Future<void> cancel(int id) async {
    try {
      await _localNotifications.cancel(id);
    } catch (e) {
      debugPrint('Error cancelling notification #$id: $e');
    }
  }

  /// Displays a local heads-up notification banner with sound and vibration from RemoteMessage.
  void _showLocalNotification(RemoteMessage message) {
    final isUtang = message.data['type'] == 'credit_reminder' ||
        message.data['channel_id'] == 'stora_owner_utang';

    final channel = isUtang ? _utangChannel : _orderChannel;
    final title = message.notification?.title ??
        message.data['title'] ??
        (isUtang ? 'Utang Reminder' : 'Store Order Update');
    final body = message.notification?.body ??
        message.data['body'] ??
        (isUtang ? 'Customer utang reminder' : 'New order update received');

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@drawable/ic_notification',
      color: isUtang ? const Color(0xFFFF9800) : const Color(0xFFFF6B00),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: isUtang ? 'Utang Reminder' : 'Stora Orders',
      ),
    );

    _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Explicitly displays a local heads-up notification banner for utang reminders.
  Future<void> showUtangNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _utangChannel.id,
        _utangChannel.name,
        channelDescription: _utangChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_notification',
        color: const Color(0xFFFF9800),
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Utang Reminder',
        ),
      );

      await _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing owner utang notification: $e');
    }
  }

  Future<File> _getUtangAlertHistoryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/stora_utang_alert_history.json');
  }

  Future<Map<String, dynamic>> _loadUtangAlertHistory() async {
    try {
      final file = await _getUtangAlertHistoryFile();
      if (await file.exists()) {
        final text = await file.readAsString();
        if (text.isNotEmpty) {
          return Map<String, dynamic>.from(jsonDecode(text) as Map);
        }
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveUtangAlertHistory(Map<String, dynamic> history) async {
    try {
      final file = await _getUtangAlertHistoryFile();
      // Keep only last 100 entries to prevent unbounded growth
      if (history.length > 100) {
        final keys = history.keys.toList();
        final excess = keys.take(keys.length - 100);
        for (final k in excess) {
          history.remove(k);
        }
      }
      await file.writeAsString(jsonEncode(history));
    } catch (_) {}
  }

  /// Scans active utang records and delivers automated notifications:
  /// - 3 Days Before Due Date (Advance Notice):
  ///   "Upcoming Utang: [Customer] has a balance of ₱[Amount] due in 3 days ([Weekday])."
  /// - On the Due Date (Today Alert):
  ///   "Due Today: [Customer] owes ₱[Amount] due today!"
  /// - When Past Due Date (Overdue Alert):
  ///   "🚨 Overdue Loan: [Customer]'s utang of ₱[Amount] is now [X] days overdue."
  ///
  /// Automatically deduplicates daily to prevent repeated alerts on the same day.
  Future<int> checkAndNotifyUtang(List<UtangRecord> records, [DateTime? currentDate]) async {
    try {
      final now = currentDate ?? DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final history = await _loadUtangAlertHistory();
      int sentCount = 0;

      for (final r in records) {
        final alert = UtangReminderHelper.generateAlert(r, now);
        if (alert != null) {
          final alertKey = '${r.id}_${todayStr}_${alert.alertType}';
          if (!history.containsKey(alertKey)) {
            final notifId = (r.id.hashCode ^ alert.alertType.hashCode) & 0x7FFFFFFF;
            await showUtangNotification(
              id: notifId,
              title: alert.title,
              body: alert.body,
              payload: 'utang:${r.id}',
            );
            history[alertKey] = now.toIso8601String();
            sentCount++;
          }
        }
      }

      if (sentCount > 0) {
        await _saveUtangAlertHistory(history);
      }
      return sentCount;
    } catch (e) {
      debugPrint('checkAndNotifyUtang error: $e');
      return 0;
    }
  }

  int _noteIdToNotificationId(String noteId) =>
      (noteId.hashCode & 0x7FFFFFFF);

  /// Schedules or immediately displays a notification for an owner note reminder.
  Future<void> scheduleNoteReminder({
    required String noteId,
    required String title,
    String? content,
    required DateTime reminderDateTime,
  }) async {
    try {
      final notifId = _noteIdToNotificationId(noteId);
      final androidDetails = AndroidNotificationDetails(
        _notesChannel.id,
        _notesChannel.name,
        channelDescription: _notesChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_notification',
        color: const Color(0xFF8B5CF6),
        styleInformation: BigTextStyleInformation(
          content != null && content.isNotEmpty ? content : 'Reminder from your store notes',
          contentTitle: '⏰ $title',
          summaryText: 'Owner Reminder',
        ),
      );

      final now = DateTime.now();
      if (reminderDateTime.isAfter(now)) {
        final tzScheduled = tz.TZDateTime.from(reminderDateTime, tz.local);
        await _localNotifications.zonedSchedule(
          notifId,
          '⏰ Reminder: $title',
          content != null && content.isNotEmpty ? content : 'Scheduled store reminder',
          tzScheduled,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'note:$noteId',
        );
      } else {
        await _localNotifications.show(
          notifId,
          '⏰ Reminder: $title',
          content != null && content.isNotEmpty ? content : 'Scheduled store reminder',
          NotificationDetails(android: androidDetails),
          payload: 'note:$noteId',
        );
      }
    } catch (e) {
      debugPrint('scheduleNoteReminder error: $e');
    }
  }

  /// Cancels a scheduled note reminder notification.
  Future<void> cancelNoteReminder(String noteId) async {
    try {
      final notifId = _noteIdToNotificationId(noteId);
      await _localNotifications.cancel(notifId);
    } catch (e) {
      debugPrint('cancelNoteReminder error: $e');
    }
  }

  @visibleForTesting
  Future<void> clearAlertHistoryForTesting() async {
    try {
      final file = await _getUtangAlertHistoryFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
