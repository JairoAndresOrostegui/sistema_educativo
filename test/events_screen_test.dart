import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/events/models/event_models.dart';
import 'package:sistema_educativo/modules/events/screens/events_screen.dart';
import 'package:sistema_educativo/modules/events/services/event_service.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';

class _FakeEventGateway implements EventGateway {
  _FakeEventGateway({
    this.items = const [],
    this.roster = const [],
    this.loadError,
  });

  final List<SchoolEvent> items;
  final List<EventAttendanceEntry> roster;
  final Object? loadError;
  int saves = 0;

  @override
  Future<(SchoolEvent, List<EventAttendanceEntry>)> attendance(
    String eventId,
  ) async => (items.first, roster);

  @override
  Future<int> changeStatus({
    required String eventId,
    required int expectedRevision,
    required SchoolEventStatus status,
  }) async => expectedRevision + 1;

  @override
  Future<List<EventChild>> children() async => const [];

  @override
  Future<EventContext> contexts() async =>
      const EventContext(academicYear: 2026, groups: [], responsibleUsers: []);

  @override
  Future<List<SchoolEvent>> events({String? studentId}) async {
    if (loadError != null) throw loadError!;
    return items;
  }

  @override
  Future<void> respond({
    required String eventId,
    required String studentId,
    required String response,
  }) async {}

  @override
  Future<List<EventReportRow>> report({
    required DateTime from,
    required DateTime to,
    SchoolEventStatus? status,
  }) async => const [];

  @override
  Future<void> saveAttendance({
    required String eventId,
    required int expectedRevision,
    required List<EventAttendanceEntry> entries,
  }) async {
    saves++;
  }

  @override
  Future<String> saveDraft({
    String? eventId,
    int? expectedRevision,
    required Map<String, dynamic> value,
  }) async => eventId ?? 'event';
}

SchoolEvent _event({SchoolEventStatus status = SchoolEventStatus.published}) =>
    SchoolEvent(
      id: 'event',
      title: 'Salida pedagógica',
      description: 'Visita guiada',
      location: 'Museo',
      startAt: DateTime(2026, 9, 8, 8),
      endAt: DateTime(2026, 9, 8, 10),
      status: status,
      audienceType: 'groups',
      targetGroupIds: const [],
      responsibleNames: const {'teacher': 'Docente Prueba'},
      registrationRequired: false,
      requiresFamilyAuthorization: false,
      confirmedCount: 0,
      revision: 1,
      attendanceRevision: 1,
      links: const [],
      myAttendance: 'present',
    );

UserProviderV2 _provider(String role) => UserProviderV2()
  ..setUser(
    userModelv2.fromFirestore({
      'role': role,
      'firstName': 'Usuario',
      'lastName': 'Prueba',
      'institution': 'institution',
      'campus': 'campus',
      'permissions': const ['eventos.ver', 'eventos.editar'],
    }, role == 'Docente' ? 'teacher' : 'student'),
  );

Widget _app(UserProviderV2 provider, Widget child) =>
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets(
    'error de permisos no muestra una lista vacía ni detalles técnicos',
    (tester) async {
      await tester.pumpWidget(
        _app(
          _provider('Estudiante'),
          EventsScreen(
            service: _FakeEventGateway(
              loadError: FirebaseFunctionsException(
                code: 'permission-denied',
                message: 'PERMISSION_DENIED: Missing permissions',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No hay eventos disponibles.'), findsNothing);
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
      expect(find.byTooltip('Actualizar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('estudiante consulta un evento en pantalla estrecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        _provider('Estudiante'),
        EventsScreen(service: _FakeEventGateway(items: [_event()])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Salida pedagógica'), findsOneWidget);
    expect(find.text('Asistencia: Presente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('asistencia de evento no permite guardar marcas incompletas', (
    tester,
  ) async {
    final gateway = _FakeEventGateway(
      items: [_event(status: SchoolEventStatus.closed)],
      roster: const [
        EventAttendanceEntry(
          studentId: 'student',
          studentName: 'Estudiante Prueba',
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        _provider('Docente'),
        EventAttendanceScreen(event: gateway.items.first, service: gateway),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Guardar asistencia'),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.text('Asistencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Presente').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar asistencia'));
    await tester.pumpAndSettle();
    expect(gateway.saves, 1);
    expect(tester.takeException(), isNull);
  });
}
