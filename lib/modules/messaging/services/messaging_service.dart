import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/messaging/message_models.dart';
import '../../../models/user/user_model_v2.dart';

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
          final items =
              snap.docs
                  .map((d) => MessageThreadSummary.fromMap(d.data(), d.id))
                  .toList();
          items.sort((a, b) {
            final da = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
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
          (snap) =>
              snap.docs
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
      final snap =
          await _db
              .collection('users')
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
            grade: (data['grade'] ?? '').toString(),
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
    if (role == 'Docente') {
      return _getTeacherContacts(user);
    }
    if (role == 'Estudiante') {
      return _getTeacherContactsForStudent(
        institutionId: user.institution,
        campusId: user.campus,
        studentId: user.id,
        studentName: '${user.firstName} ${user.lastName}'.trim(),
        studentGrade: user.grade ?? '',
      );
    }
    if (role == 'Familiar') {
      final kids = await getFamilyChildren(user);
      if (kids.isEmpty) return [];
      final selected =
          kids.where((e) => e.id == studentContextId).cast<MessagingChildContext?>().firstWhere(
            (e) => e != null,
            orElse: () => kids.first,
          )!;
      return _getTeacherContactsForStudent(
        institutionId: user.institution,
        campusId: user.campus,
        studentId: selected.id,
        studentName: selected.fullName,
        studentGrade: selected.grade,
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
    String? studentContextGrade,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception('El mensaje no puede estar vacío.');
    }

    final recipient = await _getUserById(
      userId: recipientId,
      institutionId: sender.institution,
      campusId: sender.campus,
    );
    if (recipient == null) {
      throw Exception('No se encontró el destinatario.');
    }

    final existingThread =
        threadId != null && threadId.trim().isNotEmpty
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

    final resolvedThreadId =
        threadId != null && threadId.trim().isNotEmpty
            ? threadId
            : await _ensureThread(
              sender: sender,
              recipient: recipient,
              studentContextId: studentContextId,
              studentContextName: studentContextName,
              studentContextGrade: studentContextGrade,
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
          'contextStudentGrade': studentContextGrade,
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
        'contextStudentGrade': studentContextGrade,
        'lastMessage': trimmed,
        'lastSenderId': sender.id,
        'lastSenderName': senderName,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return resolvedThreadId;
  }

  Future<int> sendMessageToGrade({
    required userModelv2 sender,
    required String grade,
    required String body,
  }) async {
    final trimmedGrade = grade.trim();
    if (sender.role.trim() != 'Docente') {
      throw Exception('Solo los docentes pueden enviar mensajes por grado.');
    }
    if (trimmedGrade.isEmpty) {
      throw Exception('Debes seleccionar un grado válido.');
    }

    final students = await _getActiveStudentsByGrade(
      institutionId: sender.institution,
      campusId: sender.campus,
      grade: trimmedGrade,
    );
    if (students.isEmpty) {
      throw Exception('No hay estudiantes activos en el grado $trimmedGrade.');
    }

    for (final student in students) {
      await sendMessage(
        sender: sender,
        recipientId: student.id,
        body: body,
        studentContextId: student.id,
        studentContextName: '${student.firstName} ${student.lastName}'.trim(),
        studentContextGrade: student.grade ?? trimmedGrade,
      );
    }

    return students.length;
  }

  Future<List<MessageContact>> _getTeacherContacts(userModelv2 user) async {
    final teachersFuture =
        _db
            .collection('users')
            .where('institution', isEqualTo: user.institution)
            .where('campus', isEqualTo: user.campus)
            .where('role', isEqualTo: 'Docente')
            .where('status', isEqualTo: 'activo')
            .get();
    final studentsFuture =
        _db
            .collection('users')
            .where('institution', isEqualTo: user.institution)
            .where('campus', isEqualTo: user.campus)
            .where('role', isEqualTo: 'Estudiante')
            .where('status', isEqualTo: 'activo')
            .get();

    final results = await Future.wait([teachersFuture, studentsFuture]);
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
          grade: (data['grade'] ?? '').toString(),
        ),
      );
    }

    for (final d in results[1].docs) {
      final data = d.data();
      out.add(
        MessageContact(
          id: d.id,
          fullName:
              '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                  .trim(),
          role: 'Estudiante',
          grade: (data['grade'] ?? '').toString(),
          studentContextId: d.id,
          studentContextName:
              '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                  .trim(),
          studentContextGrade: (data['grade'] ?? '').toString(),
        ),
      );
    }

    final grades =
        results[1].docs
            .map((d) => (d.data()['grade'] ?? '').toString().trim())
            .where((g) => g.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    for (final grade in grades) {
      out.add(
        MessageContact(
          id: 'grade_group::$grade',
          fullName: 'Todos los estudiantes de $grade',
          role: 'Grupo',
          isGroup: true,
          targetGrade: grade,
          grade: grade,
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

  Future<List<MessageContact>> _getTeacherContactsForStudent({
    required String institutionId,
    required String campusId,
    required String studentId,
    required String studentName,
    required String studentGrade,
  }) async {
    final teacherMap = <String, MessageContact>{};

    if (studentGrade.trim().isNotEmpty) {
      final subjects =
          await _db
              .collection('subjects')
              .where('institutionId', isEqualTo: institutionId)
              .where('campusId', isEqualTo: campusId)
              .where('grade', isEqualTo: studentGrade)
              .get();

      for (final d in subjects.docs) {
        final data = d.data();
        final teacherId = (data['teacherId'] ?? '').toString().trim();
        final teacherName = (data['teacherName'] ?? '').toString().trim();
        if (teacherId.isEmpty) continue;
        teacherMap[teacherId] = MessageContact(
          id: teacherId,
          fullName: teacherName.isEmpty ? 'Docente' : teacherName,
          role: 'Docente',
          studentContextId: studentId,
          studentContextName: studentName,
          studentContextGrade: studentGrade,
        );
      }

      final directTeachers =
          await _db
              .collection('users')
              .where('institution', isEqualTo: institutionId)
              .where('campus', isEqualTo: campusId)
              .where('role', isEqualTo: 'Docente')
              .where('status', isEqualTo: 'activo')
              .where('grade', isEqualTo: studentGrade)
              .get();

      for (final d in directTeachers.docs) {
        final data = d.data();
        teacherMap[d.id] = MessageContact(
          id: d.id,
          fullName:
              '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                  .trim(),
          role: 'Docente',
          grade: (data['grade'] ?? '').toString(),
          studentContextId: studentId,
          studentContextName: studentName,
          studentContextGrade: studentGrade,
        );
      }
    }

    final contacts = teacherMap.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return contacts;
  }

  Future<String> _ensureThread({
    required userModelv2 sender,
    required userModelv2 recipient,
    String? studentContextId,
    String? studentContextName,
    String? studentContextGrade,
  }) async {
    final snap =
        await _db
            .collection(_threadsCol)
            .where('institutionId', isEqualTo: sender.institution)
            .where('campusId', isEqualTo: sender.campus)
            .where('participantIds', arrayContains: sender.id)
            .get();

    for (final d in snap.docs) {
      final data = d.data();
      final participantIds = List<String>.from(data['participantIds'] ?? const []);
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
      'participantNames': {
        sender.id: senderName,
        recipient.id: recipientName,
      },
      'participantRoles': {
        sender.id: sender.role,
        recipient.id: recipient.role,
      },
      'contextStudentId': studentContextId,
      'contextStudentName': studentContextName,
      'contextStudentGrade': studentContextGrade,
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

    if (senderRole == 'Docente') {
      if (recipientRole == 'Docente' || recipientRole == 'Estudiante') {
        return true;
      }
      if (recipientRole == 'Familiar' && existingThread != null) {
        final participants = List<String>.from(existingThread['participantIds'] ?? const []);
        return participants.contains(sender.id) && participants.contains(recipient.id);
      }
      return false;
    }

    if (senderRole == 'Estudiante') {
      return recipientRole == 'Docente';
    }

    if (senderRole == 'Familiar') {
      if (recipientRole != 'Docente') return false;
      final kids = sender.studentIds ?? const <String>[];
      return studentContextId != null && kids.contains(studentContextId);
    }

    return false;
  }

  Future<userModelv2?> _getUserById({
    required String userId,
    required String institutionId,
    required String campusId,
  }) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    if ((data['institution'] ?? '').toString() != institutionId) return null;
    if ((data['campus'] ?? '').toString() != campusId) return null;
    if ((data['status'] ?? '').toString() != 'activo') return null;
    return userModelv2.fromFirestore(data, doc.id);
  }

  Future<List<userModelv2>> _getActiveStudentsByGrade({
    required String institutionId,
    required String campusId,
    required String grade,
  }) async {
    final snap =
        await _db
            .collection('users')
            .where('institution', isEqualTo: institutionId)
            .where('campus', isEqualTo: campusId)
            .where('role', isEqualTo: 'Estudiante')
            .where('status', isEqualTo: 'activo')
            .where('grade', isEqualTo: grade)
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

  int _roleOrder(MessageContact contact) {
    if (contact.isGroup) return 1;
    switch (contact.role) {
      case 'Docente':
        return 0;
      case 'Estudiante':
        return 2;
      default:
        return 3;
    }
  }

  Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }
}
