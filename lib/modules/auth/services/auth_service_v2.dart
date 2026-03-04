// ignore: file_names
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../models/user/user_model_v2.dart';
import '../../../utils/user_log_service.dart';
import '../utils/auth_error_mapper.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  static const String estadoActivo = 'activo';
  static const List<String> _rolesPermitidos = <String>[
    'Administrador',
    'Docente',
    'Estudiante',
    'Familiar',
  ];
  static StreamSubscription<String>? _tokenRefreshSub;

  Future<userModelv2?> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final correoLower = email.trim().toLowerCase();
    final userDoc = await _findUserByInstitutionalEmail(correoLower);
    await _ensureNotLocked(userDoc);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final firebaseUser = credential.user;
      final uid = firebaseUser?.uid;
      if (uid == null) {
        throw Exception('No se pudo identificar el usuario.');
      }

      final usuariosRef = _firestore.collection('users');
      final userSnap = await usuariosRef.doc(uid).get();

      if (!userSnap.exists) {
        await _auth.signOut();
        throw Exception('El usuario no esta registrado en la base de datos.');
      }

      final data = userSnap.data() ?? {};
      final uidFirestore = userSnap.id;

      final correoGuardado =
          (data['institutionalEmail'] ?? '').toString().trim().toLowerCase();
      if (correoGuardado.isNotEmpty &&
          correoGuardado != email.trim().toLowerCase()) {
        await _auth.signOut();
        throw Exception(
          'El correo no coincide con el registrado para esta cuenta.',
        );
      }

      if (firebaseUser != null && !firebaseUser.emailVerified) {
        await _auth.signOut();
        throw Exception('Debes verificar tu correo antes de iniciar sesión.');
      }

      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status != estadoActivo) {
        await _auth.signOut();
        throw Exception(
          'El usuario esta inactivo. Comuniquese con el administrador.',
        );
      }

      // limpiar intentos fallidos al login exitoso
      if (userDoc != null) {
        await _resetFailedAttempts(userDoc.id);
      }

      try {
        await FirebaseMessaging.instance.requestPermission();

        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          final dupSingle =
              await usuariosRef.where('fcmToken', isEqualTo: token).get();
          for (final d in dupSingle.docs) {
            if (d.id != uidFirestore) {
              await d.reference.update({'fcmToken': FieldValue.delete()});
            }
          }
          final dupArray =
              await usuariosRef.where('fcmTokens', arrayContains: token).get();
          for (final d in dupArray.docs) {
            if (d.id != uidFirestore) {
              await d.reference.update({
                'fcmTokens': FieldValue.arrayRemove([token]),
              });
            }
          }

          await usuariosRef.doc(uidFirestore).update({
            'fcmToken': token,
            'fcmTokens': FieldValue.arrayUnion([token]),
          });

          await _tokenRefreshSub?.cancel();
          _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
            newToken,
          ) async {
            await usuariosRef.doc(uidFirestore).update({
              'fcmToken': newToken,
              'fcmTokens': FieldValue.arrayUnion([newToken]),
            });
          });
        }
      } catch (_) {
        // Silencia error de FCM sin afectar login
      }

      final userModel = userModelv2.fromFirestore(data, uidFirestore);

      // Validaciones adicionales de rol y tenant
      if ((userModel.institution).toString().trim().isEmpty ||
          (userModel.campus).toString().trim().isEmpty) {
        await _auth.signOut();
        throw Exception(AuthErrorMapper.missingTenantMessage);
      }
      if (!_rolesPermitidos.contains(userModel.role)) {
        await _auth.signOut();
        throw Exception(AuthErrorMapper.invalidRoleMessage);
      }

      try {
        await UserLogService().logEvent(user: userModel, event: 'login');
      } catch (_) {
        // log best-effort; no romper el login
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      final code = e.code;
      if (code == 'invalid-credential' || code == 'wrong-password') {
        if (userDoc != null) {
          final locked = await _incrementFailedAttempts(userDoc.id);
          if (locked) {
            throw Exception(AuthErrorMapper.lockMessage);
          }
        }
      }
      throw Exception(AuthErrorMapper.mapFirebaseCode(code));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final usuarios = _firestore.collection('users');
    final emailTrim = email.trim();
    final emailLower = emailTrim.toLowerCase();

    // Intento 1: correo tal cual
    QuerySnapshot<Map<String, dynamic>> query =
        await usuarios.where('institutionalEmail', isEqualTo: emailTrim).get();

    // Intento 2: en minúsculas (para tolerar mayúsculas al escribir)
    if (query.docs.isEmpty && emailLower != emailTrim) {
      query =
          await usuarios
              .where('institutionalEmail', isEqualTo: emailLower)
              .get();
    }

    if (query.docs.isEmpty) {
      throw Exception('No existe una cuenta con ese correo.');
    }

    final userData = query.docs.first.data();
    final role = userData['role']?.toString() ?? '';
    final status = userData['status']?.toString().toLowerCase() ?? '';

    if (role == 'Estudiante') {
      throw Exception(
        'Este correo pertenece a un estudiante. Por favor, comuniquese con el administrador.',
      );
    }

    if (status != estadoActivo) {
      throw Exception(
        'El usuario esta inactivo. Solicite ayuda al administrador.',
      );
    }

    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> logout(userModelv2 currentUser) async {
    try {
      await UserLogService().logEvent(user: currentUser, event: 'logout');
    } catch (_) {}
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _auth.signOut();
  }

  // === Manejo de intentos fallidos ===
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserByInstitutionalEmail(
    String emailLower,
  ) async {
    try {
      final snap =
          await _firestore
              .collection('users')
              .where('institutionalEmail', isEqualTo: emailLower)
              .limit(1)
              .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureNotLocked(
    DocumentSnapshot<Map<String, dynamic>>? userDoc,
  ) async {
    if (userDoc == null) return;
    final data = userDoc.data() ?? {};
    final lockedUntil = data['lockedUntil'];
    if (lockedUntil is Timestamp) {
      final dt = lockedUntil.toDate();
      if (DateTime.now().isBefore(dt)) {
        throw Exception(
          'Cuenta bloqueada por intentos fallidos. Intenta de nuevo en 15 minutos.',
        );
      }
    }
  }

  Future<bool> _incrementFailedAttempts(String userId) async {
    try {
      final ref = _firestore.collection('users').doc(userId);
      return await _firestore.runTransaction<bool>((txn) async {
        final snap = await txn.get(ref);
        final data = snap.data() ?? {};
        final current = (data['loginAttempts'] ?? 0) as int;
        final next = current + 1;
        if (next >= 5) {
          final lockUntil = Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 15)),
          );
          txn.update(ref, {'loginAttempts': 0, 'lockedUntil': lockUntil});
          return true;
        } else {
          txn.update(ref, {'loginAttempts': next});
          return false;
        }
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> _resetFailedAttempts(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'loginAttempts': 0,
        'lockedUntil': FieldValue.delete(),
      });
    } catch (_) {}
  }
}
