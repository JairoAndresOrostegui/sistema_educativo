import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';

String get _notificationSlot => kIsWeb ? 'web' : 'mobile';

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
      // ignore
    }
  }
}

Future<void> saveUserNotificationToken({
  required String userId,
  required String token,
}) async {
  final cleanToken = token.trim();
  if (cleanToken.isEmpty) return;

  final users = FirebaseFirestore.instance.collection('users');
  final docRef = users.doc(userId);
  final slotPath = 'notificationTokens.$_notificationSlot';

  final sameWeb =
      await users.where('notificationTokens.web', isEqualTo: cleanToken).get();
  for (final doc in sameWeb.docs) {
    if (doc.id == userId && _notificationSlot == 'web') continue;
    await doc.reference.update({'notificationTokens.web': FieldValue.delete()});
  }

  final sameMobile =
      await users
          .where('notificationTokens.mobile', isEqualTo: cleanToken)
          .get();
  for (final doc in sameMobile.docs) {
    if (doc.id == userId && _notificationSlot == 'mobile') continue;
    await doc.reference.update({
      'notificationTokens.mobile': FieldValue.delete(),
    });
  }

  try {
    await docRef.update({
      slotPath: cleanToken,
      'fcmToken': FieldValue.delete(),
      'fcmTokens': FieldValue.delete(),
    });
  } catch (_) {
    await docRef.set({
      'notificationTokens': <String, dynamic>{_notificationSlot: cleanToken},
    }, SetOptions(merge: true));
    await docRef.update({
      'fcmToken': FieldValue.delete(),
      'fcmTokens': FieldValue.delete(),
    });
  }
}

Future<void> clearUserNotificationToken({required String userId}) async {
  final users = FirebaseFirestore.instance.collection('users');
  try {
    await users.doc(userId).update({
      'notificationTokens.$_notificationSlot': FieldValue.delete(),
    });
  } catch (_) {}
}
