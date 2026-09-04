import 'dart:typed_data';

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
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  FileService({FirebaseStorage? storage, FirebaseFunctions? functions})
    : _storage = storage ?? FirebaseStorage.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  Future<FileAudienceOptions> audienceOptions({
    required String institutionId,
    required String campusId,
  }) async {
    final result = await _functions
        .httpsCallable('obtenerOpcionesAudienciaArchivos')
        .call({'institutionId': institutionId, 'campusId': campusId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return FileAudienceOptions(
      groups: (data['groups'] as List? ?? const [])
          .map(
            (item) => FileAudienceGroup.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      students: (data['students'] as List? ?? const [])
          .map(
            (item) => FileAudienceStudent.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  Future<List<FileModel>> list({
    required String institutionId,
    required String campusId,
    String? activeStudentId,
  }) async {
    final result = await _functions.httpsCallable('listarArchivos').call({
      'institutionId': institutionId,
      'campusId': campusId,
      'activeStudentId': activeStudentId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final files = (data['files'] as List? ?? const []).map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return FileModel.fromMap(map, id: map['id'].toString());
    }).toList();
    files.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return files;
  }

  Future<void> upload({
    required Uint8List bytes,
    required String name,
    required String contentType,
    required String institutionId,
    required String campusId,
    required FileAudienceType audienceType,
    required List<String> targetGroupIds,
    required List<String> targetStudentIds,
    required String message,
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
          'audienceType': audienceType.value,
          'targetGroupIds': targetGroupIds,
          'targetStudentIds': targetStudentIds,
          'message': message,
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
