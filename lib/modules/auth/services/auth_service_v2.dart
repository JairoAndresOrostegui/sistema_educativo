// ignore: file_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<userModelv2?> loginWithEmailAndPassword(
    String identifier,
    String password,
  ) async {
    final trimmedIdentifier = identifier.trim();
    final isEmailLogin = Validators.isValidEmail(trimmedIdentifier);
    final loginEmail =
        isEmailLogin
            ? trimmedIdentifier.toLowerCase()
            : await _resolveStudentEmail(trimmedIdentifier);

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
      throw Exception(AuthErrorMapper.mapFirebaseCode(e.code));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final emailLower = email.trim().toLowerCase();
    if (!Validators.isValidEmail(emailLower)) {
      throw Exception('Ingresa un correo valido.');
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
    await _auth.signOut();
  }

  Future<String> _resolveStudentEmail(String document) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'resolverLoginPorDocumento',
      );
      final result = await callable.call(<String, dynamic>{
        'documento': document.trim(),
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final email = (data['email'] ?? '').toString().trim().toLowerCase();
      if (email.isEmpty) throw Exception();
      return email;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'No existe una cuenta con ese documento.');
    } catch (_) {
      throw Exception('No se pudo validar el documento. Intenta nuevamente.');
    }
  }
}
