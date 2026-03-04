import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parameter_entry.dart';

class ParameterAdminService {
  final FirebaseFirestore _db;

  ParameterAdminService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('parameters');

  Future<List<ParameterEntry>> list({String? clave}) async {
    Query<Map<String, dynamic>> query = _col;
    if (clave != null && clave.isNotEmpty) {
      query = query.where('clave', isEqualTo: clave);
    }
    final snap = await query.orderBy('clave').orderBy('orden').limit(500).get();
    return snap.docs.map(ParameterEntry.fromDoc).where((p) => p.clave != 'grade').toList();
  }

  Future<List<String>> listClaves() async {
    final snap = await _col.orderBy('clave').limit(200).get();
    final claves = <String>{};
    for (final doc in snap.docs) {
      final c = doc.data()['clave'];
      if (c is String && c != 'grade') {
        claves.add(c);
      }
    }
    return claves.toList()..sort();
  }

  Future<ParameterEntry> create({
    required String clave,
    required String etiqueta,
    required String valor,
    required int orden,
    required bool activo,
  }) async {
    if (clave == 'grade') {
      throw Exception('La clave "grade" no es editable.');
    }
    final payload = {
      'clave': clave,
      'etiqueta': etiqueta,
      'valor': valor,
      'orden': orden,
      'activo': activo,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final doc = await _col.add(payload);
    final saved = await doc.get();
    return ParameterEntry.fromDoc(saved);
  }

  Future<void> update({
    required String id,
    required String etiqueta,
    required String valor,
    required int orden,
    required bool activo,
  }) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return;
    final data = doc.data();
    if (data != null && data['clave'] == 'grade') {
      throw Exception('La clave "grade" no es editable.');
    }
    await _col.doc(id).update({
      'etiqueta': etiqueta,
      'valor': valor,
      'orden': orden,
      'activo': activo,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return;
    final data = doc.data();
    if (data != null && data['clave'] == 'grade') {
      throw Exception('La clave "grade" no es editable.');
    }
    await _col.doc(id).delete();
  }
}
