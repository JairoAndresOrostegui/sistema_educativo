import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/enrollment_model.dart';

class EnrollmentService {
  final FirebaseFirestore _db;

  EnrollmentService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('enrollments');

  Future<String> createEnrollment({
    required Map<String, dynamic> data,
    required String estado,
    required String createdByRole,
    String? createdByUserId,
    String? token,
    String? fuente,
    String? vinculaUsuarioId,
    int? anioMatricula,
  }) async {
    final payload = {
      'estado': estado,
      'createdByRole': createdByRole,
      'createdByUserId': createdByUserId,
      'token': token,
      'fuente': fuente,
      'vinculaUsuarioId': vinculaUsuarioId,
      'anioMatricula': anioMatricula,
      'data': data,
      'fechaDiligenciamiento': FieldValue.serverTimestamp(),
      if (estado == 'matriculado')
        'fechaMatricula': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final doc = await _col.add(payload);
    return doc.id;
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
  }) async {
    await _col.doc(id).update({
      'data': data,
      'estado': estado,
      'token': token,
      'anioMatricula': anioMatricula,
      'vinculaUsuarioId': vinculaUsuarioId,
      'revisadoPor': revisadoPor,
      'rechazoMotivo': rechazoMotivo,
      if (estado == 'matriculado') 'fechaMatricula': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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
    final snap = await _col.where('data.numeroIdentidad', isEqualTo: document).limit(1).get();
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

  Future<List<Enrollment>> listByEstado(String estado, {int limit = 50}) async {
    final snap = await _col
        .where('estado', isEqualTo: estado)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(Enrollment.fromDoc).toList();
  }

  Future<List<Enrollment>> listByEstados(List<String> estados, {int limit = 50}) async {
    if (estados.isEmpty) return [];
    final snap = await _col
        .where('estado', whereIn: estados.length > 10 ? estados.sublist(0, 10) : estados)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(Enrollment.fromDoc).toList();
  }

  Future<int> countByEstados(List<String> estados) async {
    if (estados.isEmpty) return 0;
    Query<Map<String, dynamic>> query = _col;
    if (estados.length == 1) {
      query = query.where('estado', isEqualTo: estados.first);
    } else {
      query = query.where('estado', whereIn: estados.length > 10 ? estados.sublist(0, 10) : estados);
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
    Query<Map<String, dynamic>> query = _col.where('createdByUserId', isEqualTo: userId);
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
