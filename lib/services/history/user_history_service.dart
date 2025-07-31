import 'package:cloud_firestore/cloud_firestore.dart';

class UserHistoryService {
  final _ref = FirebaseFirestore.instance.collection('historial_usuarios');

  Future<List<Map<String, dynamic>>> obtenerHistorial() async {
    final query = await _ref.orderBy('fecha', descending: true).get();

    return query.docs.map((doc) {
      final data = doc.data();
      return {
        'accion': data['accion'] ?? '',
        'nombres': data['nombres'] ?? '',
        'apellidos': data['apellidos'] ?? '',
        'rol': data['rol'] ?? '',
        'realizadoPor': data['realizadoPor'] ?? '',
        'fecha': (data['fecha'] as Timestamp).toDate(),
      };
    }).toList();
  }
}
