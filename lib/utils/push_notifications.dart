import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

Future<void> initializePush({
  required Future<void> Function(String token) onNewToken,
  String? webVapidKey,
}) async {
  final messaging = FirebaseMessaging.instance;

  // Permisos
  await messaging.requestPermission();

  // Canal de Android y setup de notificaciones locales (foreground)
  const channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Channel for important notifications',
    importance: Importance.high,
  );

  await _fln
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _fln.initialize(initSettings);

  // Mostrar banner local cuando la app está en primer plano
  FirebaseMessaging.onMessage.listen((message) async {
    final n = message.notification;
    if (n == null) return;
    await _fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      n.title ?? 'Notificación',
      n.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  });

  // Obtener y guardar token
  String? token;
  if (kIsWeb) {
    token = await messaging.getToken(vapidKey: webVapidKey);
  } else {
    token = await messaging.getToken();
  }
  if (token != null && token.isNotEmpty) {
    await onNewToken(token);
  }

  // Refrescos
  FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
    if (t.isNotEmpty) await onNewToken(t);
  });
}

// Handler de background (Android). Regístralo en main().
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No hacemos nada especial; lo maneja el sistema.
}
