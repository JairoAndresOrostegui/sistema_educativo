import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../models/user/userModelV2.dart';
import '../../../utils/user_log_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  static const String estadoActivo = 'activo';

  Future<UserModelV2?> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw Exception('No se pudo identificar el usuario.');
      }

      final usuariosRef = _firestore.collection('users');
      final query =
          await usuariosRef
              .where('institutionalEmail', isEqualTo: email.trim())
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        await _auth.signOut();
        throw Exception('El usuario no está registrado en la base de datos.');
      }

      final userDoc = query.docs.first;
      final data = userDoc.data();
      final uidFirestore = userDoc.id;

      if ((data['status'] ?? '').toLowerCase() != estadoActivo) {
        await _auth.signOut();
        throw Exception(
          'El usuario está inactivo. Comuníquese con el administrador.',
        );
      }

      try {
        // (opcional pero recomendado en iOS/Android 13+)
        await FirebaseMessaging.instance.requestPermission();

        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          // Limpia duplicados en otros usuarios
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

          // Guarda token en el usuario actual
          await usuariosRef.doc(uidFirestore).update({
            'fcmToken': token,
            'fcmTokens': FieldValue.arrayUnion([token]),
          });

          // Mantén actualizado si cambia el token
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
            await usuariosRef.doc(uidFirestore).update({
              'fcmToken': newToken,
              'fcmTokens': FieldValue.arrayUnion([newToken]),
            });
          });
        }
      } catch (_) {
        // Silencia error de FCM sin afectar login
      }

      return UserModelV2.fromFirestore(data, uidFirestore);
    } on FirebaseAuthException catch (e) {
      print(e.code);
      switch (e.code) {
        case 'invalid-credential':
          throw Exception(
            'No existe una cuenta con ese correo o la contraseña es incorrecta.',
          );
        case 'wrong-password':
          throw Exception('Contraseña incorrecta.');
        case 'user-disabled':
          throw Exception('La cuenta está deshabilitada.');
        case 'too-many-requests':
          throw Exception('Demasiados intentos. Intenta más tarde.');
        case 'network-request-failed':
          throw Exception('Error de red. Verifica tu conexión.');
        default:
          throw Exception('Ocurrió un error al iniciar sesión.');
      }
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final usuarios = _firestore.collection('users');
    QuerySnapshot<Map<String, dynamic>> query =
        await usuarios
            .where('institutionalEmail', isEqualTo: email.trim())
            .get();

    if (query.docs.isEmpty) {
      throw Exception('No existe una cuenta con ese correo.');
    }

    final userData = query.docs.first.data();
    final role = userData['role'];

    if (role == 'Estudiante') {
      throw Exception(
        'Este correo pertenece a un estudiante. Por favor, comuníquese con el administrador.',
      );
    }

    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> logout(UserModelV2 currentUser) async {
    try {
      await UserLogService().logEvent(user: currentUser, event: 'logout');
    } catch (_) {}
    await _auth.signOut();
  }
}
