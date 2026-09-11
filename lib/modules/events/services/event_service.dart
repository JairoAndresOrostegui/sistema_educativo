import 'package:cloud_functions/cloud_functions.dart';

import '../models/event_models.dart';

class EventChild {
  const EventChild({required this.id, required this.name});
  final String id;
  final String name;
}

abstract interface class EventGateway {
  Future<EventContext> contexts();
  Future<List<SchoolEvent>> events({String? studentId});
  Future<List<EventChild>> children();
  Future<String> saveDraft({
    String? eventId,
    int? expectedRevision,
    required Map<String, dynamic> value,
  });
  Future<int> changeStatus({
    required String eventId,
    required int expectedRevision,
    required SchoolEventStatus status,
  });
  Future<void> respond({
    required String eventId,
    required String studentId,
    required String response,
  });
  Future<(SchoolEvent, List<EventAttendanceEntry>)> attendance(String eventId);
  Future<void> saveAttendance({
    required String eventId,
    required int expectedRevision,
    required List<EventAttendanceEntry> entries,
  });
  Future<List<EventReportRow>> report({
    required DateTime from,
    required DateTime to,
    SchoolEventStatus? status,
  });
}

class EventService implements EventGateway {
  EventService({FirebaseFunctions? functions})
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
  Future<EventContext> contexts() async =>
      EventContext.fromMap(await _call('listarContextosEventos'));

  @override
  Future<List<SchoolEvent>> events({String? studentId}) async {
    final data = <String, dynamic>{};
    if (studentId != null) data['studentId'] = studentId;
    final result = await _call('listarEventos', data);
    return ((result['events'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => SchoolEvent.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<List<EventChild>> children() async {
    final result = await _call('obtenerHijosVinculados');
    return ((result['children'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => EventChild(
            id: (item['id'] ?? '').toString(),
            name: '${item['firstName'] ?? ''} ${item['lastName'] ?? ''}'.trim(),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  @override
  Future<String> saveDraft({
    String? eventId,
    int? expectedRevision,
    required Map<String, dynamic> value,
  }) async {
    final result = await _call('guardarEvento', {
      ...value,
      'eventId': ?eventId,
      'expectedRevision': ?expectedRevision,
    });
    return (result['eventId'] ?? '').toString();
  }

  @override
  Future<int> changeStatus({
    required String eventId,
    required int expectedRevision,
    required SchoolEventStatus status,
  }) async {
    final result = await _call('cambiarEstadoEvento', {
      'eventId': eventId,
      'expectedRevision': expectedRevision,
      'status': status.wire,
    });
    return (result['revision'] as num).toInt();
  }

  @override
  Future<void> respond({
    required String eventId,
    required String studentId,
    required String response,
  }) async {
    await _call('responderEvento', {
      'eventId': eventId,
      'studentId': studentId,
      'response': response,
    });
  }

  @override
  Future<(SchoolEvent, List<EventAttendanceEntry>)> attendance(
    String eventId,
  ) async {
    final result = await _call('obtenerAsistenciaEvento', {'eventId': eventId});
    return (
      SchoolEvent.fromMap(Map<String, dynamic>.from(result['event'] as Map)),
      ((result['roster'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                EventAttendanceEntry.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }

  @override
  Future<void> saveAttendance({
    required String eventId,
    required int expectedRevision,
    required List<EventAttendanceEntry> entries,
  }) async {
    var revision = expectedRevision;
    for (var offset = 0; offset < entries.length; offset += 400) {
      final result = await _call('guardarAsistenciaEvento', {
        'eventId': eventId,
        'expectedRevision': revision,
        'entries': entries
            .skip(offset)
            .take(400)
            .map((item) => {'studentId': item.studentId, 'state': item.state})
            .toList(),
      });
      revision = (result['revision'] as num).toInt();
    }
  }

  @override
  Future<List<EventReportRow>> report({
    required DateTime from,
    required DateTime to,
    SchoolEventStatus? status,
  }) async {
    final result = await _call('generarReporteEventos', {
      'fromMillis': from.millisecondsSinceEpoch,
      'toMillis': to.millisecondsSinceEpoch,
      'status': ?status?.wire,
    });
    return ((result['rows'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => EventReportRow.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
