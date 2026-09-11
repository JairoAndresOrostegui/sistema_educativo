import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/events/models/event_models.dart';
import 'package:sistema_educativo/modules/events/screens/events_screen.dart';
import 'package:sistema_educativo/modules/events/services/event_service.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';
import 'support/active_student_channel_stub.dart';

class _FakeEventGateway implements EventGateway {
  _FakeEventGateway({
    this.items = const [],
    this.roster = const [],
    this.loadError,
    this.linkedChildren = const [],
    this.onEvents,
  });

  List<SchoolEvent> items;
  final List<EventAttendanceEntry> roster;
  Object? loadError;
  List<EventChild> linkedChildren;
  Future<List<SchoolEvent>> Function(String?)? onEvents;
  final List<String?> studentRequests = [];
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
  Future<List<EventChild>> children() async => linkedChildren;

  @override
  Future<EventContext> contexts() async =>
      const EventContext(academicYear: 2026, groups: [], responsibleUsers: []);

  @override
  Future<List<SchoolEvent>> events({String? studentId}) async {
    studentRequests.add(studentId);
    if (loadError != null) throw loadError!;
    if (onEvents != null) return onEvents!(studentId);
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

SchoolEvent _event({
  SchoolEventStatus status = SchoolEventStatus.published,
  String title = 'Salida pedagógica',
}) => SchoolEvent(
  id: 'event',
  title: title,
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

UserProviderV2 _provider(
  String role, {
  List<String> permissions = const ['eventos.ver', 'eventos.editar'],
  String? activeStudentId,
}) => UserProviderV2()
  ..setUser(
    userModelv2.fromFirestore({
      'role': role,
      'firstName': 'Usuario',
      'lastName': 'Prueba',
      'institution': 'institution',
      'campus': 'campus',
      'permissions': permissions,
      'activeStudentId': activeStudentId,
      'studentIds': const ['child-a', 'child-b'],
    }, role == 'Docente' ? 'teacher' : 'student'),
  );

Widget _app(UserProviderV2 provider, Widget child) =>
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final selection = ActiveStudentChannelStub();
  setUpAll(ActiveStudentChannelStub.initialize);
  setUp(selection.install);
  tearDown(selection.uninstall);

  testWidgets('sin permiso de crear ni editar no ofrece acciones de personal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _provider('Docente', permissions: const ['eventos.ver']),
        EventsScreen(service: _FakeEventGateway(items: [_event()])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nuevo evento'), findsNothing);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Finalizar'), findsNothing);
    expect(find.text('Cancelar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'carga vacía es explícita y un fallo permite recuperar con actualizar',
    (tester) async {
      final gateway = _FakeEventGateway();
      await tester.pumpWidget(
        _app(_provider('Estudiante'), EventsScreen(service: gateway)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No hay eventos disponibles.'), findsOneWidget);
      gateway.loadError = FirebaseFunctionsException(
        code: 'unavailable',
        message: '',
      );
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('No hay eventos disponibles.'), findsNothing);
      expect(
        find.text('No fue posible conectarse al servicio. Intenta nuevamente.'),
        findsOneWidget,
      );
      gateway.loadError = null;
      gateway.items = [_event()];
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('Salida pedagógica'), findsOneWidget);
      expect(find.textContaining('No fue posible conectarse'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cambio de hijo oculta tarjetas anteriores mientras espera y reemplaza',
    (tester) async {
      final second = Completer<List<SchoolEvent>>();
      final provider = _provider('Familiar', activeStudentId: 'child-a');
      final gateway = _FakeEventGateway(
        linkedChildren: const [
          EventChild(id: 'child-a', name: 'Hija Ana'),
          EventChild(id: 'child-b', name: 'Hijo Bruno'),
        ],
        onEvents: (id) async =>
            id == 'child-a' ? [_event(title: 'Evento de Ana')] : second.future,
      );
      await tester.pumpWidget(_app(provider, EventsScreen(service: gateway)));
      await tester.pumpAndSettle();
      expect(find.text('Evento de Ana'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hijo Bruno').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Evento de Ana'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(provider.user!.activeStudentId, 'child-b');
      second.complete([_event(title: 'Evento de Bruno')]);
      await tester.pumpAndSettle();
      expect(find.text('Evento de Bruno'), findsOneWidget);
      expect(gateway.studentRequests, ['child-a', 'child-b']);
      expect(selection.selected, ['child-b']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hijos retirados al actualizar borran la información anterior', (
    tester,
  ) async {
    final gateway = _FakeEventGateway(
      items: [_event()],
      linkedChildren: const [EventChild(id: 'child-a', name: 'Hija Ana')],
    );
    await tester.pumpWidget(
      _app(
        _provider('Familiar', activeStudentId: 'child-a'),
        EventsScreen(service: gateway),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Salida pedagógica'), findsOneWidget);
    gateway.linkedChildren = [];
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('Salida pedagógica'), findsNothing);
    expect(find.text('No hay eventos disponibles.'), findsOneWidget);
    expect(gateway.studentRequests, ['child-a']);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('respuesta atrasada no reemplaza una recarga más reciente', (
    tester,
  ) async {
    final gateway = _FakeEventGateway(items: [_event()]);
    await tester.pumpWidget(
      _app(_provider('Estudiante'), EventsScreen(service: gateway)),
    );
    await tester.pumpAndSettle();
    final requests = <Completer<List<SchoolEvent>>>[];
    gateway.onEvents = (_) {
      final request = Completer<List<SchoolEvent>>();
      requests.add(request);
      return request.future;
    };
    final refresh = tester
        .widget<IconButton>(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == 'Actualizar',
          ),
        )
        .onPressed!;
    refresh();
    refresh();
    await tester.pump();
    expect(requests, hasLength(2));
    requests.last.complete([_event(title: 'Respuesta vigente')]);
    await tester.pumpAndSettle();
    requests.first.complete([_event(title: 'Respuesta antigua')]);
    await tester.pumpAndSettle();
    expect(find.text('Respuesta vigente'), findsOneWidget);
    expect(find.text('Respuesta antigua'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selección rechazada restaura opción válida y permite reintentar',
    (tester) async {
      final provider = _provider('Familiar', activeStudentId: 'child-a');
      final gateway = _FakeEventGateway(
        items: [_event()],
        linkedChildren: const [
          EventChild(id: 'child-a', name: 'Hija Ana'),
          EventChild(id: 'child-b', name: 'Hijo Bruno'),
        ],
      );
      await tester.pumpWidget(_app(provider, EventsScreen(service: gateway)));
      await tester.pumpAndSettle();
      provider.setActiveStudentId('child-retired');
      selection.deniedStudentId = 'child-b';
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hijo Bruno').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        'child-a',
      );
      expect(find.text('Salida pedagógica'), findsNothing);
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
      expect(tester.takeException(), isNull);
      selection.deniedStudentId = null;
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(provider.user!.activeStudentId, 'child-a');
      expect(find.text('Salida pedagógica'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('respuesta posterior a salir de pantalla no produce excepción', (
    tester,
  ) async {
    final pending = Completer<List<SchoolEvent>>();
    await tester.pumpWidget(
      _app(
        _provider('Estudiante'),
        EventsScreen(
          service: _FakeEventGateway(onEvents: (_) => pending.future),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete([_event()]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
