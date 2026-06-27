import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/authorization/authorization_request_model.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../utils/notification_service.dart';
import '../../../utils/notification_tokens.dart';

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
  final String grade;
  const ChildRef({
    required this.id,
    required this.fullName,
    required this.grade,
  });
}

class AuthorizationService {
  final _db = FirebaseFirestore.instance;
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

  Stream<List<AuthorizationRequest>> watchForGrade({
    required String institutionId,
    required String campusId,
    required String grade,
    int limit = 20,
  }) {
    return _db
        .collection(_col)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('grade', isEqualTo: grade)
        .snapshots()
        .map((snap) => _sortedItemsFromSnapshot(snap, limit: limit));
  }

  Stream<List<AuthorizationRequest>> watchForAdmin({
    required String institutionId,
    required String campusId,
    int limit = 50,
  }) {
    return _db
        .collection(_col)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .snapshots()
        .map((snap) => _sortedItemsFromSnapshot(snap, limit: limit));
  }

  Future<AuthorizationPage> listForStudent({
    required String institutionId,
    required String campusId,
    required String studentId,
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final snap =
        await _db
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
      final snap =
          await _db
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .where('institution', isEqualTo: institutionId)
              .where('campus', isEqualTo: campusId)
              .get();
      for (final d in snap.docs) {
        final m = d.data();
        final fn = (m['firstName'] ?? '').toString();
        final ln = (m['lastName'] ?? '').toString();
        final grade = (m['grade'] ?? '').toString();
        out.add(ChildRef(id: d.id, fullName: '$fn $ln'.trim(), grade: grade));
      }
    }
    out.sort((a, b) => a.fullName.compareTo(b.fullName));
    return out;
  }

