import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_navigator.dart';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
bool _webNotificationVisible = false;

Future<void> initializePush({
  required Future<void> Function(String token) onNewToken,
  String? webVapidKey,
}) async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission();

  const channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notificaciones importantes',
    description: 'Canal para mensajes importantes del sistema educativo',
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

  FirebaseMessaging.onMessage.listen((message) async {
    final title = _resolveTitle(message);
    final body = _resolveBody(message);

    if (kIsWeb) {
      await _showWebNotificationDialog(title: title, body: body);
      return;
    }

    await _fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Notificaciones importantes',
          channelDescription:
              'Canal para mensajes importantes del sistema educativo',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  });

  String? token;
  if (kIsWeb) {
    token = await messaging.getToken(vapidKey: webVapidKey);
  } else {
    token = await messaging.getToken();
  }
  if (token != null && token.isNotEmpty) {
    await onNewToken(token);
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
    if (t.isNotEmpty) await onNewToken(t);
  });
}

String _resolveTitle(RemoteMessage message) {
  final title = message.notification?.title?.trim() ?? '';
  if (title.isNotEmpty) return title;
  final dataTitle = message.data['title']?.toString().trim() ?? '';
  if (dataTitle.isNotEmpty) return dataTitle;
  return 'Nueva notificacion';
}

String _resolveBody(RemoteMessage message) {
  final body = message.notification?.body?.trim() ?? '';
  if (body.isNotEmpty) return body;
  final dataBody = message.data['body']?.toString().trim() ?? '';
  if (dataBody.isNotEmpty) return dataBody;
  return 'Tienes una novedad en el sistema educativo.';
}

Future<void> _showWebNotificationDialog({
  required String title,
  required String body,
}) async {
  if (_webNotificationVisible) return;
  final context = appNavigatorKey.currentContext;
  if (context == null) return;

  _webNotificationVisible = true;
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar notificacion',
      barrierColor: Colors.black54,
      pageBuilder: (context, _, _) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Notificacion recibida',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Entendido'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  } finally {
    _webNotificationVisible = false;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // En segundo plano el sistema operativo o el service worker muestran la push.
}
