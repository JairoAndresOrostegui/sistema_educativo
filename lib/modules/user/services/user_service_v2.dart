import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../models/user/user_model_v2.dart';

class UserServiceV2 {
  final _db = FirebaseFirestore.instance;

  /// Obtener todos los usuarios desde la coleccion 'users'
  Future<List<userModelv2>> obtenerTodos({
    required String institutionId,
    required String campusId,
  }) async {
    final snapshot =
        await _db
            .collection('users')
            .where('institution', isEqualTo: institutionId)
            .where('campus', isEqualTo: campusId)
            .get();

    return snapshot.docs
        .map((doc) => userModelv2.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Obtener usuario por ID
  Future<userModelv2?> obtenerPorId({
    required String uid,
    required String institutionId,
    required String campusId,
  }) async {
    final doc =
        await _db
            .collection('users')
            .where(FieldPath.documentId, isEqualTo: uid)
            .where('institution', isEqualTo: institutionId)
            .where('campus', isEqualTo: campusId)
            .limit(1)
            .get();

    if (doc.docs.isEmpty) return null;
    return userModelv2.fromFirestore(doc.docs.first.data(), doc.docs.first.id);
  }

  /// Guardar o actualizar un usuario en Firestore
  Future<void> guardarUsuario(userModelv2 usuario) async {
    if (usuario.id.trim().isEmpty) {
      throw Exception('El ID del usuario no puede estar vacio');
    }
    await _db
        .collection('users')
        .doc(usuario.id)
        .set(usuario.toMap(), SetOptions(merge: true));
  }

  /// Generar un nuevo UID local (no para Auth, solo ID de Firestore)
  Future<String> generarNuevoUid() async {
    final docRef = _db.collection('users').doc();
    return docRef.id;
  }

  /// Crear usuario en Firebase Auth via Cloud Function
  Future<String> crearUsuarioDesdeAdmin({
    required String email,
    required String password,
    required String nombres,
    required String apellidos,
    required String rol,
    required String documento,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'crearUsuarioDesdeAdmin',
    );
    final result = await callable.call({
      'email': email,
      'password': password,
      'nombres': nombres,
      'apellidos': apellidos,
      'rol': rol,
      'documento': documento,
    });

    if (result.data['exito'] != true) {
      throw Exception('No se pudo crear el usuario');
    }

    return result.data['uid'];
  }

  /// Eliminar usuario de Firebase Auth via Cloud Function
  Future<void> eliminarUsuarioAuth(String uid) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'eliminarUsuarioAuth',
    );
    final result = await callable.call({'uid': uid});

    if (result.data['success'] != true) {
      throw Exception('No se pudo eliminar el usuario en Auth');
    }
  }

  /// Eliminar usuario completamente del sistema (Auth + Firestore)
  Future<void> eliminar(userModelv2 usuario) async {
    await eliminarUsuarioAuth(usuario.id);
    await _db.collection('users').doc(usuario.id).delete();
  }

  Future<void> actualizarQr({
    required String uid,
    required String payload,
  }) async {
    await _db.collection('users').doc(uid).set({
      'qrPayload': payload,
      'qrEnabled': true,
      'qrUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Registrar historial de acciones del usuario (agrega institution/campus)
  Future<void> registrarHistorial({
    required userModelv2 usuario,
    required String accion,
    required String realizadoPor,
  }) async {
    await _db.collection('user_history').add({
      'usuarioId': usuario.id,
      'nombres': usuario.firstName,
      'apellidos': usuario.lastName,
      'rol': usuario.role,
      'accion': accion,
      'realizadoPor': realizadoPor,
      'institution': usuario.institution,
      'campus': usuario.campus,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  // ================== VALIDACIONES DE UNICIDAD ==================

  Future<bool> existeCorreoPersonal(String email, {String? excluirId}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final snap =
        await _db
            .collection('users')
            .where('personalEmail', isEqualTo: normalizedEmail)
            .limit(5)
            .get();

    if (snap.docs.isEmpty) return false;
    if (excluirId == null) return true;
    return snap.docs.any((d) => d.id != excluirId);
  }

  Future<bool> existeCorreoInstitucional(
    String email, {
    String? excluirId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final snap =
        await _db
            .collection('users')
            .where('institutionalEmail', isEqualTo: normalizedEmail)
            .limit(5)
            .get();

    if (snap.docs.isEmpty) return false;
    if (excluirId == null) return true;
    return snap.docs.any((d) => d.id != excluirId);
  }

  Future<bool> existeDocumento(String documento, {String? excluirId}) async {
    final snap =
        await _db
            .collection('users')
            .where('document', isEqualTo: documento.trim())
            .limit(5)
            .get();

    if (snap.docs.isEmpty) return false;
    if (excluirId == null) return true;
    return snap.docs.any((d) => d.id != excluirId);
  }
}
