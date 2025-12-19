import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../models/file/file_model.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../utils/notification_service.dart';

class FileService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> uploadFile({
    required File file,
    required String name,
    required String grade,
    required String uploaderId,
    required String uploaderName,
    required String institutionId,
    required String campusId,
  }) async {
    final path =
        'files/$grade/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = _storage.ref().child(path);

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    final data = {
      'name': name,
      'url': url,
      'grade': grade,
      'uploadedBy': uploaderId,
      'uploaderName': uploaderName,
      'institutionId': institutionId,
      'campusId': campusId,
      'createdAt': FieldValue.serverTimestamp(),
      'storagePath': path,
    };

    await _db.collection('files').add(data);

    await _notifyStudentsAndFamilies(
      institutionId: institutionId,
      campusId: campusId,
      grade: grade,
      title: 'Nuevo archivo disponible',
      body: name,
    );
  }

  Future<List<FileModel>> getFilesByGrade({
    required String institutionId,
    required String campusId,
    required String grade,
  }) async {
    final snap =
        await _db
            .collection('files')
            .where('institutionId', isEqualTo: institutionId)
            .where('campusId', isEqualTo: campusId)
            .where('grade', isEqualTo: grade)
            .get();

    final list = snap.docs.map((d) => FileModel.fromFirestore(d)).toList();

    list.sort((a, b) {
      final ta = a.createdAt.millisecondsSinceEpoch;
      final tb = b.createdAt.millisecondsSinceEpoch;
      return tb.compareTo(ta);
    });

    return list;
  }

  Future<void> deleteFile(String docId, String url) async {
    await _db.collection('files').doc(docId).delete();
    final ref = _storage.refFromURL(url);
    await ref.delete();
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

  Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }

  Future<void> _notifyStudentsAndFamilies({
    required String institutionId,
    required String campusId,
    required String grade,
    required String title,
    required String body,
  }) async {
    try {
      final stuSnap =
          await _db
              .collection('users')
              .where('institution', isEqualTo: institutionId)
              .where('campus', isEqualTo: campusId)
              .where('role', isEqualTo: 'Estudiante')
              .where('grade', isEqualTo: grade)
              .where('status', isEqualTo: 'activo')
              .get();

      final studentIds = stuSnap.docs.map((d) => d.id).toList();

      final stuTokens = <String>{};
      for (final d in stuSnap.docs) {
        stuTokens.addAll(_extractTokens(d.data()));
      }

      final famTokens = <String>{};
      for (final chunk in _chunks(studentIds, 10)) {
        if (chunk.isEmpty) continue;
        final famSnap =
            await _db
                .collection('users')
                .where('institution', isEqualTo: institutionId)
                .where('campus', isEqualTo: campusId)
                .where('role', isEqualTo: 'Familiar')
                .where('status', isEqualTo: 'activo')
                .where('studentIds', arrayContainsAny: chunk)
                .get();
        for (final d in famSnap.docs) {
          famTokens.addAll(_extractTokens(d.data()));
        }
      }

      final tokens = {...stuTokens, ...famTokens}.toList();
      if (tokens.isEmpty) return;

      await enviarNotificacion(
        tokens: tokens,
        titulo: title,
        cuerpo: body,
        grado: grade,
      );
    } catch (_) {
      // Best-effort notification
    }
  }

  Future<List<Map<String, dynamic>>> getUploadedFiles({
    required userModelv2 currentUser,
    String? selectedGrade,
  }) async {
    Query query = _db
        .collection('files')
        .where('institutionId', isEqualTo: currentUser.institution)
        .where('campusId', isEqualTo: currentUser.campus);

    final role = currentUser.role.toLowerCase();
    final isAdmin = role == 'admin' || role == 'administrador';

    if (isAdmin) {
      if (selectedGrade == null) return [];
      query = query.where('grade', isEqualTo: selectedGrade);
    } else {
      query = query.where('uploadedBy', isEqualTo: currentUser.id);
    }

    final snap = await query.get();

    final items =
        snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data() as Map);
          data['id'] = d.id;
          return data;
        }).toList();

    items.sort((a, b) {
      final ta =
          (a['createdAt'] is Timestamp)
              ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
              : 0;
      final tb =
          (b['createdAt'] is Timestamp)
              ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
              : 0;
      return tb.compareTo(ta);
    });

    return items;
  }
}
