import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../models/messaging/message_models.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../utils/active_academic_year_context.dart';

class MessagingService {
  MessagingService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _db = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

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
    if (!user.isSuperadmin && user.role != 'Administrador') {
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
    final ids = family.studentIds ?? const <String>[];
    final children = <MessagingChildContext>[];
    for (var index = 0; index < ids.length; index += 30) {
      final end = index + 30 > ids.length ? ids.length : index + 30;
      final snapshot = await _db
          .collection('user_directory')
          .where(FieldPath.documentId, whereIn: ids.sublist(index, end))
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['status'] != 'activo' ||
            data['role'] != 'Estudiante' ||
            data['institution'] != family.institution ||
            data['campus'] != family.campus) {
          continue;
        }
        children.add(
          MessagingChildContext(
            id: doc.id,
            fullName: '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                .trim(),
            groupId: (data['groupId'] ?? '').toString(),
            groupName: (data['groupName'] ?? '').toString(),
          ),
        );
      }
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
  }) async {
    final result = await _functions.httpsCallable('enviarMensajeCanal').call({
      'body': body,
      'channelId': ?channelId,
      'recipientId': ?recipientId,
      'studentContextId': ?studentContextId,
    });
    return Map<String, dynamic>.from(
      result.data as Map,
    )['channelId'].toString();
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
