import 'package:cloud_firestore/cloud_firestore.dart';

class MessageContact {
  const MessageContact({
    required this.id,
    required this.fullName,
    required this.role,
    this.groupId,
    this.groupName,
    this.studentContextId,
  });
  final String id;
  final String fullName;
  final String role;
  final String? groupId;
  final String? groupName;
  final String? studentContextId;
  factory MessageContact.fromMap(Map<String, dynamic> data) => MessageContact(
    id: (data['id'] ?? '').toString(),
    fullName: (data['fullName'] ?? '').toString(),
    role: (data['role'] ?? '').toString(),
    groupId: data['groupId']?.toString(),
    groupName: data['groupName']?.toString(),
    studentContextId: data['studentContextId']?.toString(),
  );
}

class MessageThreadSummary {
  const MessageThreadSummary({
    required this.id,
    required this.channelType,
    required this.category,
    required this.iconKey,
    required this.title,
    required this.memberUserIds,
    required this.memberNames,
    required this.memberRoles,
    required this.messageSequence,
    required this.readSequences,
    required this.readAtByUser,
    required this.mutedByAdmin,
    required this.status,
    this.groupId,
    this.groupName,
    this.contextStudentId,
    this.contextStudentName,
    this.lastMessage,
    this.lastSenderId,
    this.lastSenderName,
    this.lastMessageAt,
    this.familyGroupId,
    this.supervisedStudentId,
    this.supervisedStaffId,
    this.familyIds = const [],
    this.targetGroupIds = const [],
  });
  final String id, channelType, category, iconKey, title, status;
  final List<String> memberUserIds;
  final Map<String, String> memberNames, memberRoles;
  final int messageSequence;
  final Map<String, int> readSequences;
  final Map<String, DateTime> readAtByUser;
  final bool mutedByAdmin;
  final String? groupId, groupName, contextStudentId, contextStudentName;
  final String? lastMessage, lastSenderId, lastSenderName;
  final DateTime? lastMessageAt;
  final String? familyGroupId;
  final String? supervisedStudentId, supervisedStaffId;
  final List<String> familyIds;
  final List<String> targetGroupIds;
  bool belongsToChild(MessagingChildContext child) {
    if (isAcademicGroup) return groupId == child.groupId;
    if (isService) return targetGroupIds.contains(child.groupId);
    if (familyGroupId != null) return familyGroupId == child.groupId;
    return contextStudentId == child.id;
  }

  bool get isPrivate =>
      channelType == 'private' || channelType == 'supervised_student';
  bool get isSupervised => channelType == 'supervised_student';
  bool get isAcademicGroup => channelType == 'academic_group';
  bool get isService => channelType == 'service';
  int unreadCountFor(String userId) =>
      (messageSequence - (readSequences[userId] ?? 0)).clamp(0, 9999);
  String displayTitleFor(String userId) {
    if (!isPrivate) return title;
    if (isSupervised) {
      final ownRole = memberRoles[userId] ?? '';
      final targetId = ownRole == 'Docente' || ownRole == 'Administrador'
          ? supervisedStudentId
          : supervisedStaffId;
      return targetId == null
          ? 'Conversación supervisada'
          : memberNames[targetId] ?? 'Conversación supervisada';
    }
    final peerId = memberUserIds.cast<String?>().firstWhere(
      (id) => id != userId,
      orElse: () => null,
    );
    return peerId == null
        ? 'Conversación privada'
        : memberNames[peerId] ?? 'Conversación privada';
  }

  String subtitleFor(String userId) {
    if (isAcademicGroup) return groupName ?? 'Grupo académico';
    if (isService) return 'Canal de servicio';
    if (isSupervised) {
      final student = (contextStudentName ?? '').trim();
      return [
        'Conversación supervisada',
        if (student.isNotEmpty) 'Estudiante: $student',
        '${familyIds.length} familiar${familyIds.length == 1 ? '' : 'es'}',
      ].join(' • ');
    }
    final peerId = memberUserIds.cast<String?>().firstWhere(
      (id) => id != userId,
      orElse: () => null,
    );
    final role = peerId == null ? '' : memberRoles[peerId] ?? '';
    final context = (contextStudentName ?? '').trim();
    return [
      role,
      if (context.isNotEmpty) 'Contexto: $context',
    ].where((v) => v.isNotEmpty).join(' • ');
  }

