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
  bool get isPrivate => channelType == 'private';
  bool get isAcademicGroup => channelType == 'academic_group';
  bool get isService => channelType == 'service';
  int unreadCountFor(String userId) =>
      (messageSequence - (readSequences[userId] ?? 0)).clamp(0, 9999);
  String displayTitleFor(String userId) {
    if (!isPrivate) return title;
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
    this.createdAt,
  });
  final String id, senderId, senderName, senderRole, body;
  final int sequence;
  final DateTime? createdAt;
  factory MessageItem.fromMap(Map<String, dynamic> data, String id) =>
      MessageItem(
        id: id,
        sequence: (data['sequence'] as num?)?.toInt() ?? 0,
        senderId: (data['senderId'] ?? '').toString(),
        senderName: (data['senderName'] ?? '').toString(),
        senderRole: (data['senderRole'] ?? '').toString(),
        body: (data['body'] ?? '').toString(),
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
