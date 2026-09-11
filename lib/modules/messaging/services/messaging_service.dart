import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../models/messaging/message_models.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../utils/active_academic_year_context.dart';
import '../../../utils/private_document_downloader.dart';

class MessagingService {
  MessagingService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    PrivateDocumentDownloader? downloads,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _downloads = downloads ?? const PrivateDocumentDownloader();

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final PrivateDocumentDownloader _downloads;

  Stream<List<MessageThreadSummary>> watchChannels(userModelv2 user) async* {
    final year = await loadActiveAcademicYear(
      firestore: _db,
      institutionId: user.institution,
      campusId: user.campus,
    );
    Query<Map<String, dynamic>> query = _db
        .collection('message_channels')
        .where('institutionId', isEqualTo: user.institution)
        .where('campusId', isEqualTo: user.campus)
        .where('academicYearId', isEqualTo: year.id);
    if (!user.isSuperadmin) {
      query = query.where('memberUserIds', arrayContains: user.id);
    }
    yield* query.snapshots().map((snapshot) {
      final channels = snapshot.docs
          .map((doc) => MessageThreadSummary.fromMap(doc.data(), doc.id))
          .where((channel) => channel.status == 'active')
          .toList();
      channels.sort((a, b) {
        final aDate = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final byDate = bDate.compareTo(aDate);
        return byDate != 0 ? byDate : a.title.compareTo(b.title);
      });
      return channels;
    });
  }

  Stream<int> watchUnreadCount(userModelv2 user) => watchChannels(user).map(
    (channels) => channels.fold<int>(
      0,
      (total, channel) => total + channel.unreadCountFor(user.id),
    ),
  );

  Stream<List<MessageItem>> watchMessages(String channelId) => _db
      .collection('message_channels')
      .doc(channelId)
      .collection('messages')
      .orderBy('sequence')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => MessageItem.fromMap(doc.data(), doc.id))
            .toList(),
      );

  Future<List<MessagingChildContext>> getFamilyChildren(
    userModelv2 family,
  ) async {
    final result = await _functions
        .httpsCallable('obtenerHijosVinculados')
        .call();
    final payload = Map<String, dynamic>.from(result.data as Map);
    final children = <MessagingChildContext>[];
    for (final raw in payload['children'] as List? ?? const []) {
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['status'] != 'activo' ||
          data['institution'] != family.institution ||
          data['campus'] != family.campus) {
        continue;
      }
      children.add(
        MessagingChildContext(
          id: data['id'].toString(),
          fullName: '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
              .trim(),
          groupId: (data['groupId'] ?? '').toString(),
          groupName: (data['groupName'] ?? '').toString(),
        ),
      );
    }
    children.sort((a, b) => a.fullName.compareTo(b.fullName));
    return children;
  }

  Future<List<MessageContact>> getAvailableContacts({
    required String? studentContextId,
  }) async {
    final result = await _functions
        .httpsCallable('listarDestinatariosMensajeria')
        .call({'studentContextId': ?studentContextId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['contacts'] as List? ?? const [])
        .map(
          (item) =>
              MessageContact.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<String> sendMessage({
    required String body,
    String? channelId,
    String? recipientId,
    String? studentContextId,
    String? attachmentId,
  }) async {
    final result = await _functions.httpsCallable('enviarMensajeCanal').call({
      'body': body,
      'channelId': ?channelId,
      'recipientId': ?recipientId,
      'studentContextId': ?studentContextId,
      'attachmentId': ?attachmentId,
    });
    return Map<String, dynamic>.from(
      result.data as Map,
    )['channelId'].toString();
  }

  Future<String> uploadAttachment({
    required String channelId,
    required String name,
    required String contentType,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final result = await _functions
        .httpsCallable('solicitarAdjuntoMensaje')
        .call({
          'channelId': channelId,
          'name': name,
          'contentType': contentType,
          'sizeBytes': bytes.length,
        });
    final reservation = Map<String, dynamic>.from(result.data as Map);
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
                'attachmentId': id,
                'channelId': channelId,
                'uploadedBy': FirebaseAuth.instance.currentUser!.uid,
              },
            ),
          );
      task.snapshotEvents.listen(
        (snapshot) => onProgress?.call(
          snapshot.totalBytes <= 0
              ? 0
              : snapshot.bytesTransferred / snapshot.totalBytes,
        ),
        onError: (_) {},
      );
      await task;
      await _functions.httpsCallable('confirmarAdjuntoMensaje').call({
        'id': id,
      });
      return id;
    } catch (_) {
      await cancelAttachment(id);
      rethrow;
    }
  }

  Future<void> cancelAttachment(String id) async {
    try {
      await _functions.httpsCallable('cancelarAdjuntoMensaje').call({'id': id});
    } catch (_) {
      // La cancelacion es compensatoria; se conserva el error original.
    }
  }

  Future<Uint8List> attachmentDownloadBytes(
    MessageAttachment attachment,
  ) async {
    return _downloads.download(
      endpoint: 'descargarAdjuntoProtegido',
      parameters: {'attachmentId': attachment.id},
    );
  }

  Future<void> registerAttachmentDownload(String attachmentId) async {
    await _functions.httpsCallable('registrarDescargaAdjuntoMensaje').call({
      'attachmentId': attachmentId,
    });
  }

  Future<MessageAttachmentDownloadSummary> attachmentDownloads(
    String attachmentId,
  ) async {
    final result = await _functions
        .httpsCallable('listarDescargasAdjuntoMensaje')
        .call({'attachmentId': attachmentId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return MessageAttachmentDownloadSummary(
      recipientCount: (data['recipientCount'] as num?)?.toInt() ?? 0,
      downloads: (data['receipts'] as List? ?? const [])
          .map(
            (item) => MessageAttachmentDownload.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  Future<void> markRead(String channelId) async {
    await _functions.httpsCallable('marcarCanalMensajeriaLeido').call({
      'channelId': channelId,
    });
  }

  Future<void> setMuted(String channelId, bool muted) async {
    await _functions.httpsCallable('configurarSilencioCanalMensajeria').call({
      'channelId': channelId,
      'muted': muted,
    });
  }

  Future<void> syncAcademicChannels({
    required String institutionId,
    required String campusId,
  }) async {
    await _functions.httpsCallable('sincronizarCanalesMensajeria').call({
      'institutionId': institutionId,
      'campusId': campusId,
    });
  }

  Future<String> createServiceChannel({
    required String title,
    required String category,
    required String audienceType,
    required List<String> groupIds,
  }) async {
    final result = await _functions
        .httpsCallable('crearCanalServicioMensajeria')
        .call({
          'title': title,
          'category': category,
          'audienceType': audienceType,
          'groupIds': groupIds,
        });
    return Map<String, dynamic>.from(
      result.data as Map,
    )['channelId'].toString();
  }
}
