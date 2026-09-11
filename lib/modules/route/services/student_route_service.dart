import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/route/daily_route_model.dart';
import 'daily_route_service.dart';

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
    final result = await RouteOperations.call('consultarMiRecorrido', {
      'studentId': studentId,
    });
    if (result['id'] == null) return null;
    final doc = await _firestore.collection(_colDaily).doc(result['id']).get();
    return doc.exists ? RutaDiaria.fromFirestore(doc) : null;
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
