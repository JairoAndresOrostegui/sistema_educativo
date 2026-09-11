import 'dart:async';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'notification_destination.dart';
import 'firebase_utils.dart';
import '../providers/user_provider_v2.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_navigator.dart';
import '../config/firebase_options.dart';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
bool _webNotificationVisible = false;
final _pendingWebNotifications =
    <({String title, String body, Map<String, dynamic> data})>[];
bool _pushListenersInitialized = false;
String? _webVapidKey;
Future<void> Function(String token)? _tokenHandler;

void _openNotification(Map<String, dynamic> data) {
  final context = appNavigatorKey.currentContext;
  final role = context?.read<UserProviderV2>().user?.role;
  final destination = notificationDestination(data, role: role);
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
      onError: (_) {},
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
      try {
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
          id: DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
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
      } catch (_) {
        // Una notificación defectuosa no debe interrumpir la aplicación.
      }
    }, onError: (_) {});

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        final handler = _tokenHandler;
        if (token.isNotEmpty && handler != null) await handler(token);
      } catch (_) {
        // El siguiente refresh o inicio de sesión vuelve a registrar el token.
      }
    }, onError: (_) {});
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
  return 'Nueva notificación';
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
  if (_webNotificationVisible) {
    if (_pendingWebNotifications.length >= 20) {
      _pendingWebNotifications.removeAt(0);
    }
    _pendingWebNotifications.add((
      title: title,
      body: body,
      data: Map<String, dynamic>.from(data),
    ));
    return;
  }
  final context = appNavigatorKey.currentContext;
  if (context == null) return;
  final scheme = Theme.of(context).colorScheme;
  final role = context.read<UserProviderV2>().user?.role;
  final destination = notificationDestination(data, role: role);

  _webNotificationVisible = true;
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar notificación',
      barrierColor: scheme.scrim.withValues(alpha: .54),
      pageBuilder: (context, _, _) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420),
              child: Material(
                color: scheme.surface.withValues(alpha: 0),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.18),
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
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.notifications_active_outlined,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Notificación recibida',
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
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _openNotification(data);
                          },
                          child: Text(
                            destination == null ? 'Entendido' : 'Abrir módulo',
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
    if (_pendingWebNotifications.isNotEmpty) {
      final next = _pendingWebNotifications.removeAt(0);
      unawaited(
        _showWebNotificationDialog(
          title: next.title,
          body: next.body,
          data: next.data,
        ),
      );
    }
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
