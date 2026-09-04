import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Query<Map<String, dynamic>> _query({String? action, DateTimeRange? rango}) {
    Query<Map<String, dynamic>> query = _db.collection('routes_admin_history');
    if (action != null && action.trim().isNotEmpty) {
      query = query.where('action', isEqualTo: action.trim());
    }
    if (rango != null) {
      query = query
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(rango.end));
    }
    return query;
  }

  Future<RouteHistoryPage> obtenerHistorialRutasAdmin({
    String? routeNameContains,
    String? action,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    var query = _query(
      action: action,
      rango: rango,
    ).orderBy('date', descending: true).limit(limite);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snapshot = await query.get();
    final needle = routeNameContains?.trim().toLowerCase() ?? '';
    final items = snapshot.docs
        .map((document) {
          final data = document.data();
          return <String, dynamic>{
            'id': document.id,
            'nombreRuta': (data['routeName'] ?? '').toString(),
            'accion': (data['action'] ?? '').toString(),
            'nombreAdmin': (data['adminName'] ?? '').toString(),
            'fecha': (data['date'] as Timestamp?)?.toDate(),
            'detalles': data['details'],
          };
        })
        .where((item) {
          return needle.isEmpty ||
              item['nombreRuta'].toString().toLowerCase().contains(needle);
        })
        .toList();
    return RouteHistoryPage(
      items: items,
      hasNext: snapshot.docs.length == limite,
      lastDoc: snapshot.docs.isEmpty ? null : snapshot.docs.last,
    );
  }

  Future<int> contarTotal({
    String? action,
    DateTimeRange? rango,
    String? routeNameContains,
  }) async {
    final aggregate = await _query(action: action, rango: rango).count().get();
    return aggregate.count ?? 0;
  }
}
