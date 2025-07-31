import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentHistoryService {
  final _ref = FirebaseFirestore.instance.collection('archivos');

  Future<List<Map<String, dynamic>>> obtenerHistorialDocumentos() async {
    final query = await _ref.orderBy('fechaSubida', descending: true).get();

    return query.docs.map((doc) {
      final data = doc.data();
      return {
        'nombre': data['nombre'] ?? '',
        'grado': data['grado'] ?? '',
        'subidoPor': data['subidoPor'] ?? '',
        'fechaSubida': (data['fechaSubida'] as Timestamp?)?.toDate(),
      };
    }).toList();
  }
}
