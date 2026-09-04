import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/academic/academic_group.dart';
import '../../../utils/academic_group_service.dart';

class DocumentPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  const DocumentPage({
    required this.items,
    required this.hasNext,
    required this.lastDoc,
  });
}

class DocumentHistoryService {
  final FirebaseFirestore _db;
  final AcademicGroupService _groups;

  DocumentHistoryService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance,
      _groups = AcademicGroupService(db: db);

  Future<DocumentPage> obtenerHistorialDocumentos({
    required String institutionId,
    required String campusId,
    String? groupId,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _baseQuery(
      institutionId,
      campusId,
      groupId,
      rango,
    );
    query = query.orderBy('createdAt', descending: true).limit(limite);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snapshot = await query.get();
    final items = snapshot.docs.map((document) {
      final data = document.data();
      return <String, dynamic>{
        'id': document.id,
        'nombre': data['name'] ?? '',
        'grupo': data['groupName'] ?? '',
        'groupId': data['groupId'] ?? '',
        'subidoPor': data['uploaderName'] ?? data['uploadedBy'] ?? '',
        'fechaSubida': (data['createdAt'] as Timestamp?)?.toDate(),
        'storagePath': data['storagePath'],
        'sizeBytes': data['sizeBytes'] ?? 0,
      };
    }).toList();
    return DocumentPage(
      items: items,
      hasNext: snapshot.docs.length == limite,
      lastDoc: snapshot.docs.isEmpty ? null : snapshot.docs.last,
    );
  }

  Query<Map<String, dynamic>> _baseQuery(
    String institutionId,
    String campusId,
    String? groupId,
    DateTimeRange? rango,
  ) {
    Query<Map<String, dynamic>> query = _db
        .collection('files')
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('status', isEqualTo: 'active');
    if (groupId != null && groupId.isNotEmpty) {
      query = query.where('groupId', isEqualTo: groupId);
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

  Future<List<AcademicGroup>> obtenerGrupos({
    required String institutionId,
    required String campusId,
  }) => _groups.list(
    institutionId: institutionId,
    campusId: campusId,
    activeOnly: false,
  );

  Future<int> contarTotalDocumentos({
    required String institutionId,
    required String campusId,
    String? groupId,
    DateTimeRange? rango,
  }) async {
    final query = _baseQuery(institutionId, campusId, groupId, rango);
    return (await query.count().get()).count ?? 0;
  }
}
