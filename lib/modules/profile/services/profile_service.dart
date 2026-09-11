import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'profile_photo_commit.dart';

class ProfileService {
  static const int _maxPhotoBytes = 5 * 1024 * 1024;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfilePhoto(
    Uint8List bytes,
    String nombreOriginal,
  ) async {
    _validatePhoto(bytes, nombreOriginal);
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Tu sesión venció. Inicia sesión nuevamente.');
    }

    final esPng = nombreOriginal.toLowerCase().endsWith('.png');
    final extension = esPng ? 'png' : 'jpg';
    final nombreArchivo =
        'foto_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final ref = _storage.ref().child('fotos_perfil/${user.uid}/$nombreArchivo');
    late final String url;
    try {
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: esPng ? 'image/png' : 'image/jpeg'),
      );
      url = await uploadTask.ref.getDownloadURL();
    } catch (_) {
      // Aún no se solicitó la confirmación: es seguro descartar esta carga.
      try {
        await ref.delete();
      } catch (_) {}
      rethrow;
    }
    await commitProfilePhoto(
      confirm: () async {
        final result = await FirebaseFunctions.instance
            .httpsCallable('actualizarFotoPerfil')
            .call({'storagePath': ref.fullPath, 'photoUrl': url});
        final response = Map<String, dynamic>.from(result.data as Map);
        if (response['success'] != true) {
          throw StateError('No se pudo confirmar la foto. Recarga tu perfil.');
        }
        return (response['previousPhotoUrl'] ?? '').toString();
      },
      discardUpload: ref.delete,
      cleanupPrevious: (previousUrl) =>
          _deleteManagedProfilePhoto(previousUrl, exceptUrl: url),
    );
    return url;
  }

  Future<String> subirFotoPerfil({
    required Uint8List bytes,
    required String uid,
    String? fileName,
  }) async {
    _validatePhoto(bytes, fileName ?? 'foto.jpg');
    final esPng = (fileName ?? '').toLowerCase().endsWith('.png');
    final extension = esPng ? 'png' : 'jpg';
    final nombreArchivo =
        'foto_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final ref = _storage.ref().child('fotos_perfil/$uid/$nombreArchivo');
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: esPng ? 'image/png' : 'image/jpeg'),
    );
    // La edición de un perfil ajeno debe confirmarse mediante la Cloud Function
    // de Usuarios. Las reglas prohíben correctamente que el administrador
    // escriba directamente users/{uid}.
    return uploadTask.ref.getDownloadURL();
  }

  Future<void> deleteUploadedProfilePhoto(String url) =>
      _deleteManagedProfilePhoto(url);

  void _validatePhoto(Uint8List bytes, String fileName) {
    if (bytes.isEmpty) {
      throw StateError('La imagen seleccionada está vacía.');
    }
    if (bytes.length > _maxPhotoBytes) {
      throw StateError('La foto no puede superar 5 MB.');
    }
    final name = fileName.trim().toLowerCase();
    if (!name.endsWith('.jpg') &&
        !name.endsWith('.jpeg') &&
        !name.endsWith('.png')) {
      throw StateError('Usa una foto en formato JPG, JPEG o PNG.');
    }
  }

  Future<void> _deleteManagedProfilePhoto(
    String url, {
    String? exceptUrl,
  }) async {
    final normalized = url.trim();
    if (normalized.isEmpty || normalized == exceptUrl) return;
    try {
      final reference = _storage.refFromURL(normalized);
      if (!reference.fullPath.startsWith('fotos_perfil/')) return;
      await reference.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    } on ArgumentError {
      // Las fotos externas o heredadas no pertenecen al almacenamiento
      // administrado y no se intentan eliminar.
    }
  }
}
