import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'history_query_utils.dart';

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
    required String institutionId,
    required String campusId,
    String? role,
    String? action,
    DateTimeRange? rango,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection('user_history')
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId);
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
    required String institutionId,
    required String campusId,
    String? nameContains,
    String? role,
    String? action,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final query = _query(
      institutionId: institutionId,
      campusId: campusId,
      role: role,
      action: action,
      rango: rango,
    ).orderBy('fecha', descending: true);
    final needle = nameContains?.trim().toLowerCase() ?? '';
    final page = await scanFilteredPage(
      query: query,
      pageSize: limite,
      startAfter: startAfter,
      matches: (data) =>
          needle.isEmpty ||
          '${data['nombres'] ?? ''} ${data['apellidos'] ?? ''} '
                  '${data['rol'] ?? ''} ${data['accion'] ?? ''} '
                  '${data['realizadoPor'] ?? ''}'
              .toLowerCase()
              .contains(needle),
    );
    final items = page.documents.map((document) {
      final data = document.data();
      return <String, dynamic>{
        'id': document.id,
        'accion': (data['accion'] ?? '').toString(),
        'nombres': (data['nombres'] ?? '').toString(),
        'apellidos': (data['apellidos'] ?? '').toString(),
        'rol': (data['rol'] ?? '').toString(),
        'realizadoPor': (data['realizadoPor'] ?? '').toString(),
        'fecha': historyDate(data['fecha']),
        'campus': (data['campus'] ?? '').toString(),
        'institution': (data['institution'] ?? '').toString(),
        'usuarioId': (data['usuarioId'] ?? '').toString(),
      };
    }).toList();
    return UserHistoryPage(
      items: items,
      hasNext: page.hasNext,
      lastDoc: page.lastDoc,
    );
  }

  Future<int> contarTotal({
    required String institutionId,
    required String campusId,
    String? role,
    String? action,
    DateTimeRange? rango,
    String? nameContains,
  }) async {
    final query = _query(
      institutionId: institutionId,
      campusId: campusId,
      role: role,
      action: action,
      rango: rango,
    );
    final needle = nameContains?.trim().toLowerCase() ?? '';
    if (needle.isEmpty) return (await query.count().get()).count ?? 0;
    return countFilteredDocuments(
      query: query.orderBy('fecha', descending: true),
      matches: (data) =>
          '${data['nombres'] ?? ''} ${data['apellidos'] ?? ''} '
                  '${data['rol'] ?? ''} ${data['accion'] ?? ''} '
                  '${data['realizadoPor'] ?? ''}'
              .toLowerCase()
              .contains(needle),
    );
  }
}
