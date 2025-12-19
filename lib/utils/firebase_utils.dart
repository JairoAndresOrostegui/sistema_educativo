import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> fRequestPermission() async {
  final messaging = FirebaseMessaging.instance;

  if (kIsWeb) {
    await messaging.requestPermission();
  } else {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      //print('Permiso de notificaciones no concedido');
    }
  }
}

Future<void> saveUserFcmToken({
    required String userId,
    required String token,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }
