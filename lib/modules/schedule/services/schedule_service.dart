import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../models/schedule/subject_model.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../utils/parameters_service.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<List<SubjectModel>> getDaySchedule({
    required String institutionId,
    required String campusId,
    required String groupId,
    required String day,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('subjects')
          .where('institutionId', isEqualTo: institutionId)
          .where('campusId', isEqualTo: campusId)
          .where('groupId', isEqualTo: groupId)
          .where('day', isEqualTo: day)
          .orderBy('startTime')
          .get();

      return querySnapshot.docs
          .map((doc) => SubjectModel.fromMap(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error consultando el horario de $day: $e');
    }
  }

  Future<void> createSubject({
    required SubjectModel subject,
    required userModelv2 creator,
  }) async {
    try {
      await _functions
          .httpsCallable('crearHorario')
          .call(_callableSubject(subject));
    } catch (e) {
      throw Exception('Error creating subject: $e');
    }
  }

  Future<void> editSubject({
    required SubjectModel oldSubject,
    required SubjectModel newSubject,
    required userModelv2 editor,
  }) async {
    try {
      if (newSubject.id == null) {
        throw Exception('Subject ID is missing for editing');
      }
      await _functions.httpsCallable('editarHorario').call({
        'id': newSubject.id,
        ..._callableSubject(newSubject),
      });
    } catch (e) {
      throw Exception('Error editing subject: $e');
    }
  }

  Future<void> deleteSubject({
    required SubjectModel subject,
    required userModelv2 remover,
  }) async {
    try {
      if (subject.id == null) {
        throw Exception('Subject ID is missing for deletion');
      }
      await _functions.httpsCallable('eliminarHorario').call({
        'id': subject.id,
      });
    } catch (e) {
      throw Exception('Error deleting subject: $e');
    }
  }

  Future<List<userModelv2>> getTeachers({
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

  Future<Map<String, List<SubjectModel>>> getSchedulesForGroup({
    required String institutionId,
    required String campusId,
    required String groupId,
  }) async {
    final Map<String, List<SubjectModel>> allSchedules = {};
    final days = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes'];

    for (var day in days) {
      allSchedules[day] = await getDaySchedule(
        institutionId: institutionId,
        campusId: campusId,
        groupId: groupId,
        day: day,
      );
    }
    return allSchedules;
  }

  Future<List<userModelv2>> getUsersByIds({
    required List<String> userIds,
    required String institutionId,
    required String campusId,
  }) async {
    if (userIds.isEmpty) {
      return [];
    }
    final snapshot = await _firestore
        .collection('user_directory')
        .where(FieldPath.documentId, whereIn: userIds)
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .get();
    return snapshot.docs
        .map((doc) => userModelv2.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<Map<String, List<SubjectModel>>> getSchedulesForTeacher({
    required String institutionId,
    required String campusId,
    required String teacherId,
  }) async {
    final snap = await _firestore
        .collection('subjects')
        .where('institutionId', isEqualTo: institutionId)
        .where('campusId', isEqualTo: campusId)
        .where('teacherId', isEqualTo: teacherId)
        .get();

    final all = snap.docs
        .map((d) => SubjectModel.fromMap(d.data(), id: d.id))
        .toList();

    final Map<String, List<SubjectModel>> byDay = {
      'lunes': [],
      'martes': [],
      'miercoles': [],
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

  Map<String, dynamic> _callableSubject(SubjectModel subject) {
    final start = subject.startTime.toDate();
    final end = subject.endTime.toDate();
    return {
      'subject': subject.subject,
      'teacherId': subject.teacherId,
      'groupId': subject.groupId,
      'day': subject.day,
      'institutionId': subject.institutionId,
      'campusId': subject.campusId,
      'startMinutes': start.hour * 60 + start.minute,
      'endMinutes': end.hour * 60 + end.minute,
    };
  }
}
