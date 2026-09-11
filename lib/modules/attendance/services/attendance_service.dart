import 'package:cloud_functions/cloud_functions.dart';

import '../models/attendance_models.dart';

class AttendanceChild {
  const AttendanceChild({required this.id, required this.name});
  final String id;
  final String name;
}

abstract interface class AttendanceGateway {
  Future<AttendanceContext> contexts();
  Future<List<AttendanceSession>> sessions();
  Future<String> openSession({
    required String groupId,
    required String date,
    String? subjectId,
  });
  Future<(AttendanceSession, List<AttendanceEntry>)> session(String sessionId);
  Future<int> save({
    required String sessionId,
    required int expectedRevision,
    required List<AttendanceEntry> entries,
  });
  Future<int> close({required String sessionId, required int expectedRevision});
  Future<(String, List<AttendanceOwnRecord>)> own({String? studentId});
  Future<List<AttendanceChild>> children();
  Future<AttendanceReport> report({
    required String dateFrom,
    required String dateTo,
    String? groupId,
    String? studentId,
  });
}

class AttendanceService implements AttendanceGateway {
  AttendanceService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await _functions.httpsCallable(name).call(data);
    if (result.data is! Map) {
      throw StateError('El servidor devolvió una respuesta no válida.');
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<AttendanceContext> contexts() async =>
      AttendanceContext.fromMap(await _call('listarContextosAsistencia'));

  @override
  Future<List<AttendanceSession>> sessions() async {
    final result = await _call('listarSesionesAsistencia');
    return ((result['sessions'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => AttendanceSession.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<String> openSession({
    required String groupId,
    required String date,
    String? subjectId,
  }) async {
    final data = <String, dynamic>{'groupId': groupId, 'date': date};
    if (subjectId != null) data['subjectId'] = subjectId;
    final result = await _call('abrirSesionAsistencia', data);
    return (result['sessionId'] ?? '').toString();
  }

  @override
  Future<(AttendanceSession, List<AttendanceEntry>)> session(
    String sessionId,
  ) async {
    final result = await _call('obtenerSesionAsistencia', {
      'sessionId': sessionId,
    });
    final session = AttendanceSession.fromMap(
      Map<String, dynamic>.from(result['session'] as Map),
    );
    final roster = ((result['roster'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => AttendanceEntry.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    return (session, roster);
  }

  @override
  Future<int> save({
    required String sessionId,
    required int expectedRevision,
    required List<AttendanceEntry> entries,
  }) async {
    final result = await _call('guardarAsistencia', {
      'sessionId': sessionId,
      'expectedRevision': expectedRevision,
      'entries': entries
          .map(
            (entry) => {
              'studentId': entry.studentId,
              'state': entry.state!.wire,
              'observation': entry.observation,
            },
          )
          .toList(),
    });
    return (result['revision'] as num).toInt();
  }

  @override
  Future<int> close({
    required String sessionId,
    required int expectedRevision,
  }) async {
    final result = await _call('cerrarSesionAsistencia', {
      'sessionId': sessionId,
      'expectedRevision': expectedRevision,
    });
    return (result['revision'] as num).toInt();
  }

  @override
  Future<(String, List<AttendanceOwnRecord>)> own({String? studentId}) async {
    final data = <String, dynamic>{};
    if (studentId != null) data['studentId'] = studentId;
    final result = await _call('consultarMiAsistencia', data);
    final student = Map<String, dynamic>.from(result['student'] as Map);
    final records = ((result['records'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              AttendanceOwnRecord.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    return ((student['name'] ?? 'Estudiante').toString(), records);
  }

  @override
  Future<List<AttendanceChild>> children() async {
    final result = await _call('obtenerHijosVinculados');
    return ((result['children'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final value = Map<String, dynamic>.from(item);
          return AttendanceChild(
            id: (value['id'] ?? '').toString(),
            name: '${value['firstName'] ?? ''} ${value['lastName'] ?? ''}'
                .trim(),
          );
        })
        .where((child) => child.id.isNotEmpty)
        .toList();
  }

  @override
  Future<AttendanceReport> report({
    required String dateFrom,
    required String dateTo,
    String? groupId,
    String? studentId,
  }) async {
    final data = <String, dynamic>{'dateFrom': dateFrom, 'dateTo': dateTo};
    if (groupId != null) data['groupId'] = groupId;
    if (studentId != null) data['studentId'] = studentId;
    return AttendanceReport.fromMap(
      await _call('generarReporteAsistencia', data),
    );
  }
}
