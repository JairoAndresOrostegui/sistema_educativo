import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PushDeviceSession {
  static String? _uid;
  static String? _sessionId;
  static final enabled = ValueNotifier<bool>(false);
  static final error = ValueNotifier<String?>(null);
  static String get slot => kIsWeb ? 'web' : 'mobile';

  static void newLogin(String uid) {
    _uid = uid;
    final random = Random.secure();
    _sessionId = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    enabled.value = false;
    error.value = null;
  }

  static Future<Map<String, dynamic>> action(
    String action, {
    String? token,
  }) async {
    if (_uid == null || FirebaseAuth.instance.currentUser?.uid != _uid) {
      throw StateError('Inicia sesión nuevamente.');
    }
    final result = await FirebaseFunctions.instance
        .httpsCallable('gestionarDispositivoPush')
        .call({
          'slot': slot,
          'sessionId': _sessionId,
          'action': action,
          'token': ?token,
        });
    if (result.data is! Map) {
      throw const FormatException(
        'El servidor devolvió una respuesta de notificaciones no válida.',
      );
    }
    final data = Map<String, dynamic>.from(result.data as Map);
    enabled.value = data['enabled'] == true;
    error.value = null;
    return data;
  }
}

Future<void> clearUserNotificationToken({required String userId}) async {
  if (FirebaseAuth.instance.currentUser?.uid == userId) {
    await PushDeviceSession.action('disable');
  }
}
