import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

Future<void> initFCM() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await _notifications.initialize(initSettings);

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: true,
  );
}

Future<void> handleFCMBackgroundMessage(RemoteMessage message) async {
  _handleNotification(message);
}

void handleFCMForegroundMessage(RemoteMessage message) {
  _handleNotification(message);
}

void _handleNotification(RemoteMessage message) {
  final data = message.data;
  final title = message.notification?.title ?? 'KwayaPro';
  final body = message.notification?.body ?? '';

  const androidDetails = AndroidNotificationDetails(
    'kwayapro_channel',
    'KwayaPro Notifications',
    channelDescription: 'Choir notifications',
    importance: Importance.high,
    priority: Priority.high,
  );
  const details = NotificationDetails(android: androidDetails);

  _notifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
    payload: _buildPayload(data),
  );
}

String _buildPayload(Map<String, dynamic> data) {
  final type = (data['type'] as String?) ?? '';
  switch (type) {
    case 'rehearsal_created':
    case 'rehearsal_reminder':
      return '/home/rehearsals';
    case 'audio_uploaded':
      return '/home/library';
    case 'program_published':
      return '/planner';
    case 'chat_message':
      return '/home/chat';
    default:
      return '/home';
  }
}

void handleNotificationTap(String? payload) {
  // Called from app entry point when user taps notification
  // Navigation handled by go_router deep link
}
