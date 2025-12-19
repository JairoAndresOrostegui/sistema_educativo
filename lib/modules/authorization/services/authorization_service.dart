import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/authorization/authorization_request_model.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../utils/notification_service.dart';

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

  Future<AuthorizationPage> listForStudent({
    required String institutionId,
    required String campusId,
    required String studentId,
    required int limit, // se ignora para no paginar por cursor
    DocumentSnapshot<Map<String, dynamic>>? startAfter, // se ignora
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
            return db.compareTo(da); // desc
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
          'requesterId': requester.id,
          'requesterFullName':
              '${requester.firstName} ${requester.lastName}'.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    final ref = await _db.collection(_col).add(data);
    await _notifyOnCreate(request: request, requester: requester);
    return ref.id;
  }

  Future<void> _notifyOnCreate({
    required AuthorizationRequest request,
    required userModelv2 requester,
  }) async {
    try {
      final adminsSnap =
          await _db
              .collection('users')
              .where('institution', isEqualTo: request.institutionId)
              .where('campus', isEqualTo: request.campusId)
              .where('role', isEqualTo: 'Administrador')
              .where('status', isEqualTo: 'activo')
              .get();
      final adminTokens = <String>{};
      for (final d in adminsSnap.docs) {
        adminTokens.addAll(_extractTokens(d.data()));
      }
      final teachersSnap =
          await _db
              .collection('users')
              .where('institution', isEqualTo: request.institutionId)
              .where('campus', isEqualTo: request.campusId)
              .where('role', isEqualTo: 'Docente')
              .where('status', isEqualTo: 'activo')
              .where('grade', isEqualTo: request.grade)
              .get();
      final teacherTokens = <String>{};
      for (final d in teachersSnap.docs) {
        teacherTokens.addAll(_extractTokens(d.data()));
      }
      final tokens = {...adminTokens, ...teacherTokens}.toList();
      if (tokens.isEmpty) return;
      final title = 'New authorization request';
      final body = '${request.studentFullName} • ${request.grade}';
      await enviarNotificacion(
        tokens: tokens,
        titulo: title,
        cuerpo: body,
        grado: request.grade,
      );
    } catch (_) {}
  }

  Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    if (list.isEmpty) return;
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }

  List<String> _extractTokens(Map<String, dynamic> data) {
    final out = <String>[];
    final t1 = data['fcmToken'];
    if (t1 is String && t1.trim().isNotEmpty) out.add(t1.trim());
    final tN = data['fcmTokens'];
    if (tN is List) {
      out.addAll(
        tN.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }
    return out;
  }

  Future<AuthorizationPage> listForGrade({
    required String institutionId,
    required String campusId,
    required String grade,
    int limit = 20, // se ignora
    DocumentSnapshot<Map<String, dynamic>>? startAfter, // se ignora
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
            return db.compareTo(da); // desc
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

    final upd = <String, dynamic>{
      'status': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final noteTrim = (adminNote ?? '').trim();
    final evTrim = (evidence ?? '').trim();

    if (newStatus == AuthorizationStatus.pending ||
        newStatus == AuthorizationStatus.rejected) {
      upd['adminNote'] = noteTrim.isEmpty ? null : noteTrim;
      upd['evidence'] = null;
    } else if (newStatus == AuthorizationStatus.approved) {
      if (noteTrim.isNotEmpty) upd['adminNote'] = noteTrim;
      upd['evidence'] = null;
    } else if (newStatus == AuthorizationStatus.finished) {
      upd['evidence'] = evTrim.isEmpty ? null : evTrim;
    }

    await ref.update(upd);

    final current = snap.data()!;
    final req = AuthorizationRequest.fromMap({...current, ...upd}, id);

    await _notifyOnStatusChange(
      req: req,
      admin: admin,
      note: upd['adminNote'] as String?,
      evidence: upd['evidence'] as String?,
    );
  }

  Future<void> _notifyOnStatusChange({
    required AuthorizationRequest req,
    required userModelv2 admin,
    String? note,
    String? evidence,
  }) async {
    String label(AuthorizationStatus s) {
      switch (s) {
        case AuthorizationStatus.pending:
          return 'Pendiente';
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

    final title = 'Autorización actualizada';
    final lines = <String>[
      '${req.studentFullName} • ${req.grade}',
      'Estado: ${label(req.status)}',
    ];
    if ((note ?? '').trim().isNotEmpty) lines.add('Nota: ${note!.trim()}');
    if (req.status == AuthorizationStatus.finished &&
        (evidence ?? '').trim().isNotEmpty) {
      lines.add('Evidencia: ${firstWords(evidence!.trim(), 40)}');
    }
    final body = lines.join(' • ');

    final tokens = <String>{};

    final stu = await _db.collection('users').doc(req.studentId).get();
    if (stu.exists) {
      tokens.addAll(_extractTokens(stu.data()!));
    }

    final famSnap =
        await _db
            .collection('users')
            .where('institution', isEqualTo: req.institutionId)
            .where('campus', isEqualTo: req.campusId)
            .where('role', isEqualTo: 'Familiar')
            .where('status', isEqualTo: 'activo')
            .where('studentIds', arrayContains: req.studentId)
            .get();
    for (final d in famSnap.docs) {
      tokens.addAll(_extractTokens(d.data()));
    }

    if (tokens.isEmpty) return;

    await enviarNotificacion(
      tokens: tokens.toList(),
      titulo: title,
      cuerpo: body,
      grado: req.grade,
    );
  }
}
