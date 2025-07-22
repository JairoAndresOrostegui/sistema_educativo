import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/firebase_options.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 🔹 Registrar el handler para segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔹 Obtener el token del dispositivo (lo necesitarás para enviar mensajes)
  final fcmToken = await FirebaseMessaging.instance.getToken();

  // 🔹 Pedir permisos para notificaciones (solo necesario en iOS y web)
  await FirebaseMessaging.instance.requestPermission();

  runApp(const App());
}
