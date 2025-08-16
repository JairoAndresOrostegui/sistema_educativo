import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/schedule/subject_model.dart';
import '../../../models/user/userModelV2.dart';
import '../../../utils/notification_service.dart';
import '../../../utils/parameters_service.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<SubjectModel>> getDaySchedule({
    required String institutionId,
    required String campusId,
    required String grade,
    required String day,
  }) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('subjects')
              .where('institutionId', isEqualTo: institutionId)
              .where('campusId', isEqualTo: campusId)
              .where('grade', isEqualTo: grade)
              .where('day', isEqualTo: day)
              .orderBy('startTime')
              .get();

      return querySnapshot.docs
          .map((doc) => SubjectModel.fromMap(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error fetching schedule for $day: $e');
    }
  }

  Future<void> createSubject({
    required SubjectModel subject,
    required UserModelV2 creator,
  }) async {
    try {
      final docRef = await _firestore
          .collection('subjects')
          .add(subject.toMap());
      final newSubjectWithId = subject.copyWith(id: docRef.id);

      await _logScheduleAction(
        action: 'create_subject',
        creator: creator,
        subject: newSubjectWithId,
        message:
            'Materia ${newSubjectWithId.subject} creada en el grado ${newSubjectWithId.grade} para el ${newSubjectWithId.day}',
      );

      if (newSubjectWithId.institutionId != null &&
          newSubjectWithId.campusId != null &&
          newSubjectWithId.grade != null) {
        await _notifyScheduleChange(
          institutionId: newSubjectWithId.institutionId!,
          campusId: newSubjectWithId.campusId!,
          grade: newSubjectWithId.grade!,
          title: 'Horario actualizado (${newSubjectWithId.grade})',
          body:
              'Se creó "${newSubjectWithId.subject}" el ${newSubjectWithId.day}.',
        );
      }
    } catch (e) {
      throw Exception('Error creating subject: $e');
    }
  }

  Future<void> editSubject({
    required SubjectModel oldSubject,
    required SubjectModel newSubject,
    required UserModelV2 editor,
  }) async {
    try {
      if (newSubject.id == null) {
        throw Exception('Subject ID is missing for editing');
      }
      await _firestore
          .collection('subjects')
          .doc(newSubject.id)
          .update(newSubject.toMap());

      await _logScheduleAction(
        action: 'edit_subject',
        creator: editor,
        subject: newSubject,
        message:
            'Materia ${oldSubject.subject} editada a ${newSubject.subject} en el grado ${newSubject.grade} el ${newSubject.day}.',
      );

      if (newSubject.institutionId != null &&
          newSubject.campusId != null &&
          newSubject.grade != null) {
        await _notifyScheduleChange(
          institutionId: newSubject.institutionId!,
          campusId: newSubject.campusId!,
          grade: newSubject.grade!,
          title: 'Horario actualizado (${newSubject.grade})',
          body:
              'Se editó "${oldSubject.subject}" → "${newSubject.subject}" el ${newSubject.day}.',
        );
      }
    } catch (e) {
      throw Exception('Error editing subject: $e');
    }
  }

  Future<void> deleteSubject({
    required SubjectModel subject,
    required UserModelV2 remover,
  }) async {
    try {
      if (subject.id == null) {
        throw Exception('Subject ID is missing for deletion');
      }
      await _firestore.collection('subjects').doc(subject.id).delete();

      await _logScheduleAction(
        action: 'delete_subject',
        creator: remover,
        subject: subject,
        message:
            'Materia ${subject.subject} eliminada del grado ${subject.grade} en el ${subject.day}',
      );

      if (subject.institutionId != null &&
          subject.campusId != null &&
          subject.grade != null) {
        await _notifyScheduleChange(
          institutionId: subject.institutionId!,
          campusId: subject.campusId!,
          grade: subject.grade!,
          title: 'Horario actualizado (${subject.grade})',
          body: 'Se eliminó "${subject.subject}" del ${subject.day}.',
        );
      }
    } catch (e) {
      throw Exception('Error deleting subject: $e');
    }
  }

  Future<List<UserModelV2>> getTeachers({
    required String institutionId,
    required String campusId,
  }) async {
    try {
      return await ParametersService().getUsersByFilters(
        institution: institutionId,
        campus: campusId,
        role: 'Docente',
      );
    } catch (e) {
      return [];
    }
  }

  Future<void> _logScheduleAction({
    required String action,
    required UserModelV2 creator,
    required SubjectModel subject,
    required String message,
  }) async {
    try {
      final subjectData = subject.toMap();

      final logData = {
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': creator.id,
        'userName': '${creator.firstName} ${creator.lastName}',
        'institutionId': creator.institution,
        'campusId': creator.campus,
        'subjectData': subjectData,
        'message': message,
      };
      await _firestore.collection('schedule_history').add(logData);
    } catch (e) {}
  }

  Future<Map<String, List<SubjectModel>>> getSchedulesForGrade({
    required String institutionId,
    required String campusId,
    required String grade,
  }) async {
    final Map<String, List<SubjectModel>> allSchedules = {};
    final days = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes'];

    for (var day in days) {
      allSchedules[day] = await getDaySchedule(
        institutionId: institutionId,
        campusId: campusId,
        grade: grade,
        day: day,
      );
    }
    return allSchedules;
  }

  Future<List<UserModelV2>> getUsersByIds({
    required List<String> userIds,
    required String institutionId,
    required String campusId,
  }) async {
    if (userIds.isEmpty) {
      return [];
    }
    final snapshot =
        await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: userIds)
            .where('institution', isEqualTo: institutionId)
            .where('campus', isEqualTo: campusId)
            .get();
    return snapshot.docs
        .map((doc) => UserModelV2.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<Map<String, List<SubjectModel>>> getSchedulesForTeacher({
    required String institutionId,
    required String campusId,
    required String teacherId,
  }) async {
    final snap =
        await _firestore
            .collection('subjects')
            .where('institutionId', isEqualTo: institutionId)
            .where('campusId', isEqualTo: campusId)
            .where('teacherId', isEqualTo: teacherId)
            .get();

    final all =
        snap.docs.map((d) => SubjectModel.fromMap(d.data(), id: d.id)).toList();

    final Map<String, List<SubjectModel>> byDay = {
      'lunes': [],
      'martes': [],
      'miércoles': [],
      'jueves': [],
      'viernes': [],
    };

    for (final s in all) {
      final d = (s.day ?? '').toLowerCase();
      if (byDay.containsKey(d)) byDay[d]!.add(s);
    }

    // Orden final por hora
    for (final k in byDay.keys) {
      byDay[k]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return byDay;
  }

  List<String> _extractTokens(Map<String, dynamic> data) {
    final out = <String>[];

    // Soporta fcmToken (string) y fcmTokens (lista)
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

  Future<void> _notifyScheduleChange({
    required String institutionId,
    required String campusId,
    required String grade,
    required String title,
    required String body,
  }) async {
    try {
      // 1) Estudiantes del grado (misma institución/campus)
      final studentsSnap =
          await _firestore
              .collection('users')
              .where('institution', isEqualTo: institutionId)
              .where('campus', isEqualTo: campusId)
              .where('role', isEqualTo: 'Estudiante')
              .where('grade', isEqualTo: grade)
              .where('status', isEqualTo: 'activo')
              .get();

      final studentIds = studentsSnap.docs.map((d) => d.id).toList();

      // Tokens estudiantes
      final studentTokens = <String>{};
      for (final d in studentsSnap.docs) {
        studentTokens.addAll(_extractTokens(d.data()));
      }

      // 2) Familiares que tengan esos estudiantes (array-contains-any máx 10)
      final familyTokens = <String>{};
      for (final chunk in _chunks(studentIds, 10)) {
        if (chunk.isEmpty) continue;
        final famSnap =
            await _firestore
                .collection('users')
                .where('institution', isEqualTo: institutionId)
                .where('campus', isEqualTo: campusId)
                .where('role', isEqualTo: 'Familiar')
                .where('status', isEqualTo: 'activo')
                .where('studentIds', arrayContainsAny: chunk)
                .get();
        for (final d in famSnap.docs) {
          familyTokens.addAll(_extractTokens(d.data()));
        }
      }

      final allTokens = {...studentTokens, ...familyTokens}.toList();
      if (allTokens.isEmpty) return;

      await enviarNotificacion(
        tokens: allTokens,
        titulo: title,
        cuerpo: body,
        grado: grade,
      );
    } catch (_) {
      // silenciar errores de notificación para no romper el CRUD
    }
  }
}
