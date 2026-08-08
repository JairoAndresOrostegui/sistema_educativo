import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../models/route/route_model.dart';

class RouteService {
  final _routes = FirebaseFirestore.instance.collection('routes');
  final _users = FirebaseFirestore.instance.collection('users');

  Future<List<RouteModel>> obtenerTodasLasRutas({
    required String institutionId,
    required String campusId,
  }) async {
    final q = _routes
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId);
    final query = await q.get();
    return query.docs.map((doc) => RouteModel.fromFirestore(doc)).toList();
  }

  Future<void> eliminarRuta(
    String id, {
    required String performedBy,
    required String adminName,
    required String institutionId,
    required String campusId,
  }) async {
    final ruta = await obtenerRutaPorId(id);
    await _routes.doc(id).delete();
    if (ruta != null) {
      await registrarHistorialRuta(
        ruta: ruta,
        accion: 'eliminado',
        performedBy: performedBy,
        adminName: adminName,
        institutionId: institutionId,
        campusId: campusId,
      );
    }
  }

  Future<RouteModel?> obtenerRutaPorId(String id) async {
    final doc = await _routes.doc(id).get();
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
    final data = ruta.toMap()
      ..addAll({'institution': institutionId, 'campus': campusId});

    if (id == null) {
      final docRef = await _routes.add(data);
      final nuevaRuta = ruta.copyWithId(docRef.id);
      await registrarHistorialRuta(
        ruta: nuevaRuta,
        accion: 'creado',
        performedBy: performedBy,
        adminName: adminName,
        institutionId: institutionId,
        campusId: campusId,
      );
    } else {
      final anterior = await obtenerRutaPorId(id);
      await _routes.doc(id).update(data);
      final actualizada = ruta.copyWithId(id);

      if (anterioresNoNulos(anterior)) {
        final cambios = _compararRutas(anterior!, actualizada);
        if (cambios.isNotEmpty) {
          await registrarHistorialRuta(
            ruta: actualizada,
            accion: 'editado',
            performedBy: performedBy,
            adminName: adminName,
            institutionId: institutionId,
            campusId: campusId,
            cambios: cambios,
          );
        }
      }
    }
  }

  bool anterioresNoNulos(RouteModel? r) => r != null;

  Map<String, dynamic> _compararRutas(RouteModel antes, RouteModel despues) {
    final cambios = <String, dynamic>{};
    if (antes.name != despues.name) {
      cambios['name'] = '${antes.name} ➝ ${despues.name}';
    }
    if (antes.startAddress != despues.startAddress) {
      cambios['startAddress'] =
          '${antes.startAddress} ➝ ${despues.startAddress}';
    }
    if (antes.startDate != despues.startDate) {
      cambios['startDate'] = '${antes.startDate} ➝ ${despues.startDate}';
    }
    if (antes.endDate != despues.endDate) {
      cambios['endDate'] = '${antes.endDate} ➝ ${despues.endDate}';
    }
    if (antes.startTime != despues.startTime) {
      cambios['startTime'] = '${antes.startTime} ➝ ${despues.startTime}';
    }
    if (antes.endTime != despues.endTime) {
      cambios['endTime'] = '${antes.endTime} ➝ ${despues.endTime}';
    }
    if (antes.manager != despues.manager) {
      cambios['manager'] = '${antes.manager} ➝ ${despues.manager}';
    }
    if (antes.students.toString() != despues.students.toString()) {
      cambios['students'] = 'Modified';
    }
    return cambios;
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
  obtenerEstudiantesDisponibles({
    required String institutionId,
    required String campusId,
  }) async {
    final snapshot = await _users
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .where('role', isEqualTo: 'Estudiante')
        .where('status', isEqualTo: 'activo')
        .get();
    return snapshot.docs;
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
  obtenerGestionadoresDisponibles({
    required String institutionId,
    required String campusId,
  }) async {
    final snapshot = await _users
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .where('role', whereIn: ['Docente', 'Administrador'])
        .where('status', isEqualTo: 'activo')
        .get();
    return snapshot.docs;
  }

  Future<List<RouteModel>> getRutasAsignadas({
    required String userId,
    required String institutionId,
    required String campusId,
  }) async {
    Query<Map<String, dynamic>> q1 = _routes
        .where('gestionador', isEqualTo: userId)
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId);
    final snapEs = await q1.get();

    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = snapEs.docs;
    if (allDocs.isEmpty) {
      final q2 = _routes
          .where('manager', isEqualTo: userId)
          .where('institution', isEqualTo: institutionId)
          .where('campus', isEqualTo: campusId);
      final snapEn = await q2.get();
      allDocs = snapEn.docs;
    }

    return allDocs.map((doc) => RouteModel.fromFirestore(doc)).toList();
  }

  Future<void> registrarHistorialRuta({
    required RouteModel ruta,
    required String accion,
    required String performedBy,
    required String adminName,
    required String institutionId,
    required String campusId,
    Map<String, dynamic>? cambios,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'registrarAuditoria',
    );
    await callable.call({
      'type': 'route_history',
      'payload': {
        'routeId': ruta.id,
        'routeName': ruta.name,
        'action': _mapActionToEnglish(accion),
        'changes': ?cambios,
      },
    });
  }

  String _mapActionToEnglish(String accion) {
    switch (accion) {
      case 'creado':
        return 'created';
      case 'editado':
        return 'edited';
      case 'eliminado':
        return 'deleted';
      default:
        return accion;
    }
  }
}
