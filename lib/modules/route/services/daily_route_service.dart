import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../models/route/daily_route_model.dart';
import '../../../models/route/student_route_model.dart';
import '../../../models/user/user_model_v2.dart';

class RutaDiariaService {
  final FirebaseFirestore _firestore;
  final userModelv2 _currentUser;

  RutaDiariaService({
    FirebaseFirestore? firestore,
    required userModelv2 currentUser,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUser = currentUser;

  static const String _colDailyRoutes = 'daily_routes';
  static const String _colUsers = 'users';
  static const String _subStudents = 'students';

  String _generateRutaDiaId(String routeId) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${routeId}_$today';
  }

  Future<RutaDiaria?> getRutaDia(String routeId) async {
    final idRutaDia = _generateRutaDiaId(routeId);
    final doc =
        await _firestore.collection(_colDailyRoutes).doc(idRutaDia).get();
    return doc.exists ? RutaDiaria.fromFirestore(doc) : null;
  }

  Future<List<EstudianteRutaDiaria>> getEstudiantesRutaDia(
    String dailyRouteId,
  ) async {
    final snap =
        await _firestore
            .collection(_colDailyRoutes)
            .doc(dailyRouteId)
            .collection(_subStudents)
            .get();

    final list =
        snap.docs.map((d) => EstudianteRutaDiaria.fromFirestore(d)).toList();
    list.sort((a, b) => (a.orden ?? 0).compareTo(b.orden ?? 0));
    return list;
  }

  Future<RutaDiaria> createRutaDia({
    required String rutaId,
    required String nombreRuta,
    required List<String> estudiantesIds,
  }) async {
    final dailyId = _generateRutaDiaId(rutaId);
    final dailyRef = _firestore.collection(_colDailyRoutes).doc(dailyId);

    final teacherName =
        '${(_currentUser.firstName).toString().trim()} ${(_currentUser.lastName).toString().trim()}'
            .trim();

    final inst = _currentUser.institution;
    final camp = _currentUser.campus;

    final usersCol = _firestore.collection(_colUsers);
    final List<Map<String, dynamic>> studentsPayload = [];

    for (int i = 0; i < estudiantesIds.length; i++) {
      final sid = estudiantesIds[i];
      final sdoc = await usersCol.doc(sid).get();
      if (!sdoc.exists) continue;

      final sd = sdoc.data()!;
      final fullName =
          '${(sd['firstName'] ?? '').toString().trim()} ${(sd['lastName'] ?? '').toString().trim()}'
              .trim();
      final address =
          (sd['routeAddress'] ?? sd['direccionRuta'] ?? '').toString();

      studentsPayload.add({
        'id': sid,
        'nombre': fullName,
        'direccion': address,
        'activo': true,
        'recogido': false,
        'horaRecogida': null,
        'avisoEnviado': false,
        'avisosEnviados': 0,
        'anulado': false,
        'orden': i,
        'institution': inst,
        'campus': camp,
      });
    }

    await dailyRef.set({
      'idRuta': rutaId,
      'nombreRuta': nombreRuta,
      'fecha': Timestamp.now(),
      'gestionador': _currentUser.id,
      'gestionadaPorNombre': teacherName,
      'estado': 'pendiente',
      'horaInicio': null,
      'horaFin': null,
      'institution': inst,
      'campus': camp,
    });

    for (final st in studentsPayload) {
      final sid = st['id'] as String;
      await dailyRef.collection(_subStudents).doc(sid).set(st);
    }

    final created = await dailyRef.get();
    return RutaDiaria.fromFirestore(created);
  }

  Future<void> updateEstudianteRutaDiaria(
    String dailyRouteId,
    String studentId,
    Map<String, dynamic> data,
  ) async {
    final ref = _firestore
        .collection(_colDailyRoutes)
        .doc(dailyRouteId)
        .collection(_subStudents)
        .doc(studentId);

    await ref.update(data);
  }

  Future<void> updateRutaDiaria(
    String dailyRouteId,
    Map<String, dynamic> data,
  ) async {
    final ref = _firestore.collection(_colDailyRoutes).doc(dailyRouteId);
    await ref.update(data);
  }

  Future<void> updateStudentAddress(String studentId, String newAddress) async {
    await _firestore.collection(_colUsers).doc(studentId).update({
      'routeAddress': newAddress,
      'direccionRuta': newAddress,
    });
  }
}
