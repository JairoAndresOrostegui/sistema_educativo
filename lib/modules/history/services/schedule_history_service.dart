import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final _db = FirebaseFirestore.instance;

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
    Query<Map<String, dynamic>> query = _db
        .collection('schedule_history')
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId);
    if (action != null && action.isNotEmpty) {
      query = query.where('action', isEqualTo: action);
    }
    if (day != null && day.isNotEmpty) {
      query = query.where('after.day', isEqualTo: day);
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
    query = query.orderBy('createdAt', descending: true).limit(limite);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snapshot = await query.get();
    final items = <Map<String, dynamic>>[];
    for (final document in snapshot.docs) {
      final data = document.data();
      final subject = Map<String, dynamic>.from(
        (data['after'] ?? data['before'] ?? const {}) as Map,
      );
      final groupName = (data['groupName'] ?? subject['groupName'] ?? '')
          .toString();
      final subjectName = (subject['subject'] ?? '').toString();
      if (groupContains != null &&
          !groupName.toLowerCase().contains(groupContains.toLowerCase())) {
        continue;
      }
      if (subjectContains != null &&
          !subjectName.toLowerCase().contains(subjectContains.toLowerCase())) {
        continue;
      }
      items.add({
        'id': document.id,
        'grupo': groupName,
        'groupId': data['groupId'] ?? subject['groupId'] ?? '',
        'materia': subjectName,
        'dia': subject['day'] ?? '',
        'accion': data['action'] ?? '',
        'usuarioNombre': data['performedBy'] ?? '',
        'fecha': (data['createdAt'] as Timestamp?)?.toDate(),
      });
    }
    return ScheduleHistoryPage(
      items: items,
      hasNext: snapshot.docs.length == limite,
      lastDoc: snapshot.docs.isEmpty ? null : snapshot.docs.last,
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
    final page = await obtenerHistorialHorarios(
      institutionId: institutionId,
      campusId: campusId,
      groupContains: groupContains,
      subjectContains: subjectContains,
      day: day,
      action: action,
      rango: rango,
      limite: 1000,
    );
    return page.items.length;
  }
}
