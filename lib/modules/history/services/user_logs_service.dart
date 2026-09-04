import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserLogsPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  UserLogsPage({
    required this.items,
    required this.hasNext,
    required this.lastDoc,
  });
}

class UserLogsService {
  final _db = FirebaseFirestore.instance;

  static const userLogsCollection = 'user_logs';

  /// Página de resultados normalizada
  Future<UserLogsPage> getLogs({
    String? role,
    String? event,
    String? campus,
    String? institution,
    String?
    platform, // filtro local (no hace query si no tienes índice en env.platform)
    String? nameContains, // filtro local (contiene)
    DateTimeRange? rango,
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection(userLogsCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (role != null && role.trim().isNotEmpty) {
      q = q.where('role', isEqualTo: role.trim());
    }
    if (event != null && event.trim().isNotEmpty) {
      q = q.where('event', isEqualTo: event.trim());
    }
    if (campus != null && campus.trim().isNotEmpty) {
      q = q.where('campus', isEqualTo: campus.trim());
    }
    if (institution != null && institution.trim().isNotEmpty) {
      q = q.where('institution', isEqualTo: institution.trim());
    }
    if (rango != null) {
      q = q
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where(
            'timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(rango.end),
          );
    }
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final docs = snap.docs;

    // Normalización + filtros locales
    final items = <Map<String, dynamic>>[];
    for (final d in docs) {
      final data = d.data();
      final ts = (data['timestamp'] as Timestamp?)?.toDate();

      final env = (data['env'] is Map<String, dynamic>)
          ? data['env'] as Map<String, dynamic>
          : <String, dynamic>{};

      final map = {
        'id': d.id,
        'timestamp': ts,
        'event': (data['event'] ?? '').toString(),
        'fullName': (data['fullName'] ?? '').toString(),
        'role': (data['role'] ?? '').toString(),
        'userId': (data['userId'] ?? '').toString(),
        'campus': (data['campus'] ?? '').toString(),
        'institution': (data['institution'] ?? '').toString(),
        'groupId': (data['groupId'] ?? '').toString(),
        'groupName': (data['groupName'] ?? '').toString(),
        // ENV
        'platform': (env['platform'] ?? '').toString(),
        'browserName': (env['browserName'] ?? '').toString(),
        'appVersion': (env['appVersion'] ?? '').toString(),
        'buildNumber': (env['buildNumber'] ?? '').toString(),
        'deviceMemoryGb': env['deviceMemoryGb'],
        'hardwareConcurrency': env['hardwareConcurrency'],
        'userAgent': (env['userAgent'] ?? '').toString(),
      };

      // Filtros locales (no requieren índices)
      if (platform != null &&
          platform.trim().isNotEmpty &&
          map['platform'].toString().toLowerCase() !=
              platform.trim().toLowerCase()) {
        continue;
      }
      if (nameContains != null &&
          nameContains.trim().isNotEmpty &&
          !map['fullName'].toString().toLowerCase().contains(
            nameContains.trim().toLowerCase(),
          )) {
        continue;
      }

      items.add(map);
    }

    final hasNext = docs.length == limit;
    final lastDoc = docs.isNotEmpty ? docs.last : null;

    return UserLogsPage(items: items, hasNext: hasNext, lastDoc: lastDoc);
  }

  /// Conteo aproximado con los filtros que sí son indexables (no incluye contains)
  Future<int> countLogs({
    String? role,
    String? event,
    String? campus,
    String? institution,
    DateTimeRange? rango,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection(userLogsCollection);

    if (role != null && role.trim().isNotEmpty) {
      q = q.where('role', isEqualTo: role.trim());
    }
    if (event != null && event.trim().isNotEmpty) {
      q = q.where('event', isEqualTo: event.trim());
    }
    if (campus != null && campus.trim().isNotEmpty) {
      q = q.where('campus', isEqualTo: campus.trim());
    }
    if (institution != null && institution.trim().isNotEmpty) {
      q = q.where('institution', isEqualTo: institution.trim());
    }
    if (rango != null) {
      q = q
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where(
            'timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(rango.end),
          );
    }

    // Si tu SDK soporta agregaciones: usa q.count().get()
    final snap = await q.get();
    return snap.docs.length;
  }
}
