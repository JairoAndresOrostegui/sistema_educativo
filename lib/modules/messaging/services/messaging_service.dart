import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/messaging/message_models.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../utils/notification_service.dart';

class MessagingService {
  MessagingService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _threadsCol = 'message_threads';

  Stream<List<MessageThreadSummary>> watchThreadsForUser({
    required String institutionId,
    required String campusId,
    required String userId,
  }) {
    return _db
        .collection(_threadsCol)
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snap) {
          final items = snap.docs
              .map((d) => MessageThreadSummary.fromMap(d.data(), d.id))
              .toList();
          items.sort((a, b) {
            final da =
                a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db =
                b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });
          return items;
        });
  }

  Stream<List<MessageItem>> watchMessages(String threadId) {
    return _db
        .collection(_threadsCol)
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MessageItem.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Future<List<MessagingChildContext>> getFamilyChildren(
    userModelv2 family,
  ) async {
    final ids = family.studentIds ?? const <String>[];
    if (ids.isEmpty) return [];

    final out = <MessagingChildContext>[];
    for (final chunk in _chunks(ids, 10)) {
      final snap = await _db
          .collection('user_directory')
          .where(FieldPath.documentId, whereIn: chunk)
          .where('institution', isEqualTo: family.institution)
          .where('campus', isEqualTo: family.campus)
          .where('role', isEqualTo: 'Estudiante')
          .where('status', isEqualTo: 'activo')
          .get();
      for (final d in snap.docs) {
        final data = d.data();
        out.add(
          MessagingChildContext(
            id: d.id,
            fullName:
                '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                    .trim(),
            groupId: (data['groupId'] ?? '').toString(),
            groupName: (data['groupName'] ?? '').toString(),
          ),
        );
      }
    }
    out.sort((a, b) => a.fullName.compareTo(b.fullName));
    return out;
  }

  Future<List<MessageContact>> getAvailableContacts({
    required userModelv2 user,
    String? studentContextId,
  }) async {
    final role = user.role.trim();
    if (role == 'Administrador') {
      return _getAdminContacts(user);
    }
    if (role == 'Docente') {
      return _getTeacherContacts(user);
    }
    if (role == 'Estudiante') {
      return _getContactsForStudentContext(
        institutionId: user.institution,
        campusId: user.campus,
        studentId: user.id,
        studentName: '${user.firstName} ${user.lastName}'.trim(),
        studentGroupId: user.groupId ?? '',
        studentGroupName: user.groupName ?? '',
      );
    }
    if (role == 'Familiar') {
      final kids = await getFamilyChildren(user);
      if (kids.isEmpty) return [];
      final selected = kids
          .where((e) => e.id == studentContextId)
          .cast<MessagingChildContext?>()
          .firstWhere((e) => e != null, orElse: () => kids.first)!;
      return _getContactsForStudentContext(
        institutionId: user.institution,
        campusId: user.campus,
        studentId: selected.id,
        studentName: selected.fullName,
        studentGroupId: selected.groupId,
        studentGroupName: selected.groupName,
      );
    }
    return [];
  }

  Future<String> sendMessage({
    required userModelv2 sender,
    required String recipientId,
    required String body,
    String? threadId,
    String? studentContextId,
    String? studentContextName,
    String? studentContextGroupId,
    String? studentContextGroupName,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception('El mensaje no puede estar vacio.');
    }

    final recipient = await _getUserById(
      userId: recipientId,
      institutionId: sender.institution,
      campusId: sender.campus,
    );
    if (recipient == null) {
      throw Exception('No se encontro el destinatario.');
    }

    final existingThread = threadId != null && threadId.trim().isNotEmpty
        ? await _db.collection(_threadsCol).doc(threadId).get()
        : null;

    final canMessage = await _canSendMessage(
      sender: sender,
      recipient: recipient,
      existingThread: existingThread?.data(),
      studentContextId: studentContextId,
    );
    if (!canMessage) {
      throw Exception('No tienes permitido enviar mensajes a este usuario.');
    }

    final resolvedThreadId = threadId != null && threadId.trim().isNotEmpty
        ? threadId
        : await _ensureThread(
            sender: sender,
            recipient: recipient,
            studentContextId: studentContextId,
            studentContextName: studentContextName,
            studentContextGroupId: studentContextGroupId,
            studentContextGroupName: studentContextGroupName,
          );

    final threadRef = _db.collection(_threadsCol).doc(resolvedThreadId);
    final msgRef = threadRef.collection('messages').doc();

    final senderName = '${sender.firstName} ${sender.lastName}'.trim();

    await _db.runTransaction((tx) async {
      final threadSnap = await tx.get(threadRef);
      if (!threadSnap.exists) {
        tx.set(threadRef, {
          'institutionId': sender.institution,
          'campusId': sender.campus,
          'participantIds': [sender.id, recipient.id],
          'participantNames': {
            sender.id: senderName,
            recipient.id: '${recipient.firstName} ${recipient.lastName}'.trim(),
          },
          'participantRoles': {
            sender.id: sender.role,
            recipient.id: recipient.role,
          },
          'contextStudentId': studentContextId,
          'contextStudentName': studentContextName,
          'contextStudentGroupId': studentContextGroupId,
          'contextStudentGroupName': studentContextGroupName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      tx.set(msgRef, {
        'senderId': sender.id,
        'senderName': senderName,
        'senderRole': sender.role,
        'recipientId': recipient.id,
        'body': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(threadRef, {
        'institutionId': sender.institution,
        'campusId': sender.campus,
        'participantIds': [sender.id, recipient.id],
        'participantNames': {
          sender.id: senderName,
          recipient.id: '${recipient.firstName} ${recipient.lastName}'.trim(),
        },
        'participantRoles': {
          sender.id: sender.role,
          recipient.id: recipient.role,
        },
        'contextStudentId': studentContextId,
        'contextStudentName': studentContextName,
        'contextStudentGroupId': studentContextGroupId,
        'contextStudentGroupName': studentContextGroupName,
        'lastMessage': trimmed,
        'lastSenderId': sender.id,
        'lastSenderName': senderName,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await _notifyMessageRecipients(
      sender: sender,
      recipients: [recipient],
      body: trimmed,
    );

    return resolvedThreadId;
  }

  Future<int> sendMessageToAcademicGroup({
    required userModelv2 sender,
    required String groupId,
    required String groupName,
    required String body,
  }) async {
    final contact = MessageContact(
      id: 'academic_group::$groupId',
      fullName: 'Todos los estudiantes de $groupName',
      role: 'Grupo',
      isGroup: true,
      groupType: 'academic_group_students',
      targetGroupId: groupId,
      groupId: groupId,
      groupName: groupName,
    );
    return sendMessageToGroup(sender: sender, group: contact, body: body);
  }

  Future<int> sendMessageToGroup({
    required userModelv2 sender,
    required MessageContact group,
    required String body,
  }) async {
    if (!group.isGroup) {
      throw Exception('El destinatario seleccionado no es un grupo.');
    }

    final recipients = await _resolveGroupRecipients(
      sender: sender,
      group: group,
    );
    if (recipients.isEmpty) {
      throw Exception('No hay destinatarios activos para este envio masivo.');
    }

    for (final recipient in recipients) {
      await sendMessage(
        sender: sender,
        recipientId: recipient.id,
        body: body,
        studentContextId: recipient.role.trim() == 'Estudiante'
            ? recipient.id
            : null,
        studentContextName: recipient.role.trim() == 'Estudiante'
            ? '${recipient.firstName} ${recipient.lastName}'.trim()
            : null,
        studentContextGroupId: recipient.role.trim() == 'Estudiante'
            ? (recipient.groupId ?? '')
            : null,
        studentContextGroupName: recipient.role.trim() == 'Estudiante'
            ? (recipient.groupName ?? '')
            : null,
      );
    }

    return recipients.length;
  }

  Future<List<MessageContact>> _getTeacherContacts(userModelv2 user) async {
    final teachersFuture = _db
        .collection('user_directory')
        .where('institution', isEqualTo: user.institution)
        .where('campus', isEqualTo: user.campus)
        .where('role', isEqualTo: 'Docente')
        .where('status', isEqualTo: 'activo')
        .get();
    final adminsFuture = _db
        .collection('user_directory')
        .where('institution', isEqualTo: user.institution)
        .where('campus', isEqualTo: user.campus)
        .where('role', isEqualTo: 'Administrador')
        .where('status', isEqualTo: 'activo')
        .get();
    final studentsFuture = _db
        .collection('user_directory')
        .where('institution', isEqualTo: user.institution)
        .where('campus', isEqualTo: user.campus)
        .where('role', isEqualTo: 'Estudiante')
        .where('status', isEqualTo: 'activo')
        .get();

    final results = await Future.wait([
      teachersFuture,
      adminsFuture,
      studentsFuture,
    ]);
    final out = <MessageContact>[];

    for (final d in results[0].docs) {
      if (d.id == user.id) continue;
      final data = d.data();
      out.add(
        MessageContact(
          id: d.id,
          fullName:
              '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                  .trim(),
          role: 'Docente',
          groupId: (data['groupId'] ?? '').toString(),
          groupName: (data['groupName'] ?? '').toString(),
        ),
      );
    }

    for (final d in results[1].docs) {
      if (d.id == user.id) continue;
      final data = d.data();
      out.add(
        MessageContact(
          id: d.id,
          fullName:
              '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                  .trim(),
          role: 'Administrador',
          groupId: (data['groupId'] ?? '').toString(),
          groupName: (data['groupName'] ?? '').toString(),
        ),
      );
    }

    for (final d in results[2].docs) {
      final data = d.data();
      out.add(
        MessageContact(
          id: d.id,
          fullName:
              '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                  .trim(),
          role: 'Estudiante',
          groupId: (data['groupId'] ?? '').toString(),
          groupName: (data['groupName'] ?? '').toString(),
          studentContextId: d.id,
          studentContextName:
              '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                  .trim(),
          studentContextGroupId: (data['groupId'] ?? '').toString(),
          studentContextGroupName: (data['groupName'] ?? '').toString(),
        ),
      );
    }

    final groups =
        results[2].docs
            .map(
              (d) => (
                id: (d.data()['groupId'] ?? '').toString().trim(),
                name: (d.data()['groupName'] ?? '').toString().trim(),
              ),
            )
            .where((group) => group.id.isNotEmpty)
            .fold(<String, String>{}, (result, group) {
              result[group.id] = group.name;
              return result;
            })
            .entries
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    for (final group in groups) {
      out.add(
        MessageContact(
          id: 'academic_group::${group.key}',
          fullName: 'Todos los estudiantes de ${group.value}',
          role: 'Grupo',
          isGroup: true,
          groupType: 'academic_group_students',
          targetGroupId: group.key,
          groupId: group.key,
          groupName: group.value,
        ),
      );
    }

    out.sort((a, b) {
      final roleCmp = _roleOrder(a).compareTo(_roleOrder(b));
      if (roleCmp != 0) return roleCmp;
      return a.fullName.compareTo(b.fullName);
    });
    return out;
  }

  Future<List<MessageContact>> _getAdminContacts(userModelv2 user) async {
    final snap = await _db
        .collection('user_directory')
        .where('institution', isEqualTo: user.institution)
        .where('campus', isEqualTo: user.campus)
        .where('status', isEqualTo: 'activo')
        .get();

    final out = <MessageContact>[];
    final groups = <String, String>{};
    for (final d in snap.docs) {
      if (d.id == user.id) continue;
      final data = d.data();
      final role = (data['role'] ?? '').toString();
      final groupId = (data['groupId'] ?? '').toString();
      final groupName = (data['groupName'] ?? '').toString();
      if (role == 'Estudiante' && groupId.trim().isNotEmpty) {
        groups[groupId.trim()] = groupName.trim();
      }
      out.add(
        MessageContact(
          id: d.id,
          fullName:
              '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                  .trim(),
          role: role,
          groupId: groupId,
          groupName: groupName,
          studentContextId: role == 'Estudiante' ? d.id : null,
          studentContextName: role == 'Estudiante'
              ? '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                    .trim()
              : null,
          studentContextGroupId: role == 'Estudiante' ? groupId : null,
          studentContextGroupName: role == 'Estudiante' ? groupName : null,
        ),
      );
    }

    final sortedGroups = groups.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final group in sortedGroups) {
      out.add(
        MessageContact(
          id: 'academic_group::${group.key}',
          fullName: 'Todos los estudiantes de ${group.value}',
          role: 'Grupo',
          isGroup: true,
          groupType: 'academic_group_students',
          targetGroupId: group.key,
          groupId: group.key,
          groupName: group.value,
        ),
      );
    }

    out.addAll(const [
      MessageContact(
        id: 'role_group::Estudiante',
        fullName: 'Todos los estudiantes del colegio',
        role: 'Grupo',
        isGroup: true,
        groupType: 'role',
        targetRole: 'Estudiante',
      ),
      MessageContact(
        id: 'role_group::Docente',
        fullName: 'Todos los docentes del colegio',
        role: 'Grupo',
        isGroup: true,
        groupType: 'role',
        targetRole: 'Docente',
      ),
      MessageContact(
        id: 'all_group::users',
        fullName: 'Todos los usuarios del colegio',
        role: 'Grupo',
        isGroup: true,
        groupType: 'all_users',
      ),
    ]);

    out.sort((a, b) {
      final roleCmp = _roleOrder(a).compareTo(_roleOrder(b));
      if (roleCmp != 0) return roleCmp;
      return a.fullName.compareTo(b.fullName);
    });
    return out;
  }

  Future<List<MessageContact>> _getContactsForStudentContext({
    required String institutionId,
    required String campusId,
    required String studentId,
    required String studentName,
    required String studentGroupId,
    required String studentGroupName,
  }) async {
    final contacts = <String, MessageContact>{};

    final teachers = await _db
        .collection('user_directory')
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .where('role', isEqualTo: 'Docente')
        .where('status', isEqualTo: 'activo')
        .get();
    for (final d in teachers.docs) {
      final data = d.data();
      contacts[d.id] = MessageContact(
        id: d.id,
        fullName:
            '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                .trim(),
        role: 'Docente',
        groupId: (data['groupId'] ?? '').toString(),
        groupName: (data['groupName'] ?? '').toString(),
        studentContextId: studentId,
        studentContextName: studentName,
        studentContextGroupId: studentGroupId,
        studentContextGroupName: studentGroupName,
      );
    }

    final admins = await _db
        .collection('user_directory')
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .where('role', isEqualTo: 'Administrador')
        .where('status', isEqualTo: 'activo')
        .get();
    for (final d in admins.docs) {
      final data = d.data();
      contacts[d.id] = MessageContact(
        id: d.id,
        fullName:
            '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                .trim(),
        role: 'Administrador',
        studentContextId: studentId,
        studentContextName: studentName,
        studentContextGroupId: studentGroupId,
        studentContextGroupName: studentGroupName,
      );
    }

    if (studentGroupId.trim().isNotEmpty) {
      final classmates = await _db
          .collection('user_directory')
          .where('institution', isEqualTo: institutionId)
          .where('campus', isEqualTo: campusId)
          .where('role', isEqualTo: 'Estudiante')
          .where('status', isEqualTo: 'activo')
          .where('groupId', isEqualTo: studentGroupId)
          .get();
      for (final d in classmates.docs) {
        if (d.id == studentId) continue;
        final data = d.data();
        contacts[d.id] = MessageContact(
          id: d.id,
          fullName:
              '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                  .trim(),
          role: 'Estudiante',
          groupId: (data['groupId'] ?? '').toString(),
          groupName: (data['groupName'] ?? '').toString(),
          studentContextId: studentId,
          studentContextName: studentName,
          studentContextGroupId: studentGroupId,
          studentContextGroupName: studentGroupName,
        );
      }
    }

    final items = contacts.values.toList()
      ..sort((a, b) {
        final roleCmp = _roleOrder(a).compareTo(_roleOrder(b));
        if (roleCmp != 0) return roleCmp;
        return a.fullName.compareTo(b.fullName);
      });
    return items;
  }

  Future<String> _ensureThread({
    required userModelv2 sender,
    required userModelv2 recipient,
    String? studentContextId,
    String? studentContextName,
    String? studentContextGroupId,
    String? studentContextGroupName,
  }) async {
    final snap = await _db
        .collection(_threadsCol)
        .where('institutionId', isEqualTo: sender.institution)
        .where('campusId', isEqualTo: sender.campus)
        .where('participantIds', arrayContains: sender.id)
        .get();

    for (final d in snap.docs) {
      final data = d.data();
      final participantIds = List<String>.from(
        data['participantIds'] ?? const [],
      );
      if (!participantIds.contains(recipient.id)) continue;
      final currentContext = (data['contextStudentId'] ?? '').toString();
      if (currentContext == (studentContextId ?? '')) {
        return d.id;
      }
    }

    final senderName = '${sender.firstName} ${sender.lastName}'.trim();
    final recipientName = '${recipient.firstName} ${recipient.lastName}'.trim();
    final ref = _db.collection(_threadsCol).doc();
    await ref.set({
      'institutionId': sender.institution,
      'campusId': sender.campus,
      'participantIds': [sender.id, recipient.id],
      'participantNames': {sender.id: senderName, recipient.id: recipientName},
      'participantRoles': {
        sender.id: sender.role,
        recipient.id: recipient.role,
      },
      'contextStudentId': studentContextId,
      'contextStudentName': studentContextName,
      'contextStudentGroupId': studentContextGroupId,
      'contextStudentGroupName': studentContextGroupName,
      'lastMessage': null,
      'lastSenderId': null,
      'lastSenderName': null,
      'lastMessageAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<bool> _canSendMessage({
    required userModelv2 sender,
    required userModelv2 recipient,
    Map<String, dynamic>? existingThread,
    String? studentContextId,
  }) async {
    final senderRole = sender.role.trim();
    final recipientRole = recipient.role.trim();

    if (senderRole == 'Administrador') {
      return true;
    }

    if (senderRole == 'Docente') {
      if (recipientRole == 'Docente' ||
          recipientRole == 'Estudiante' ||
          recipientRole == 'Administrador') {
        return true;
      }
      if (recipientRole == 'Familiar' && existingThread != null) {
        final participants = List<String>.from(
          existingThread['participantIds'] ?? const [],
        );
        return participants.contains(sender.id) &&
            participants.contains(recipient.id);
      }
      return false;
    }

    if (senderRole == 'Estudiante') {
      if (recipientRole == 'Docente' || recipientRole == 'Administrador') {
        return true;
      }
      if (recipientRole == 'Estudiante') {
        final senderGroup = (sender.groupId ?? '').trim();
        final recipientGroup = (recipient.groupId ?? '').trim();
        return senderGroup.isNotEmpty && senderGroup == recipientGroup;
      }
      return false;
    }

    if (senderRole == 'Familiar') {
      final kids = sender.studentIds ?? const <String>[];
      if (studentContextId == null || !kids.contains(studentContextId)) {
        return false;
      }
      if (recipientRole == 'Docente' || recipientRole == 'Administrador') {
        return true;
      }
      if (recipientRole == 'Estudiante') {
        final contextStudent = await _getUserById(
          userId: studentContextId,
          institutionId: sender.institution,
          campusId: sender.campus,
        );
        if (contextStudent == null) return false;
        final contextGroup = (contextStudent.groupId ?? '').trim();
        final recipientGroup = (recipient.groupId ?? '').trim();
        return contextGroup.isNotEmpty && contextGroup == recipientGroup;
      }
      return false;
    }

    return false;
  }

  Future<userModelv2?> _getUserById({
    required String userId,
    required String institutionId,
    required String campusId,
  }) async {
    final doc = await _db.collection('user_directory').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    if ((data['institution'] ?? '').toString() != institutionId) return null;
    if ((data['campus'] ?? '').toString() != campusId) return null;
    if ((data['status'] ?? '').toString() != 'activo') return null;
    return userModelv2.fromFirestore(data, doc.id);
  }

  Future<List<userModelv2>> _getActiveStudentsByGroup({
    required String institutionId,
    required String campusId,
    required String groupId,
  }) async {
    final snap = await _db
        .collection('user_directory')
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .where('role', isEqualTo: 'Estudiante')
        .where('status', isEqualTo: 'activo')
        .where('groupId', isEqualTo: groupId)
        .get();

    final items =
        snap.docs.map((d) => userModelv2.fromFirestore(d.data(), d.id)).toList()
          ..sort((a, b) {
            final nameA = '${a.firstName} ${a.lastName}'.trim();
            final nameB = '${b.firstName} ${b.lastName}'.trim();
            return nameA.compareTo(nameB);
          });
    return items;
  }

  Future<List<userModelv2>> _getActiveUsersByRole({
    required String institutionId,
    required String campusId,
    required String role,
  }) async {
    final snap = await _db
        .collection('user_directory')
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .where('role', isEqualTo: role)
        .where('status', isEqualTo: 'activo')
        .get();
    return snap.docs
        .map((d) => userModelv2.fromFirestore(d.data(), d.id))
        .toList();
  }

  Future<List<userModelv2>> _getAllActiveUsers({
    required String institutionId,
    required String campusId,
  }) async {
    final snap = await _db
        .collection('user_directory')
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .where('status', isEqualTo: 'activo')
        .get();
    return snap.docs
        .map((d) => userModelv2.fromFirestore(d.data(), d.id))
        .toList();
  }

  Future<List<userModelv2>> _resolveGroupRecipients({
    required userModelv2 sender,
    required MessageContact group,
  }) async {
    final senderRole = sender.role.trim();

    if (group.groupType == 'academic_group_students') {
      if (senderRole != 'Docente' && senderRole != 'Administrador') {
        throw Exception(
          'Solo docentes o administradores pueden enviar a grupos acadÃ©micos.',
        );
      }
      final groupId = (group.targetGroupId ?? '').trim();
      if (groupId.isEmpty) {
        throw Exception('Debes seleccionar un grupo acadÃ©mico vÃ¡lido.');
      }
      return _getActiveStudentsByGroup(
        institutionId: sender.institution,
        campusId: sender.campus,
        groupId: groupId,
      );
    }

    if (group.groupType == 'role') {
      if (senderRole != 'Administrador') {
        throw Exception(
          'Solo los administradores pueden enviar a grupos institucionales.',
        );
      }
      final role = (group.targetRole ?? '').trim();
      if (role.isEmpty) {
        throw Exception('El grupo seleccionado no tiene un rol valido.');
      }
      final users = await _getActiveUsersByRole(
        institutionId: sender.institution,
        campusId: sender.campus,
        role: role,
      );
      return users.where((u) => u.id != sender.id).toList();
    }

    if (group.groupType == 'all_users') {
      if (senderRole != 'Administrador') {
        throw Exception(
          'Solo los administradores pueden enviar a todos los usuarios.',
        );
      }
      final users = await _getAllActiveUsers(
        institutionId: sender.institution,
        campusId: sender.campus,
      );
      return users.where((u) => u.id != sender.id).toList();
    }

    throw Exception('Grupo no soportado.');
  }

  Future<void> _notifyMessageRecipients({
    required userModelv2 sender,
    required List<userModelv2> recipients,
    required String body,
  }) async {
    try {
      final senderName = '${sender.firstName} ${sender.lastName}'.trim();
      await enviarNotificacion(
        notificationType: 'messaging',
        userIds: recipients.map((user) => user.id).toList(),
        titulo: 'Nuevo mensaje de $senderName',
        cuerpo: body.length > 120 ? '${body.substring(0, 120)}...' : body,
      );
    } catch (_) {
      // No bloquear el envio del mensaje si falla la notificacion.
    }
  }

  int _roleOrder(MessageContact contact) {
    if (contact.isGroup) return 1;
    switch (contact.role) {
      case 'Administrador':
        return 0;
      case 'Docente':
        return 2;
      case 'Estudiante':
        return 3;
      case 'Familiar':
        return 4;
      default:
        return 5;
    }
  }

  Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }
}
