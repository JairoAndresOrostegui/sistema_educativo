import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';
import 'package:cloud_functions/cloud_functions.dart';

class UsuarioService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<UsuarioModel?> obtenerUsuarioActual() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _db.collection('usuarios').doc(user.uid).get();
    if (!snap.exists) return null;

    final usuario = UsuarioModel.fromFirestore(snap.data()!, snap.id);
    return usuario;
  }

  Future<void> guardarUsuario(UsuarioModel usuario) async {
    await _db
        .collection('usuarios')
        .doc(usuario.id)
        .set(usuario.toMap(), SetOptions(merge: true));
  }

  Future<void> registrarDispositivo(String uid) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    // Verificar que no esté en otro usuario
    final duplicados =
        await _db
            .collection('usuarios')
            .where('dispositivos', arrayContains: token)
            .get();

    for (var doc in duplicados.docs) {
      if (doc.id != uid) {
        await _db.collection('usuarios').doc(doc.id).update({
          'dispositivos': FieldValue.arrayRemove([token]),
        });
      }
    }

    await _db.collection('usuarios').doc(uid).update({
      'dispositivos': FieldValue.arrayUnion([token]),
    });
  }

  Future<String> generarNuevoUid() async {
    final docRef = FirebaseFirestore.instance.collection('usuarios').doc();
    return docRef.id;
  }

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

    return result.data['uid']; // <- aquí devuelves el UID
  }

  Future<void> eliminarUsuarioAuth(String uid) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'eliminarUsuarioAuth',
    );

    final result = await callable.call({'uid': uid});
    if (result.data['success'] != true) {
      throw Exception('No se pudo eliminar el usuario en Auth');
    }
  }
}
