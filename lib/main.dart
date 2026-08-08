import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'config/firebase_options.dart';
import 'config/theme_config.dart';
import 'providers/user_provider_v2.dart';
import 'utils/push_notifications.dart';
import 'widgets/push_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      Firebase.app();
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // Fondo (Android)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await ThemeProvider.cargarConfiguracion();
  } catch (e) {
    debugPrint('Error al cargar configuracion de tema: $e');
    ThemeProvider.usarConfiguracionPredeterminada();
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProviderV2(),
      child: const PushBootstrap(
        webVapidKey:
            'BCWDKdFxjGMarEkk6xvvs5jw0mnJEN22UFAKmd-DbT7Lwipt4rwHhKTnF0GaTphnkk0-CmCerzJIidz8kkfrV-s',
        child: AppRouter(),
      ),
    ),
  );
}
