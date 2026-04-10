// ignore: file_names
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../models/user/user_model_v2.dart';
import '../../../utils/firebase_utils.dart';
import '../../../utils/user_log_service.dart';
import '../../../utils/validators.dart';
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
    String identifier,
    String password,
  ) async {
    final trimmedIdentifier = identifier.trim();
    final isEmailLogin = Validators.isValidEmail(trimmedIdentifier);
    final normalizedIdentifier =
        isEmailLogin ? trimmedIdentifier.toLowerCase() : trimmedIdentifier;

    final userDoc =
        isEmailLogin
            ? await _findUserByInstitutionalEmail(normalizedIdentifier)
            : await _findUserByDocument(normalizedIdentifier);
    await _ensureNotLocked(userDoc);

    if (userDoc == null) {
      throw Exception(
        isEmailLogin
            ? 'No existe una cuenta con ese correo.'
            : 'No existe un estudiante con ese documento.',
      );
    }

    final loginCandidate = userDoc.data() ?? <String, dynamic>{};
    final loginRole = (loginCandidate['role'] ?? '').toString().trim();
    final loginEmail =
        (loginCandidate['institutionalEmail'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (!isEmailLogin && loginRole != 'Estudiante') {
      throw Exception('Solo los estudiantes pueden iniciar sesion con documento.');
    }

    if (loginEmail.isEmpty) {
      throw Exception('La cuenta no tiene un correo configurado para acceso.');
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: loginEmail,
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

      final data = userSnap.data() ?? <String, dynamic>{};
      final uidFirestore = userSnap.id;

      final correoGuardado =
          (data['institutionalEmail'] ?? '').toString().trim().toLowerCase();
      if (correoGuardado.isNotEmpty && correoGuardado != loginEmail) {
        await _auth.signOut();
        throw Exception(
          'El correo no coincide con el registrado para esta cuenta.',
        );
      }

      final role = (data['role'] ?? '').toString().trim();
      final requiresEmailVerification = role != 'Estudiante';
      if (requiresEmailVerification &&
          firebaseUser != null &&
          !firebaseUser.emailVerified) {
        await _auth.signOut();
        throw Exception('Debes verificar tu correo antes de iniciar sesion.');
      }

      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status != estadoActivo) {
        await _auth.signOut();
        throw Exception(
          'El usuario esta inactivo. Comuniquese con el administrador.',
        );
      }

      await _resetFailedAttempts(userDoc.id);

      try {
        await FirebaseMessaging.instance.requestPermission();

        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          await saveUserNotificationToken(userId: uidFirestore, token: token);

          await _tokenRefreshSub?.cancel();
          _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
            newToken,
          ) async {
            await saveUserNotificationToken(
              userId: uidFirestore,
              token: newToken,
            );
          });
        }
      } catch (_) {
        // Silencia error de FCM sin afectar login
      }

      final userModel = userModelv2.fromFirestore(data, uidFirestore);

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
        final locked = await _incrementFailedAttempts(userDoc.id);
        if (locked) {
          throw Exception(AuthErrorMapper.lockMessage);
        }
      }
      throw Exception(AuthErrorMapper.mapFirebaseCode(code));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final usuarios = _firestore.collection('users');
    final emailTrim = email.trim();
    final emailLower = emailTrim.toLowerCase();

    QuerySnapshot<Map<String, dynamic>> query =
        await usuarios.where('institutionalEmail', isEqualTo: emailTrim).get();

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

    await _auth.sendPasswordResetEmail(email: emailLower);
  }

  Future<void> logout(userModelv2 currentUser) async {
    try {
      await UserLogService().logEvent(user: currentUser, event: 'logout');
    } catch (_) {}
    try {
      await clearUserNotificationToken(userId: currentUser.id);
    } catch (_) {}
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _auth.signOut();
  }

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

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserByDocument(
    String document,
  ) async {
    try {
      final snap =
          await _firestore
              .collection('users')
              .where('document', isEqualTo: document.trim())
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
    final data = userDoc.data() ?? <String, dynamic>{};
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
        final data = snap.data() ?? <String, dynamic>{};
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
