import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRouteLogService {
  static Future<List<Map<String, dynamic>>> obtenerHistorialRutasAdmin() async {
    final query = await FirebaseFirestore.instance
        .collection('historial_rutas_admin')
        .orderBy('fecha', descending: true)
        .get();

    return query.docs.map((doc) => doc.data()).toList();
  }
}