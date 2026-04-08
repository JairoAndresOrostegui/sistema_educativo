import 'package:cloud_firestore/cloud_firestore.dart';

class MessageContact {
  final String id;
  final String fullName;
  final String role;
  final bool isGroup;
  final String? targetGrade;
  final String? grade;
  final String? studentContextId;
  final String? studentContextName;
  final String? studentContextGrade;

  const MessageContact({
    required this.id,
    required this.fullName,
    required this.role,
    this.isGroup = false,
    this.targetGrade,
    this.grade,
    this.studentContextId,
    this.studentContextName,
    this.studentContextGrade,
  });
}

class MessageThreadSummary {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String> participantRoles;
  final String? contextStudentId;
  final String? contextStudentName;
  final String? contextStudentGrade;
  final String? lastMessage;
  final String? lastSenderId;
  final String? lastSenderName;
  final DateTime? lastMessageAt;

  const MessageThreadSummary({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantRoles,
    this.contextStudentId,
    this.contextStudentName,
    this.contextStudentGrade,
    this.lastMessage,
    this.lastSenderId,
    this.lastSenderName,
    this.lastMessageAt,
  });

  factory MessageThreadSummary.fromMap(
    Map<String, dynamic> data,
    String id,
  ) {
    final rawNames = (data['participantNames'] as Map?) ?? const {};
    final rawRoles = (data['participantRoles'] as Map?) ?? const {};
    final ts = data['lastMessageAt'];

    return MessageThreadSummary(
      id: id,
      participantIds: List<String>.from(data['participantIds'] ?? const []),
      participantNames: rawNames.map(
        (key, value) => MapEntry(key.toString(), (value ?? '').toString()),
      ),
      participantRoles: rawRoles.map(
        (key, value) => MapEntry(key.toString(), (value ?? '').toString()),
      ),
      contextStudentId: (data['contextStudentId'] ?? '').toString().trim().isEmpty
          ? null
          : data['contextStudentId'].toString(),
      contextStudentName: (data['contextStudentName'] ?? '').toString().trim().isEmpty
          ? null
          : data['contextStudentName'].toString(),
      contextStudentGrade: (data['contextStudentGrade'] ?? '').toString().trim().isEmpty
          ? null
          : data['contextStudentGrade'].toString(),
      lastMessage: data['lastMessage']?.toString(),
      lastSenderId: data['lastSenderId']?.toString(),
      lastSenderName: data['lastSenderName']?.toString(),
      lastMessageAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  String peerNameFor(String userId) {
    final peerId =
        participantIds.cast<String?>().firstWhere((id) => id != userId, orElse: () => null);
    if (peerId == null) return 'Conversación';
    return participantNames[peerId] ?? 'Conversación';
  }

  String peerRoleFor(String userId) {
    final peerId =
        participantIds.cast<String?>().firstWhere((id) => id != userId, orElse: () => null);
    if (peerId == null) return '';
    return participantRoles[peerId] ?? '';
  }

  String? peerIdFor(String userId) {
    return participantIds.cast<String?>().firstWhere((id) => id != userId, orElse: () => null);
  }
}

class MessageItem {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String recipientId;
  final String body;
  final DateTime? createdAt;

  const MessageItem({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.recipientId,
    required this.body,
    this.createdAt,
  });

  factory MessageItem.fromMap(Map<String, dynamic> data, String id) {
    final ts = data['createdAt'];
    return MessageItem(
      id: id,
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? '').toString(),
      senderRole: (data['senderRole'] ?? '').toString(),
      recipientId: (data['recipientId'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class MessagingChildContext {
  final String id;
  final String fullName;
  final String grade;

  const MessagingChildContext({
    required this.id,
    required this.fullName,
    required this.grade,
  });
}
