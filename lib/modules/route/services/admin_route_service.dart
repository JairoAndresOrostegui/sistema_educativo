import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../models/route/route_model.dart';
import '../../../utils/active_academic_year_context.dart';

class RouteService {
  final _db = FirebaseFirestore.instance;
  Future<List<RouteModel>> obtenerTodasLasRutas({
    required String institutionId,
    required String campusId,
  }) async {
    final year = await loadActiveAcademicYear(
      firestore: _db,
      institutionId: institutionId,
      campusId: campusId,
    );
    final rows = await _db
        .collection('routes')
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .where('academicYearId', isEqualTo: year.id)
        .get();
    return rows.docs.map(RouteModel.fromFirestore).toList();
  }

  Future<void> eliminarRuta(
    String id, {
    required String performedBy,
    required String adminName,
    required String institutionId,
    required String campusId,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('eliminarRutaSegura').call({
      'id': id,
    });
  }

  Future<RouteModel?> obtenerRutaPorId(String id) async {
    final doc = await _db.collection('routes').doc(id).get();
    return doc.exists ? RouteModel.fromFirestore(doc) : null;
  }

  Future<void> guardarRuta({
    String? id,
    required RouteModel ruta,
    required String performedBy,
    required String adminName,
    required String institutionId,
    required String campusId,
  }) async {
    final data = ruta.toMap().map(
      (key, value) => MapEntry(
        key,
        value is Timestamp ? value.millisecondsSinceEpoch : value,
      ),
    );
    await FirebaseFunctions.instance.httpsCallable('guardarRutaSegura').call({
      ...data,
      'id': id,
      'institution': institutionId,
      'campus': campusId,
    });
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
  obtenerEstudiantesDisponibles({
    required String institutionId,
    required String campusId,
  }) async =>
      (await _db
              .collection('users')
              .where('institution', isEqualTo: institutionId)
              .where('campus', isEqualTo: campusId)
              .where('role', isEqualTo: 'Estudiante')
              .where('status', isEqualTo: 'activo')
              .get())
          .docs;
  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
  obtenerGestionadoresDisponibles({
    required String institutionId,
    required String campusId,
  }) async =>
      (await _db
              .collection('users')
              .where('institution', isEqualTo: institutionId)
              .where('campus', isEqualTo: campusId)
              .where('role', whereIn: ['Docente', 'Administrador', 'Auxiliar'])
              .where('status', isEqualTo: 'activo')
              .get())
          .docs;
  Future<List<RouteModel>> getRutasAsignadas({
    required String userId,
    required String institutionId,
    required String campusId,
  }) async {
    final year = await loadActiveAcademicYear(
      firestore: _db,
      institutionId: institutionId,
      campusId: campusId,
    );
    final rows = await _db
        .collection('routes')
        .where('gestionador', isEqualTo: userId)
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .where('academicYearId', isEqualTo: year.id)
        .get();
    return rows.docs.map(RouteModel.fromFirestore).toList();
  }
}
