import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/file/file_model.dart';
import '../notification/notification_service.dart';

class ArchivoService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> subirArchivo({
    required File archivo,
    required String nombre,
    required String grado,
    required String nombreSubidor,
  }) async {
    final ruta =
        'archivos/$grado/${DateTime.now().millisecondsSinceEpoch}_${archivo.path.split('/').last}';
    final ref = _storage.ref().child(ruta);

    // Subir a Firebase Storage
    await ref.putFile(archivo);
    final url = await ref.getDownloadURL();

    // Guardar en Firestore
    final data = {
      'nombre': nombre,
      'url': url,
      'grado': grado,
      'subidoPor': _uid,
      'nombreSubidor': nombreSubidor,
      'fecha': FieldValue.serverTimestamp(),
    };

    await _db.collection('archivos').add(data);

    // Enviar notificación
    await _notificarEstudiantes(grado, '📎 Nuevo archivo disponible', nombre);
  }

  Future<List<ArchivoModel>> obtenerArchivosPorGrado(String grado) async {
    final snap =
        await _db
            .collection('archivos')
            .where('grado', isEqualTo: grado)
            .orderBy('fecha', descending: true)
            .get();

    return snap.docs.map((d) => ArchivoModel.fromFirestore(d)).toList();
  }

  Future<void> eliminarArchivo(String docId, String url) async {
    // Eliminar de Firestore
    await _db.collection('archivos').doc(docId).delete();

    // Eliminar de Storage
    final ref = _storage.refFromURL(url);
    await ref.delete();
  }

  Future<void> _notificarEstudiantes(
    String grado,
    String titulo,
    String cuerpo,
  ) async {
    final snap =
        await _db
            .collection('usuarios')
            .where('grado', isEqualTo: grado)
            .where('activo', isEqualTo: true)
            .get();

    final tokens =
        snap.docs
            .map((d) => List<String>.from(d.data()['fcmTokens'] ?? []))
            .expand((e) => e)
            .toList();

    if (tokens.isNotEmpty) {
      await enviarNotificacion(tokens: tokens, titulo: titulo, cuerpo: cuerpo);
    }
  }

  Future<List<Map<String, dynamic>>> obtenerArchivosSubidos({
    required String? gradoSeleccionado,
  }) async {
    final userSnap = await _db.collection('usuarios').doc(_uid).get();
    final rol = userSnap['rol'];
    final gradoUsuario = userSnap.data()?['grado'];

    Query query = _db.collection('archivos');

    if (rol == 'admin') {
      if (gradoSeleccionado == null) return [];
      query = query.where('grado', isEqualTo: gradoSeleccionado);
    } else {
      query = query.where('uploaderId', isEqualTo: _uid);
    }

    final snap = await query.orderBy('fechaSubida', descending: true).get();

    return snap.docs
        .where((d) => d.data() != null && d.data() is Map<String, dynamic>)
        .map((d) {
          final data = Map<String, dynamic>.from(d.data() as Map);
          data['id'] = d.id;
          return data;
        })
        .toList();
  }
}
