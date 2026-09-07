import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'config/firebase_options.dart';
import 'config/app_environment.dart';
import 'config/theme_config.dart';
import 'providers/user_provider_v2.dart';
import 'utils/push_notifications.dart';
import 'widgets/push_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) AppEnvironment.validateWebHost(Uri.base.host);
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
  if (Firebase.app().options.projectId !=
      DefaultFirebaseOptions.currentPlatform.projectId) {
    throw StateError(
      'La configuración nativa y Flutter usan distintos entornos.',
    );
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
      child: PushBootstrap(
        webVapidKey: AppEnvironment.webVapidKey,
        child: const AppRouter(),
      ),
    ),
  );
}
