import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfilePhoto(
    Uint8List bytes,
    String nombreOriginal,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final esPng = nombreOriginal.toLowerCase().endsWith('.png');
    final extension = esPng ? 'png' : 'jpg';
    final nombreArchivo =
        'foto_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final ref = _storage.ref().child('fotos_perfil/${user.uid}/$nombreArchivo');
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: esPng ? 'image/png' : 'image/jpeg',
      ),
    );

    final url = await uploadTask.ref.getDownloadURL();

    await _firestore.collection('users').doc(user.uid).update({
      'photoUrl': url,
    });

    return url;
  }

  Future<String> subirFotoPerfil({
    required Uint8List bytes,
    required String uid,
    String? fileName,
  }) async {
    final esPng = (fileName ?? '').toLowerCase().endsWith('.png');
    final extension = esPng ? 'png' : 'jpg';
    final nombreArchivo =
        'foto_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final ref = _storage.ref().child('fotos_perfil/$uid/$nombreArchivo');
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: esPng ? 'image/png' : 'image/jpeg'),
    );

    final url = await uploadTask.ref.getDownloadURL();

    await _firestore.collection('users').doc(uid).update({
      'photoUrl': url,
    });

    return url;
  }
}