  Future<String> createRequest({
    required AuthorizationRequest request,
    required userModelv2 requester,
  }) async {
    final data =
        request.toMap()..addAll({
          'status': AuthorizationStatus.pending.name,
          'adminNote': null,
          'evidence': null,
          'requesterId': requester.id,
          'requesterFullName':
              '${requester.firstName} ${requester.lastName}'.trim(),
          'requiresRequesterEdit': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    final ref = await _db.collection(_col).add(data);
    await _notifyOnCreate(request: request, requester: requester);
    return ref.id;
  }

  Future<void> resubmitRequest({
    required String id,
    required AuthorizationRequest updated,
    required userModelv2 requester,
  }) async {
    final ref = _db.collection(_col).doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception('La autorizacion no existe.');
    }

    final current = AuthorizationRequest.fromMap(snap.data()!, id);
    if (current.status != AuthorizationStatus.pending ||
        !current.requiresRequesterEdit) {
      throw Exception('Esta autorizacion no esta habilitada para correccion.');
    }
    if (current.requesterId != requester.id) {
      throw Exception('Solo el solicitante puede corregir esta autorizacion.');
    }

    final upd = <String, dynamic>{
      'studentId': updated.studentId,
      'studentFullName': updated.studentFullName,
      'grade': updated.grade,
      'allDay': updated.allDay,
      'multiDay': updated.multiDay,
      'dateFrom': updated.dateFrom,
      'dateTo': updated.dateTo,
      'startTime': updated.startTime,
      'endTime': updated.endTime,
      'reason': updated.reason,
      'status': AuthorizationStatus.pending.name,
      'requiresRequesterEdit': false,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await ref.update(upd);
    final merged = AuthorizationRequest.fromMap({...snap.data()!, ...upd}, id);
    await _notifyOnCreate(request: merged, requester: requester);
  }

  Future<AuthorizationPage> listForGrade({
    required String institutionId,
    required String campusId,
    required String grade,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final snap =
        await _db
            .collection(_col)
            .where('institutionId', isEqualTo: institutionId)
            .where('campusId', isEqualTo: campusId)
            .where('grade', isEqualTo: grade)
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
    final snap =
        await _db
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
  }) async {
    final ref = _db.collection(_col).doc(id);
    final snap = await ref.get();
    if (!snap.exists) return;

    final current = AuthorizationRequest.fromMap(snap.data()!, id);
    if (current.status == AuthorizationStatus.rejected ||
        current.status == AuthorizationStatus.finished) {
      throw Exception('Esta autorizacion ya no puede modificarse.');
    }
    if (current.status == AuthorizationStatus.approved &&
        newStatus != AuthorizationStatus.finished) {
      throw Exception('Una autorizacion aprobada solo puede pasar a finalizada.');
    }
    if (newStatus == AuthorizationStatus.finished &&
        current.status != AuthorizationStatus.approved) {
      throw Exception('Solo una autorizacion aprobada puede finalizarse.');
    }

    final noteTrim = (adminNote ?? '').trim();
    final evidenceTrim = (evidence ?? '').trim();
    final upd = <String, dynamic>{
      'status': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == AuthorizationStatus.pending) {
      upd['adminNote'] = noteTrim.isEmpty ? null : noteTrim;
      upd['evidence'] = null;
      upd['requiresRequesterEdit'] = true;
    } else if (newStatus == AuthorizationStatus.rejected) {
      upd['adminNote'] = noteTrim.isEmpty ? null : noteTrim;
      upd['evidence'] = null;
      upd['requiresRequesterEdit'] = false;
    } else if (newStatus == AuthorizationStatus.approved) {
      upd['adminNote'] = null;
      upd['evidence'] = null;
      upd['requiresRequesterEdit'] = false;
    } else if (newStatus == AuthorizationStatus.finished) {
      upd['adminNote'] = current.adminNote;
      upd['evidence'] = evidenceTrim.isEmpty ? null : evidenceTrim;
      upd['requiresRequesterEdit'] = false;
    }

    await ref.update(upd);

    final req = AuthorizationRequest.fromMap({...snap.data()!, ...upd}, id);
    await _notifyOnStatusChange(req: req, note: upd['adminNote'] as String?, evidence: upd['evidence'] as String?);
  }

  Stream<int> watchPendingCountForAdmin({
    required String institutionId,
    required String campusId,
  }) {
    return _db
        .collection(_col)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('status', isEqualTo: AuthorizationStatus.pending.name)
        .snapshots()
        .map((snap) => snap.size);
  }

  Stream<int> watchPendingCountForGrade({
    required String institutionId,
    required String campusId,
    required String grade,
  }) {
    return _db
        .collection(_col)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('grade', isEqualTo: grade)
        .where('status', isEqualTo: AuthorizationStatus.pending.name)
        .snapshots()
        .map((snap) => snap.size);
  }

  Future<void> _notifyOnCreate({
    required AuthorizationRequest request,
    required userModelv2 requester,
  }) async {
    try {
      final adminSnap =
          await _db
              .collection('users')
              .where('institution', isEqualTo: request.institutionId)
              .where('campus', isEqualTo: request.campusId)
              .where('role', isEqualTo: 'Administrador')
              .where('status', isEqualTo: 'activo')
              .get();
      final teacherSnap =
          await _db
              .collection('users')
              .where('institution', isEqualTo: request.institutionId)
              .where('campus', isEqualTo: request.campusId)
              .where('role', isEqualTo: 'Docente')
              .where('status', isEqualTo: 'activo')
              .where('grade', isEqualTo: request.grade)
              .get();

      final tokens = <String>{};
      for (final d in adminSnap.docs) {
        tokens.addAll(extractNotificationTokens(d.data()));
      }
      for (final d in teacherSnap.docs) {
        tokens.addAll(extractNotificationTokens(d.data()));
      }
      if (tokens.isEmpty) return;

      await enviarNotificacion(
        tokens: tokens.toList(),
        titulo: 'Nueva autorizacion pendiente',
        cuerpo: '${request.studentFullName} - ${request.grade}',
        grado: request.grade,
      );
    } catch (_) {}
  }

  Future<void> _notifyOnStatusChange({
    required AuthorizationRequest req,
    String? note,
    String? evidence,
  }) async {
    try {
      String label(AuthorizationStatus s) {
        switch (s) {
          case AuthorizationStatus.pending:
            return 'Pendiente para correccion';
          case AuthorizationStatus.approved:
            return 'Aprobada';
          case AuthorizationStatus.rejected:
            return 'Rechazada';
          case AuthorizationStatus.finished:
            return 'Finalizada';
        }
      }

      String firstWords(String text, int n) {
        final parts = text.trim().split(RegExp(r'\s+'));
        if (parts.length <= n) return text.trim();
        return '${parts.take(n).join(' ')}...';
      }

      final familySnap =
          await _db
              .collection('users')
              .where('institution', isEqualTo: req.institutionId)
              .where('campus', isEqualTo: req.campusId)
              .where('role', isEqualTo: 'Familiar')
              .where('status', isEqualTo: 'activo')
              .where('studentIds', arrayContains: req.studentId)
              .get();
      final teacherSnap =
          await _db
              .collection('users')
              .where('institution', isEqualTo: req.institutionId)
              .where('campus', isEqualTo: req.campusId)
              .where('role', isEqualTo: 'Docente')
              .where('status', isEqualTo: 'activo')
              .where('grade', isEqualTo: req.grade)
              .get();

      final tokens = <String>{};
      for (final d in familySnap.docs) {
        tokens.addAll(extractNotificationTokens(d.data()));
      }
      for (final d in teacherSnap.docs) {
        tokens.addAll(extractNotificationTokens(d.data()));
      }
      if (tokens.isEmpty) return;

      final lines = <String>[
        '${req.studentFullName} - ${req.grade}',
        'Estado: ${label(req.status)}',
      ];
      if ((note ?? '').trim().isNotEmpty) {
        lines.add('Nota: ${note!.trim()}');
      }
      if (req.status == AuthorizationStatus.finished &&
          (evidence ?? '').trim().isNotEmpty) {
        lines.add('Observacion: ${firstWords(evidence!.trim(), 40)}');
      }

      await enviarNotificacion(
        tokens: tokens.toList(),
        titulo: 'Autorizacion actualizada',
        cuerpo: lines.join(' - '),
        grado: req.grade,
      );
    } catch (_) {}
  }

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
