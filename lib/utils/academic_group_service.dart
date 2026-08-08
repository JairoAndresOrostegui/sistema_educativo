import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/academic/academic_group.dart';

class AcademicGroupService {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  AcademicGroupService({FirebaseFirestore? db, FirebaseFunctions? functions})
    : _db = db ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  Future<List<AcademicGroup>> list({
    required String institutionId,
    required String campusId,
    bool activeOnly = true,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('academic_groups')
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId);
    if (activeOnly) query = query.where('active', isEqualTo: true);
    final snapshot = await query.get();
    final groups = snapshot.docs.map(AcademicGroup.fromDocument).toList();
    groups.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return groups;
  }

  Future<void> create({
    required String institutionId,
    required String campusId,
    required String level,
    required String section,
    required int order,
  }) async {
    await _functions.httpsCallable('crearGrupoAcademico').call({
      'institutionId': institutionId,
      'campusId': campusId,
      'level': level,
      'section': section,
      'order': order,
    });
  }

  Future<void> update({
    required String id,
    required String level,
    required String section,
    required int order,
    required bool active,
  }) async {
    await _functions.httpsCallable('actualizarGrupoAcademico').call({
      'id': id,
      'level': level,
      'section': section,
      'order': order,
      'active': active,
    });
  }

  Future<void> delete(String id) async {
    await _functions.httpsCallable('eliminarGrupoAcademico').call({'id': id});
  }
}
