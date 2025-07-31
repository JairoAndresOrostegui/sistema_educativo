import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RutaHistoryService {
  final _db = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> obtenerHistorialRutas({
    String? nombreRuta,
    String? estado,
    DateTime? fecha,
    required int limite,
    int pagina = 0,
  }) async {
    if (!kIsWeb) return [];

    Query<Map<String, dynamic>> query = _db
        .collection('rutas_diarias')
        .orderBy('fecha', descending: true)
        .limit(limite);

    if (nombreRuta != null && nombreRuta.trim().isNotEmpty) {
      query = query.where('nombreRuta', isEqualTo: nombreRuta.trim());
    }
    if (estado != null && estado.trim().isNotEmpty) {
      query = query.where('estado', isEqualTo: estado.trim());
    }
    if (fecha != null) {
      final inicio = DateTime(fecha.year, fecha.month, fecha.day);
      final fin = inicio.add(const Duration(days: 1));
      query = query
          .where('fecha', isGreaterThanOrEqualTo: inicio)
          .where('fecha', isLessThan: fin);
    }

    final snap = await query.get();

    final List<Map<String, dynamic>> rutas = [];

    for (final doc in snap.docs) {
      final data = doc.data();
      data['id'] = doc.id;

      // 🔽 Aquí se cargan los estudiantes desde la subcolección
      final estudiantesSnap =
          await doc.reference.collection('estudiantes').get();
      data['estudiantes'] = estudiantesSnap.docs.map((e) => e.data()).toList();

      rutas.add(data);
    }

    return rutas;
  }

  Future<List<String>> obtenerNombresDeRutas() async {
    final snap = await _db.collection('rutas_diarias').get();
    final nombres =
        snap.docs
            .map((d) => d.data()['nombreRuta'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
    nombres.sort();
    return nombres;
  }

  Future<int> contarRutasFinalizadas() async {
    final snap =
        await _db
            .collection('rutas_diarias')
            .where('estado', isEqualTo: 'finalizada')
            .get();
    return snap.docs.length;
  }
}
