import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('usuarios').doc(user.uid).get();
    return doc.data();
  }

  Future<String?> uploadProfilePhoto(
    Uint8List bytes,
    String nombreOriginal,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final nombreArchivo = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = _storage.ref().child('fotos_perfil/${user.uid}/$nombreArchivo');
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final url = await uploadTask.ref.getDownloadURL();
    await _firestore.collection('usuarios').doc(user.uid).update({
      'fotoUrl': url,
    });
    return url;
  }

  Future<String> subirFotoPerfil({
    required Uint8List bytes,
    required String uid,
  }) async {
    final nombreArchivo = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = _storage.ref().child('fotos_perfil/$uid/$nombreArchivo');
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final url = await uploadTask.ref.getDownloadURL();

    // Actualizar Firestore
    await _firestore.collection('usuarios').doc(uid).update({'fotoUrl': url});

    return url;
  }
}
