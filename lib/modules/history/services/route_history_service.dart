import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'history_query_utils.dart';

class RouteHistoryPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  const RouteHistoryPage({
    required this.items,
    required this.hasNext,
    required this.lastDoc,
  });
}

class AdminRouteHistoryService {
  final FirebaseFirestore _db;

  AdminRouteHistoryService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  Query<Map<String, dynamic>> _query({
    required String institutionId,
    required String campusId,
    String? action,
    DateTimeRange? rango,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection('route_history')
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId);
    if (action != null && action.trim().isNotEmpty) {
      query = query.where('action', isEqualTo: action.trim());
    }
    if (rango != null) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(rango.end),
          );
    }
    return query;
  }

  Future<RouteHistoryPage> obtenerHistorialRutasAdmin({
    required String institutionId,
    required String campusId,
    String? routeNameContains,
    String? action,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final query = _query(
      institutionId: institutionId,
      campusId: campusId,
      action: action,
      rango: rango,
    ).orderBy('createdAt', descending: true);
    final needle = routeNameContains?.trim().toLowerCase() ?? '';
    final page = await scanFilteredPage(
      query: query,
      pageSize: limite,
      startAfter: startAfter,
      matches: (data) =>
          needle.isEmpty ||
          (data['routeName'] ?? '').toString().toLowerCase().contains(needle),
    );
    final items = page.documents.map((document) {
      final data = document.data();
      return <String, dynamic>{
        'id': document.id,
        'nombreRuta': (data['routeName'] ?? '').toString(),
        'accion': (data['action'] ?? '').toString(),
        'nombreAdmin':
            (data['performedByName'] ??
                    data['adminName'] ??
                    data['performedBy'] ??
                    '')
                .toString(),
        'fecha': historyDate(data['createdAt']) ?? historyDate(data['date']),
        'detalles':
            data['changes'] ??
            <String, dynamic>{
              if (data.containsKey('before')) 'antes': data['before'],
              if (data.containsKey('after')) 'después': data['after'],
            },
      };
    }).toList();
    return RouteHistoryPage(
      items: items,
      hasNext: page.hasNext,
      lastDoc: page.lastDoc,
    );
  }

  Future<int> contarTotal({
    required String institutionId,
    required String campusId,
    String? action,
    DateTimeRange? rango,
    String? routeNameContains,
  }) async {
    final query = _query(
      institutionId: institutionId,
      campusId: campusId,
      action: action,
      rango: rango,
    );
    final needle = routeNameContains?.trim().toLowerCase() ?? '';
    if (needle.isEmpty) return (await query.count().get()).count ?? 0;
    return countFilteredDocuments(
      query: query.orderBy('createdAt', descending: true),
      matches: (data) =>
          (data['routeName'] ?? '').toString().toLowerCase().contains(needle),
    );
  }
}
