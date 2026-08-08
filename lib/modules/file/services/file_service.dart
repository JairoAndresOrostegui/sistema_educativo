import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../models/file/file_model.dart';

class FileStorageSummary {
  final int usedBytes;
  final int reservedBytes;
  final int limitBytes;
  final int maxFileBytes;
  final int oldFilesCount;
  final int retentionDays;

  const FileStorageSummary({
    required this.usedBytes,
    required this.reservedBytes,
    required this.limitBytes,
    required this.maxFileBytes,
    required this.oldFilesCount,
    required this.retentionDays,
  });

  double get ratio => limitBytes <= 0
      ? 0
      : ((usedBytes + reservedBytes) / limitBytes).clamp(0, 1);
}

class FileUploadProgress {
  final int transferredBytes;
  final int totalBytes;

  const FileUploadProgress(this.transferredBytes, this.totalBytes);

  double get ratio => totalBytes <= 0 ? 0 : transferredBytes / totalBytes;
}

class FileService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  FileService({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _db = db ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  Future<List<FileModel>> list({
    required String institutionId,
    required String campusId,
    required String groupId,
  }) async {
    final snapshot = await _db
        .collection('files')
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'active')
        .get();
    final files = snapshot.docs.map(FileModel.fromFirestore).toList();
    files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return files;
  }

  Future<void> upload({
    required Uint8List bytes,
    required String name,
    required String contentType,
    required String institutionId,
    required String campusId,
    required String groupId,
    void Function(FileUploadProgress progress)? onProgress,
  }) async {
    final reservationResult = await _functions
        .httpsCallable('solicitarCargaArchivo')
        .call({
          'name': name,
          'contentType': contentType,
          'sizeBytes': bytes.length,
          'institutionId': institutionId,
          'campusId': campusId,
          'groupId': groupId,
        });
    final reservation = Map<String, dynamic>.from(
      reservationResult.data as Map,
    );
    final id = reservation['id'].toString();
    final path = reservation['storagePath'].toString();
    try {
      final task = _storage
          .ref(path)
          .putData(
            bytes,
            SettableMetadata(
              contentType: contentType,
              customMetadata: {
                'fileId': id,
                'groupId': groupId,
                'uploadedBy': FirebaseAuth.instance.currentUser!.uid,
              },
            ),
          );
      task.snapshotEvents.listen((snapshot) {
        onProgress?.call(
          FileUploadProgress(snapshot.bytesTransferred, snapshot.totalBytes),
        );
      });
      await task;
      await _functions.httpsCallable('confirmarCargaArchivo').call({'id': id});
    } catch (_) {
      try {
        await _functions.httpsCallable('cancelarCargaArchivo').call({'id': id});
      } catch (_) {}
      rethrow;
    }
  }

  Future<String> downloadUrl(FileModel file) =>
      _storage.ref(file.storagePath).getDownloadURL();

  Future<void> deleteSelected(Iterable<String> ids) async {
    await _functions.httpsCallable('eliminarArchivos').call({
      'ids': ids.toSet().toList(),
    });
  }

  Future<int> deleteOlderThanRetention() async {
    var total = 0;
    while (true) {
      final result = await _functions
          .httpsCallable('limpiarArchivosAntiguos')
          .call();
      final deleted =
          (Map<String, dynamic>.from(result.data as Map)['deleted'] as num?)
              ?.toInt() ??
          0;
      total += deleted;
      if (deleted < 100) return total;
    }
  }

  Future<FileStorageSummary> summary({String? institutionId}) async {
    final result = await _functions
        .httpsCallable('obtenerResumenArchivos')
        .call({'institutionId': institutionId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return FileStorageSummary(
      usedBytes: (data['usedBytes'] as num?)?.toInt() ?? 0,
      reservedBytes: (data['reservedBytes'] as num?)?.toInt() ?? 0,
      limitBytes: (data['limitBytes'] as num?)?.toInt() ?? 1,
      maxFileBytes: (data['maxFileBytes'] as num?)?.toInt() ?? 0,
      oldFilesCount: (data['oldFilesCount'] as num?)?.toInt() ?? 0,
      retentionDays: (data['retentionDays'] as num?)?.toInt() ?? 60,
    );
  }
}
