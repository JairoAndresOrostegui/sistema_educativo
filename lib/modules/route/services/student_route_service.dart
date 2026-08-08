import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/route/daily_route_model.dart';

class MyRouteService {
  final FirebaseFirestore _firestore;
  MyRouteService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _colDaily = 'daily_routes';
  static const String _subStudents = 'students';

  Future<RutaDiaria?> getMyDailyRoute({
    required String studentId,
    required String institutionId,
    required String campusId,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final byTenant = await _firestore
        .collection(_colDaily)
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .get();

    final todaysDocs = byTenant.docs.where((d) {
      final ts = d.data()['fecha'];
      if (ts is! Timestamp) return false;
      final dt = ts.toDate();
      return (dt.isAfter(start) || dt.isAtSameMomentAs(start)) &&
          (dt.isBefore(end) || dt.isAtSameMomentAs(end));
    });

    for (final doc in todaysDocs) {
      final exists = await _firestore
          .collection(_colDaily)
          .doc(doc.id)
          .collection(_subStudents)
          .doc(studentId)
          .get();

      if (exists.exists) {
        return RutaDiaria.fromFirestore(doc);
      }
    }
    return null;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDailyRoute(
    String routeId,
  ) {
    return _firestore.collection(_colDaily).doc(routeId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamStudentDailyRoute(
    String routeId,
    String studentId,
  ) {
    return _firestore
        .collection(_colDaily)
        .doc(routeId)
        .collection(_subStudents)
        .doc(studentId)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getStudentDailyRouteDoc(
    String routeId,
    String studentId,
  ) async {
    final doc = await _firestore
        .collection(_colDaily)
        .doc(routeId)
        .collection(_subStudents)
        .doc(studentId)
        .get();
    return doc.exists ? doc : null;
  }
}
