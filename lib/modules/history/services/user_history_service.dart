import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserHistoryPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  const UserHistoryPage({
    required this.items,
    required this.hasNext,
    required this.lastDoc,
  });
}

class AdminUserHistoryService {
  final FirebaseFirestore _db;

  AdminUserHistoryService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  Query<Map<String, dynamic>> _query({
    String? role,
    String? action,
    DateTimeRange? rango,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('user_history');
    if (role != null && role.trim().isNotEmpty) {
      query = query.where('rol', isEqualTo: role.trim());
    }
    if (action != null && action.trim().isNotEmpty) {
      query = query.where('accion', isEqualTo: action.trim());
    }
    if (rango != null) {
      query = query
          .where(
            'fecha',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(rango.end));
    }
    return query;
  }

  Future<UserHistoryPage> obtenerHistorial({
    String? nameContains,
    String? role,
    String? action,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    var query = _query(
      role: role,
      action: action,
      rango: rango,
    ).orderBy('fecha', descending: true).limit(limite);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snapshot = await query.get();
    final needle = nameContains?.trim().toLowerCase() ?? '';
    final items = snapshot.docs
        .map((document) {
          final data = document.data();
          return <String, dynamic>{
            'id': document.id,
            'accion': (data['accion'] ?? '').toString(),
            'nombres': (data['nombres'] ?? '').toString(),
            'apellidos': (data['apellidos'] ?? '').toString(),
            'rol': (data['rol'] ?? '').toString(),
            'realizadoPor': (data['realizadoPor'] ?? '').toString(),
            'fecha': (data['fecha'] as Timestamp?)?.toDate(),
            'campus': (data['campus'] ?? '').toString(),
            'institution': (data['institution'] ?? '').toString(),
            'usuarioId': (data['usuarioId'] ?? '').toString(),
          };
        })
        .where((item) {
          if (needle.isEmpty) return true;
          return '${item['nombres']} ${item['apellidos']}'
              .toLowerCase()
              .contains(needle);
        })
        .toList();
    return UserHistoryPage(
      items: items,
      hasNext: snapshot.docs.length == limite,
      lastDoc: snapshot.docs.isEmpty ? null : snapshot.docs.last,
    );
  }

  Future<int> contarTotal({
    String? role,
    String? action,
    DateTimeRange? rango,
    String? nameContains,
  }) async {
    final aggregate = await _query(
      role: role,
      action: action,
      rango: rango,
    ).count().get();
    return aggregate.count ?? 0;
  }
}
