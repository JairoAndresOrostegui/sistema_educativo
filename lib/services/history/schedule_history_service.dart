import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleHistoryService {
  static Future<List<Map<String, dynamic>>> obtenerHistorialHorarios() async {
    final query = await FirebaseFirestore.instance
        .collection('historial_horarios')
        .orderBy('fecha', descending: true)
        .get();

    return query.docs.map((doc) => doc.data()).toList();
  }
}
