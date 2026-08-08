import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../models/authorization/authorization_request_model.dart';
import '../../../models/user/user_model_v2.dart';

class AuthorizationPage {
  final List<AuthorizationRequest> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  AuthorizationPage({
    required this.items,
    required this.hasNext,
    required this.lastDoc,
  });
}

class ChildRef {
  final String id;
  final String fullName;
  final String groupId;
  final String groupName;
  const ChildRef({
    required this.id,
    required this.fullName,
    required this.groupId,
    required this.groupName,
  });
}

class AuthorizationService {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  static const _col = 'authorization_requests';

  Stream<List<AuthorizationRequest>> watchForStudent({
    required String institutionId,
    required String campusId,
    required String studentId,
    int limit = 20,
  }) {
    return _db
        .collection(_col)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) => _sortedItemsFromSnapshot(snap, limit: limit));
  }

  Stream<List<AuthorizationRequest>> watchForGroup({
    required String institutionId,
    required String campusId,
    required String groupId,
    int limit = 20,
  }) {
    return _db
        .collection(_col)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snap) => _sortedItemsFromSnapshot(snap, limit: limit));
  }

  Stream<List<AuthorizationRequest>> watchForAdmin({
    String? institutionId,
    String? campusId,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(_col);
    if ((institutionId ?? '').isNotEmpty) {
      query = query.where('institutionId', isEqualTo: institutionId);
    }
    if ((campusId ?? '').isNotEmpty) {
      query = query.where('campusId', isEqualTo: campusId);
    }
    return query.snapshots().map(
      (snap) => _sortedItemsFromSnapshot(snap, limit: limit),
    );
  }

  Future<AuthorizationPage> listForStudent({
    required String institutionId,
    required String campusId,
    required String studentId,
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final snap = await _db
        .collection(_col)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('studentId', isEqualTo: studentId)
        .get();

    final items =
        snap.docs
            .map((d) => AuthorizationRequest.fromMap(d.data(), d.id))
            .toList()
          ..sort((a, b) {
            final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });

    return AuthorizationPage(items: items, hasNext: false, lastDoc: null);
  }

  Future<List<ChildRef>> getChildrenForFamily({
    required String institutionId,
    required String campusId,
    required List<String> studentIds,
  }) async {
    if (studentIds.isEmpty) return [];
    final out = <ChildRef>[];
    for (final chunk in _chunks(studentIds, 10)) {
      final snap = await _db
          .collection('user_directory')
          .where(FieldPath.documentId, whereIn: chunk)
          .where('institution', isEqualTo: institutionId)
          .where('campus', isEqualTo: campusId)
          .get();
      for (final d in snap.docs) {
        final m = d.data();
        final fn = (m['firstName'] ?? '').toString();
        final ln = (m['lastName'] ?? '').toString();
        final groupId = (m['groupId'] ?? '').toString();
        final groupName = (m['groupName'] ?? '').toString();
        out.add(
          ChildRef(
            id: d.id,
            fullName: '$fn $ln'.trim(),
            groupId: groupId,
            groupName: groupName,
          ),
        );
      }
    }
    out.sort((a, b) => a.fullName.compareTo(b.fullName));
    return out;
  }

  Future<String> createRequest({
    required AuthorizationRequest request,
    required userModelv2 requester,
  }) async {
    final result = await _functions
        .httpsCallable('crearAutorizacion')
        .call(_callableData(request));
    final response = Map<String, dynamic>.from(result.data as Map);
    return response['id']?.toString() ?? '';
  }

  Future<void> resubmitRequest({
    required String id,
    required AuthorizationRequest updated,
    required userModelv2 requester,
  }) async {
    await _functions.httpsCallable('actualizarAutorizacion').call({
      'id': id,
      'action': 'resubmit',
      ..._callableData(updated),
    });
  }

  Future<AuthorizationPage> listForGroup({
    required String institutionId,
    required String campusId,
    required String groupId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final snap = await _db
        .collection(_col)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('groupId', isEqualTo: groupId)
        .get();

    final items =
        snap.docs
            .map((d) => AuthorizationRequest.fromMap(d.data(), d.id))
            .toList()
          ..sort((a, b) {
            final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });

    return AuthorizationPage(items: items, hasNext: false, lastDoc: null);
  }

  Future<AuthorizationPage> listForAdmin({
    required String institutionId,
    required String campusId,
  }) async {
    final snap = await _db
        .collection(_col)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .get();

    final items =
        snap.docs
            .map((d) => AuthorizationRequest.fromMap(d.data(), d.id))
            .toList()
          ..sort((a, b) {
            final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });

    return AuthorizationPage(items: items, hasNext: false, lastDoc: null);
  }

  Future<void> updateStatus({
    required String id,
    required AuthorizationStatus newStatus,
    String? adminNote,
    String? evidence,
    required userModelv2 admin,
    bool superOverride = false,
  }) async {
    final action = superOverride
        ? 'super_override'
        : switch (newStatus) {
            AuthorizationStatus.pending => 'request_correction',
            AuthorizationStatus.approved => 'approve',
            AuthorizationStatus.rejected => 'reject',
            AuthorizationStatus.finished => 'finish',
          };
    await _functions.httpsCallable('actualizarAutorizacion').call({
      'id': id,
      'action': action,
      'targetStatus': newStatus.name,
      'note': adminNote,
      'evidence': evidence,
    });
  }

  Stream<int> watchPendingCountForAdmin({
    String? institutionId,
    String? campusId,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(_col);
    if ((institutionId ?? '').isNotEmpty) {
      query = query.where('institutionId', isEqualTo: institutionId);
    }
    if ((campusId ?? '').isNotEmpty) {
      query = query.where('campusId', isEqualTo: campusId);
    }
    return query
        .where('status', isEqualTo: AuthorizationStatus.pending.name)
        .snapshots()
        .map((snap) => snap.size);
  }

  Stream<int> watchPendingCountForGroup({
    required String institutionId,
    required String campusId,
    required String groupId,
  }) {
    return _db
        .collection(_col)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: AuthorizationStatus.pending.name)
        .snapshots()
        .map((snap) => snap.size);
  }

  Map<String, dynamic> _callableData(AuthorizationRequest request) => {
    'studentId': request.studentId,
    'allDay': request.allDay,
    'multiDay': request.multiDay,
    'dateFrom': request.dateFrom.millisecondsSinceEpoch,
    'dateTo': request.dateTo?.millisecondsSinceEpoch,
    'startTime': request.startTime?.millisecondsSinceEpoch,
    'endTime': request.endTime?.millisecondsSinceEpoch,
    'reason': request.reason,
  };

  Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    if (list.isEmpty) return;
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }

  List<AuthorizationRequest> _sortedItemsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap, {
    required int limit,
  }) {
    final items =
        snap.docs
            .map((d) => AuthorizationRequest.fromMap(d.data(), d.id))
            .toList()
          ..sort((a, b) {
            final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });

    if (items.length <= limit) return items;
    return items.take(limit).toList();
  }
}
