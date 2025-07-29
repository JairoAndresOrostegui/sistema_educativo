import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_route_model.dart';

class MyRouteService {
  final FirebaseFirestore _firestore;

  MyRouteService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<RutaDiaria?> getMyDailyRoute(String userId) async {
    final hoyUtc = DateTime.now().toUtc();

    final inicioDelDiaUtc = DateTime.utc(
      hoyUtc.year,
      hoyUtc.month,
      hoyUtc.day,
      0,
      0,
      0,
    );

    final finDelDiaUtc = DateTime.utc(
      hoyUtc.year,
      hoyUtc.month,
      hoyUtc.day,
      23,
      59,
      59,
      999,
    );

    final inicioTimestamp = Timestamp.fromDate(inicioDelDiaUtc);
    final finTimestamp = Timestamp.fromDate(finDelDiaUtc);

    final querySnapshot =
        await _firestore
            .collection('rutas_diarias')
            .where('fecha', isGreaterThanOrEqualTo: inicioTimestamp)
            .where('fecha', isLessThanOrEqualTo: finTimestamp)
            .where('estado', whereIn: ['activa', 'pendiente', 'finalizada'])
            .get();

    for (final doc in querySnapshot.docs) {
      print('🔍 Verificando ruta: ${doc.id}');
      final studentDoc =
          await _firestore
              .collection('rutas_diarias')
              .doc(doc.id)
              .collection('estudiantes')
              .doc(userId)
              .get();

      if (studentDoc.exists) {
        return RutaDiaria.fromFirestore(doc);
      } else {}
    }

    return null;
  }

  Stream<DocumentSnapshot> streamDailyRoute(String routeId) {
    return _firestore.collection('rutas_diarias').doc(routeId).snapshots();
  }

  Stream<DocumentSnapshot> streamStudentDailyRoute(
    String routeId,
    String studentId,
  ) {
    return _firestore
        .collection('rutas_diarias')
        .doc(routeId)
        .collection('estudiantes')
        .doc(studentId)
        .snapshots();
  }

  Future<DocumentSnapshot?> getStudentDailyRouteDoc(
    String routeId,
    String studentId,
  ) async {
    return _firestore
        .collection('rutas_diarias')
        .doc(routeId)
        .collection('estudiantes')
        .doc(studentId)
        .get();
  }
}
