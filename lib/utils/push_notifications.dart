import 'package:sistema_educativo/config/app_palette.dart';
import 'dart:async';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'notification_destination.dart';
import 'firebase_utils.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_navigator.dart';
import '../config/firebase_options.dart';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
bool _webNotificationVisible = false;
bool _pushListenersInitialized = false;
String? _webVapidKey;
Future<void> Function(String token)? _tokenHandler;

void _openNotification(Map<String, dynamic> data) {
  final destination = notificationDestination(data);
  final context = appNavigatorKey.currentContext;
  if (destination != null && context != null) {
    GoRouter.of(context).go(destination);
  }
}

void _openPayload(String? payload) {
  if (payload == null) return;
  try {
    _openNotification(Map<String, dynamic>.from(jsonDecode(payload) as Map));
  } catch (_) {
    /* Una notificación inválida no navega. */
  }
}

Future<void> initializePush({
  required Future<void> Function(String token) onNewToken,
  String? webVapidKey,
}) async {
  final messaging = FirebaseMessaging.instance;
  _webVapidKey = webVapidKey;
  _tokenHandler = onNewToken;

  if (kIsWeb && (webVapidKey == null || webVapidKey.isEmpty)) {
    throw StateError(
      'Falta configurar la clave web de notificaciones de este entorno.',
    );
  }

  final permission = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  if (permission.authorizationStatus == AuthorizationStatus.denied) return;

  final channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notificaciones importantes',
    description: 'Canal para mensajes importantes del sistema educativo',
    importance: Importance.high,
  );

  if (!kIsWeb) {
    await _fln
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    final initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _fln.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) =>
          _openPayload(response.payload),
    );
  }

  if (!_pushListenersInitialized) {
    _pushListenersInitialized = true;
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _openNotification(message.data),
    );
    final initial = await messaging.getInitialMessage();
    if (initial != null) _openNotification(initial.data);
    if (!kIsWeb) {
      final launch = await _fln.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _openPayload(launch?.notificationResponse?.payload);
      }
    }
    FirebaseMessaging.onMessage.listen((message) async {
      final title = _resolveTitle(message);
      final body = _resolveBody(message);

      if (kIsWeb) {
        await _showWebNotificationDialog(
          title: title,
          body: body,
          data: message.data,
        );
        return;
      }

      await _fln.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        payload: jsonEncode(message.data),
        notificationDetails: NotificationDetails(
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

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final handler = _tokenHandler;
      if (token.isNotEmpty && handler != null) await handler(token);
    });
  }

  String? token;
  if (kIsWeb) {
    token = await messaging.getToken(vapidKey: webVapidKey);
  } else {
    token = await messaging.getToken();
  }
  if (token != null && token.isNotEmpty) {
    await PushDeviceSession.action('enable', token: token);
  }
}

void clearPushTokenHandler() => _tokenHandler = null;
void configurePushVapidKey(String? key) => _webVapidKey = key;

Future<bool> enablePushFromHome() async {
  final permission = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  if (permission.authorizationStatus == AuthorizationStatus.denied ||
      permission.authorizationStatus == AuthorizationStatus.notDetermined) {
    return false;
  }
  await PushDeviceSession.action('begin');
  await initializePush(
    webVapidKey: _webVapidKey,
    onNewToken: (token) async {
      await PushDeviceSession.action('refresh', token: token);
    },
  );
  return PushDeviceSession.enabled.value;
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
  Map<String, dynamic> data = const {},
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
      barrierColor: AppPalette.onSurface.withValues(alpha: .54),
      pageBuilder: (context, _, _) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420),
              child: Material(
                color: AppPalette.transparent,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.onSurface.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: Offset(0, 10),
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
                              color: AppPalette.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.notifications_active_outlined,
                              color: AppPalette.primary,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
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
                      SizedBox(height: 16),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AppPalette.onSurface.withValues(alpha: .87),
                        ),
                      ),
                      SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.primary,
                            foregroundColor: AppPalette.surface,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _openNotification(data);
                          },
                          child: Text(
                            notificationDestination(data) == null
                                ? 'Entendido'
                                : 'Abrir conversación',
                          ),
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
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  // El sistema operativo o el service worker muestran la notificacion.
}