  int readCountForSequence(int sequence, {String? excludingUserId}) =>
      readSequences.entries
          .where(
            (entry) => entry.key != excludingUserId && entry.value >= sequence,
          )
          .length;
  factory MessageThreadSummary.fromMap(Map<String, dynamic> data, String id) {
    final names = data['memberNames'] is Map
        ? data['memberNames'] as Map
        : const {};
    final roles = data['memberRoles'] is Map
        ? data['memberRoles'] as Map
        : const {};
    final reads = data['readSequences'] is Map
        ? data['readSequences'] as Map
        : const {};
    final dates = data['readAtByUser'] is Map
        ? data['readAtByUser'] as Map
        : const {};
    return MessageThreadSummary(
      id: id,
      channelType: (data['channelType'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      iconKey: (data['iconKey'] ?? 'private').toString(),
      title: (data['title'] ?? 'Conversación').toString(),
      memberUserIds: List<String>.from(data['memberUserIds'] ?? const []),
      memberNames: names.map((k, v) => MapEntry(k.toString(), v.toString())),
      memberRoles: roles.map((k, v) => MapEntry(k.toString(), v.toString())),
      messageSequence: (data['messageSequence'] as num?)?.toInt() ?? 0,
      readSequences: reads.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
      ),
      readAtByUser: dates.map(
        (k, v) => MapEntry(
          k.toString(),
          v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ),
      mutedByAdmin: data['mutedByAdmin'] == true,
      status: (data['status'] ?? 'active').toString(),
      groupId: data['groupId']?.toString(),
      familyGroupId: data['familyGroupId']?.toString(),
      supervisedStudentId: data['supervisedStudentId']?.toString(),
      supervisedStaffId: data['supervisedStaffId']?.toString(),
      familyIds: List<String>.from(data['familyIds'] ?? const []),
      targetGroupIds: List<String>.from(data['targetGroupIds'] ?? const []),
      groupName: data['groupName']?.toString(),
      contextStudentId: data['contextStudentId']?.toString(),
      contextStudentName: data['contextStudentName']?.toString(),
      lastMessage: data['lastMessage']?.toString(),
      lastSenderId: data['lastSenderId']?.toString(),
      lastSenderName: data['lastSenderName']?.toString(),
      lastMessageAt: data['lastMessageAt'] is Timestamp
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class MessageItem {
  const MessageItem({
    required this.id,
    required this.sequence,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.body,
    this.recipientUserIds = const [],
    this.recipientNames = const {},
    this.recipientRoles = const {},
    this.readAtByUser = const {},
    this.readNames = const {},
    this.readRoles = const {},
    this.createdAt,
  });
  final String id, senderId, senderName, senderRole, body;
  final int sequence;
  final List<String> recipientUserIds;
  final Map<String, String> recipientNames, recipientRoles;
  final Map<String, DateTime> readAtByUser;
  final Map<String, String> readNames, readRoles;
  final DateTime? createdAt;
  factory MessageItem.fromMap(
    Map<String, dynamic> data,
    String id,
  ) => MessageItem(
    id: id,
    sequence: (data['sequence'] as num?)?.toInt() ?? 0,
    senderId: (data['senderId'] ?? '').toString(),
    senderName: (data['senderName'] ?? '').toString(),
    senderRole: (data['senderRole'] ?? '').toString(),
    body: (data['body'] ?? '').toString(),
    recipientUserIds: List<String>.from(data['recipientUserIds'] ?? const []),
    recipientNames:
        (data['recipientNames'] is Map
                ? data['recipientNames'] as Map
                : const <String, dynamic>{})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
    recipientRoles:
        (data['recipientRoles'] is Map
                ? data['recipientRoles'] as Map
                : const <String, dynamic>{})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
    readAtByUser:
        (data['readAtByUser'] is Map
                ? data['readAtByUser'] as Map
                : const <String, dynamic>{})
            .map(
              (key, value) => MapEntry(
                key.toString(),
                value is Timestamp
                    ? value.toDate()
                    : DateTime.fromMillisecondsSinceEpoch(0),
              ),
            ),
    readNames:
        (data['readNames'] is Map
                ? data['readNames'] as Map
                : const <String, dynamic>{})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
    readRoles:
        (data['readRoles'] is Map
                ? data['readRoles'] as Map
                : const <String, dynamic>{})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
    createdAt: data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null,
  );
}

class MessagingChildContext {
  const MessagingChildContext({
    required this.id,
    required this.fullName,
    required this.groupId,
    required this.groupName,
  });
  final String id, fullName, groupId, groupName;
}
