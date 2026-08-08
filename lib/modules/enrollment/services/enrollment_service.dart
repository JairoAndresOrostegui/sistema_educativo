import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/enrollment_model.dart';

class EnrollmentService {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  EnrollmentService({FirebaseFirestore? db, FirebaseFunctions? functions})
    : _db = db ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('enrollments');

  Future<String> createEnrollment({
    required Map<String, dynamic> data,
    required String estado,
    required String institution,
    required String campus,
    String? token,
    String? vinculaUsuarioId,
    int? anioMatricula,
  }) async {
    final result = await _functions.httpsCallable('crearMatricula').call({
      'data': data,
      'institution': institution.trim(),
      'campus': campus.trim(),
      'token': token,
      'vinculaUsuarioId': vinculaUsuarioId,
      'anioMatricula': anioMatricula,
      'matricularAhora': estado == 'matriculado',
    });
    final response = Map<String, dynamic>.from(result.data as Map);
    return response['id']?.toString() ?? '';
  }

  Future<void> updateEnrollment({
    required String id,
    required Map<String, dynamic> data,
    required String estado,
    String? revisadoPor,
    String? rechazoMotivo,
    String? token,
    int? anioMatricula,
    String? vinculaUsuarioId,
    String? institution,
    String? campus,
  }) async {
    final action = switch (estado) {
      'matriculado' => 'approve',
      'rechazado' => 'reject',
      'desmatriculado' => 'withdraw',
      _ => 'save_review',
    };
    await transitionEnrollment(
      id: id,
      action: action,
      data: data,
      observation: rechazoMotivo,
      linkedStudentId: vinculaUsuarioId,
    );
  }

  Future<void> transitionEnrollment({
    required String id,
    required String action,
    Map<String, dynamic>? data,
    String? observation,
    String? linkedStudentId,
  }) async {
    await _functions.httpsCallable('actualizarMatricula').call({
      'id': id,
      'action': action,
      'data': data,
      'observation': observation,
      'vinculaUsuarioId': linkedStudentId,
    });
  }

  Future<Enrollment?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Enrollment.fromDoc(doc);
  }

  Future<Enrollment?> getByToken(String token) async {
    final snap = await _col.where('token', isEqualTo: token).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return Enrollment.fromDoc(snap.docs.first);
  }

  Future<Enrollment?> getByDocument(String document) async {
    final snap = await _col
        .where('data.numeroIdentidad', isEqualTo: document)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Enrollment.fromDoc(snap.docs.first);
  }

  Future<bool> existsByDocumentAndYear({
    required String document,
    required int anioMatricula,
  }) async {
    final snap = await _col
        .where('data.numeroIdentidad', isEqualTo: document)
        .where('anioMatricula', isEqualTo: anioMatricula)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<List<Enrollment>> listFinalizedByDocumentBeforeYear({
    required String document,
    required int anioMatricula,
  }) async {
    final snap = await _col
        .where('data.numeroIdentidad', isEqualTo: document)
        .where('anioMatricula', isLessThan: anioMatricula)
        .where('estado', whereIn: ['matriculado', 'finalizado'])
        .orderBy('anioMatricula')
        .get();
    return snap.docs.map(Enrollment.fromDoc).toList();
  }

  Future<List<Enrollment>> listByEstado(
    String estado, {
    int limit = 50,
    String? institution,
    String? campus,
    String? groupId,
  }) async {
    Query<Map<String, dynamic>> query = _col.where('estado', isEqualTo: estado);
    if (institution != null && institution.isNotEmpty) {
      query = query.where('institution', isEqualTo: institution);
    }
    if (campus != null && campus.isNotEmpty) {
      query = query.where('campus', isEqualTo: campus);
    }
    if (groupId != null && groupId.isNotEmpty) {
      query = query.where('data.groupId', isEqualTo: groupId);
    }
    final snap = await query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(Enrollment.fromDoc).toList();
  }

  Future<List<Enrollment>> listByEstados(
    List<String> estados, {
    int limit = 50,
    String? institution,
    String? campus,
    String? groupId,
  }) async {
    if (estados.isEmpty) return [];
    Query<Map<String, dynamic>> query = _col.where(
      'estado',
      whereIn: estados.length > 10 ? estados.sublist(0, 10) : estados,
    );
    if ((institution ?? '').isNotEmpty) {
      query = query.where('institution', isEqualTo: institution);
    }
    if ((campus ?? '').isNotEmpty) {
      query = query.where('campus', isEqualTo: campus);
    }
    if ((groupId ?? '').isNotEmpty) {
      query = query.where('data.groupId', isEqualTo: groupId);
    }
    final snap = await query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(Enrollment.fromDoc).toList();
  }

  Future<int> countByEstados(
    List<String> estados, {
    String? institution,
    String? campus,
    String? groupId,
  }) async {
    if (estados.isEmpty) return 0;
    Query<Map<String, dynamic>> query = _col;
    if (estados.length == 1) {
      query = query.where('estado', isEqualTo: estados.first);
    } else {
      query = query.where(
        'estado',
        whereIn: estados.length > 10 ? estados.sublist(0, 10) : estados,
      );
    }
    if ((institution ?? '').isNotEmpty) {
      query = query.where('institution', isEqualTo: institution);
    }
    if ((campus ?? '').isNotEmpty) {
      query = query.where('campus', isEqualTo: campus);
    }
    if ((groupId ?? '').isNotEmpty) {
      query = query.where('data.groupId', isEqualTo: groupId);
    }
    final snap = await query.get();
    return snap.size;
  }

  Future<bool> hasEnrollmentForUser({
    required String userId,
    required List<String> estados,
    int? anioMatricula,
  }) async {
    if (estados.isEmpty) return false;
    Query<Map<String, dynamic>> query = _col.where(
      'createdByUserId',
      isEqualTo: userId,
    );
    if (anioMatricula != null) {
      query = query.where('anioMatricula', isEqualTo: anioMatricula);
    }
    if (estados.length == 1) {
      query = query.where('estado', isEqualTo: estados.first);
    } else {
      query = query.where(
        'estado',
        whereIn: estados.length > 10 ? estados.sublist(0, 10) : estados,
      );
    }
    final snap = await query.limit(1).get();
    return snap.docs.isNotEmpty;
  }
}
