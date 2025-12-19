import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RutaPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  RutaPage({required this.items, required this.hasNext, required this.lastDoc});
}

class RutaHistoryService {
  final _db = FirebaseFirestore.instance;

  static const dailyRoutesCollection = 'daily_routes';
  static const studentsCollectionEn = 'students';
  static const studentsCollectionEs = 'estudiantes';

  Future<RutaPage> obtenerHistorialRutas({
    // ⬇️ filtros OBLIGATORIOS de organización
    required String institutionId,
    required String campusId,

    String? nombreRuta,
    String? estado,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection(dailyRoutesCollection)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId);

    if (nombreRuta != null && nombreRuta.trim().isNotEmpty) {
      q = q.where('nombreRuta', isEqualTo: nombreRuta.trim());
    }
    if (estado != null && estado.trim().isNotEmpty) {
      q = q.where('estado', isEqualTo: estado.trim());
    }
    if (rango != null) {
      q = q
          .where(
            'fecha',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(rango.end));
    }

    // Orden y paginación
    q = q.orderBy('fecha', descending: true).limit(limite);
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final docs = snap.docs;

    final List<Map<String, dynamic>> rutas = [];
    for (final doc in docs) {
      final data = doc.data();
      data['id'] = doc.id;

      // Carga de subcolección (EN primero, si no, ES)
      final studentsCol = doc.reference.collection(studentsCollectionEn);
      final stSnap = await studentsCol.get();
      if (stSnap.docs.isNotEmpty) {
        data['estudiantes'] =
            stSnap.docs.map((e) => _toEsStudent(e.data())).toList();
      } else {
        final stSnapEs =
            await doc.reference.collection(studentsCollectionEs).get();
        data['estudiantes'] = stSnapEs.docs.map((e) => e.data()).toList();
      }

      rutas.add(data);
    }

    final hasNext = docs.length == limite;
    final lastDoc = docs.isNotEmpty ? docs.last : null;

    return RutaPage(items: rutas, hasNext: hasNext, lastDoc: lastDoc);
  }

  Map<String, dynamic> _toEsStudent(Map<String, dynamic> en) {
    return {
      'id': en['id'],
      'nombre': en['nombre'] ?? en['name'],
      'direccion': en['direccion'] ?? en['address'],
      'activo': en['activo'] ?? en['active'] ?? false,
      'recogido': en['recogido'] ?? en['picked'] ?? false,
      'horaRecogida': en['horaRecogida'] ?? en['pickupTime'],
      'avisoEnviado': en['avisoEnviado'] ?? en['arrivalNotified'] ?? false,
      'avisosEnviados': en['avisosEnviados'] ?? en['arrivalNotices'] ?? 0,
      'anulado': en['anulado'] ?? en['canceled'] ?? false,
      'orden': en['orden'] ?? en['order'] ?? 0,
    };
  }

  Future<int> contarRutasFinalizadas({
    // ⬇️ filtros OBLIGATORIOS de organización
    required String institutionId,
    required String campusId,

    DateTimeRange? rango,
    String? nombreRuta,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection(dailyRoutesCollection)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('estado', isEqualTo: 'finalizada');

    if (nombreRuta != null && nombreRuta.trim().isNotEmpty) {
      q = q.where('nombreRuta', isEqualTo: nombreRuta.trim());
    }
    if (rango != null) {
      q = q
          .where(
            'fecha',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(rango.end));
    }

    final snap = await q.get();
    return snap.docs.length;
  }
}
