import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'history_query_utils.dart';

class ScheduleHistoryPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  const ScheduleHistoryPage({
    required this.items,
    required this.hasNext,
    required this.lastDoc,
  });
}

class AdminScheduleHistoryService {
  final FirebaseFirestore _db;

  AdminScheduleHistoryService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  Map<String, dynamic> _subject(Map<String, dynamic> data) {
    final raw = data['after'] ?? data['before'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  bool _matches(
    Map<String, dynamic> data, {
    String? groupContains,
    String? subjectContains,
    String? day,
  }) {
    final subject = _subject(data);
    final groupName = (data['groupName'] ?? subject['groupName'] ?? '')
        .toString()
        .toLowerCase();
    final subjectName = (subject['subject'] ?? '').toString().toLowerCase();
    final expectedGroup = groupContains?.trim().toLowerCase() ?? '';
    final expectedSubject = subjectContains?.trim().toLowerCase() ?? '';
    final expectedDay = day?.trim().toLowerCase() ?? '';
    return (expectedGroup.isEmpty || groupName.contains(expectedGroup)) &&
        (expectedSubject.isEmpty || subjectName.contains(expectedSubject)) &&
        (expectedDay.isEmpty ||
            (subject['day'] ?? '').toString().toLowerCase() == expectedDay);
  }

  Query<Map<String, dynamic>> _query({
    required String institutionId,
    required String campusId,
    String? action,
    DateTimeRange? rango,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection('schedule_history')
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId);
    if (action != null && action.isNotEmpty) {
      query = query.where('action', isEqualTo: action);
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

  Future<ScheduleHistoryPage> obtenerHistorialHorarios({
    required String institutionId,
    required String campusId,
    String? groupContains,
    String? subjectContains,
    String? day,
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
    final page = await scanFilteredPage(
      query: query,
      pageSize: limite,
      startAfter: startAfter,
      matches: (data) => _matches(
        data,
        groupContains: groupContains,
        subjectContains: subjectContains,
        day: day,
      ),
    );
    final items = <Map<String, dynamic>>[];
    for (final document in page.documents) {
      final data = document.data();
      final subject = _subject(data);
      final groupName = (data['groupName'] ?? subject['groupName'] ?? '')
          .toString();
      final subjectName = (subject['subject'] ?? '').toString();
      items.add({
        'id': document.id,
        'grupo': groupName,
        'groupId': data['groupId'] ?? subject['groupId'] ?? '',
        'materia': subjectName,
        'dia': subject['day'] ?? '',
        'accion': data['action'] ?? '',
        'usuarioNombre': data['performedBy'] ?? '',
        'fecha': historyDate(data['createdAt']),
      });
    }
    return ScheduleHistoryPage(
      items: items,
      hasNext: page.hasNext,
      lastDoc: page.lastDoc,
    );
  }

  Future<int> contarTotal({
    required String institutionId,
    required String campusId,
    String? action,
    String? day,
    DateTimeRange? rango,
    String? groupContains,
    String? subjectContains,
  }) async {
    final query = _query(
      institutionId: institutionId,
      campusId: campusId,
      action: action,
      rango: rango,
    );
    final hasLocalFilters = [
      groupContains,
      subjectContains,
      day,
    ].any((value) => value != null && value.trim().isNotEmpty);
    if (!hasLocalFilters) return (await query.count().get()).count ?? 0;
    return countFilteredDocuments(
      query: query.orderBy('createdAt', descending: true),
      matches: (data) => _matches(
        data,
        groupContains: groupContains,
        subjectContains: subjectContains,
        day: day,
      ),
    );
  }
}
