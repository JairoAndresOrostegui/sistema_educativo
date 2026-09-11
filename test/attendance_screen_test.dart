import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/attendance/models/attendance_models.dart';
import 'package:sistema_educativo/modules/attendance/screens/attendance_screen.dart';
import 'package:sistema_educativo/modules/attendance/services/attendance_service.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';
import 'support/active_student_channel_stub.dart';

class _FakeAttendanceGateway implements AttendanceGateway {
  _FakeAttendanceGateway({
    this.currentSession,
    this.roster = const [],
    this.loadError,
    this.linkedChildren = const [],
    this.onOwn,
  });

  AttendanceSession? currentSession;
  List<AttendanceEntry> roster;
  Object? loadError;
  List<AttendanceChild> linkedChildren;
  Future<(String, List<AttendanceOwnRecord>)> Function(String?)? onOwn;
  final List<String?> studentRequests = [];
  int saveCalls = 0;

  @override
  Future<List<AttendanceChild>> children() async => linkedChildren;

  @override
  Future<int> close({
    required String sessionId,
    required int expectedRevision,
  }) async => expectedRevision + 1;

  @override
  Future<AttendanceContext> contexts() async => const AttendanceContext(
    groups: [],
    subjects: [],
    academicYearId: 'year',
    academicYear: 2026,
  );

  @override
  Future<String> openSession({
    required String groupId,
    required String date,
    String? subjectId,
  }) async => 'session';

  @override
  Future<AttendanceReport> report({
    required String dateFrom,
    required String dateTo,
    String? groupId,
    String? studentId,
  }) async => AttendanceReport(
    dateFrom: dateFrom,
    dateTo: dateTo,
    sessionCount: 0,
    rows: const [],
    summary: const {},
  );

  @override
  Future<(String, List<AttendanceOwnRecord>)> own({String? studentId}) async {
    studentRequests.add(studentId);
    if (loadError != null) throw loadError!;
    if (onOwn != null) return onOwn!(studentId);
    return (
      'Sara Prueba',
      const [
        AttendanceOwnRecord(
          date: '2026-09-08',
          groupName: 'Séptimo A',
          state: AttendanceState.late,
          observation: 'Llegó a las 7:10 a. m.',
        ),
      ],
    );
  }

  @override
  Future<int> save({
    required String sessionId,
    required int expectedRevision,
    required List<AttendanceEntry> entries,
  }) async {
    saveCalls++;
    currentSession = AttendanceSession(
      id: currentSession!.id,
      groupName: currentSession!.groupName,
      date: currentSession!.date,
      status: currentSession!.status,
      revision: expectedRevision + 1,
      studentCount: currentSession!.studentCount,
      markedCount: currentSession!.markedCount,
      responsibleTeacherName: currentSession!.responsibleTeacherName,
      subjectName: currentSession!.subjectName,
    );
    return expectedRevision + 1;
  }

  @override
  Future<(AttendanceSession, List<AttendanceEntry>)> session(
    String sessionId,
  ) async => (currentSession!, roster);

  @override
  Future<List<AttendanceSession>> sessions() async {
    if (loadError != null) throw loadError!;
    return const [];
  }
}

UserProviderV2 _provider(
  String role,
  List<String> permissions, {
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
    }, 'user'),
  );

Widget _app({required UserProviderV2 provider, required Widget child}) =>
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

  testWidgets(
    'estudiante sin registros y familiar sin hijos tienen estado vacío',
    (tester) async {
      final service = _FakeAttendanceGateway(
        onOwn: (_) async => ('', <AttendanceOwnRecord>[]),
      );
      await tester.pumpWidget(
        _app(
          provider: _provider('Estudiante', const ['asistencia.ver']),
          child: AttendanceScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Todavía no hay registros de asistencia.'),
        findsOneWidget,
      );
      expect(find.text('Nueva lista'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(
          provider: _provider('Familiar', const ['asistencia.ver']),
          child: AttendanceScreen(service: _FakeAttendanceGateway()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No hay un estudiante activo vinculado.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallo de consulta propia se recupera al actualizar sin detalles',
    (tester) async {
      final service = _FakeAttendanceGateway(
        loadError: FirebaseFunctionsException(code: 'unavailable', message: ''),
      );
      await tester.pumpWidget(
        _app(
          provider: _provider('Estudiante', const ['asistencia.ver']),
          child: AttendanceScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No fue posible conectarse al servicio. Intenta nuevamente.'),
        findsOneWidget,
      );
      expect(
        find.text('Todavía no hay registros de asistencia.'),
        findsNothing,
      );
      service.loadError = null;
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('Sara Prueba'), findsOneWidget);
      expect(find.textContaining('No fue posible conectarse'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cambiar hijo borra nombre y asistencia anterior mientras espera',
    (tester) async {
      final second = Completer<(String, List<AttendanceOwnRecord>)>();
      final provider = _provider('Familiar', const [
        'asistencia.ver',
      ], activeStudentId: 'child-a');
      final service = _FakeAttendanceGateway(
        linkedChildren: const [
          AttendanceChild(id: 'child-a', name: 'Hija Ana'),
          AttendanceChild(id: 'child-b', name: 'Hijo Bruno'),
        ],
        onOwn: (id) async => id == 'child-a'
            ? (
                'Registro Ana',
                const [
                  AttendanceOwnRecord(
                    date: '2026-09-08',
                    groupName: 'Grupo Ana',
                    state: AttendanceState.present,
                    observation: 'Registro anterior',
                  ),
                ],
              )
            : second.future,
      );
      await tester.pumpWidget(
        _app(
          provider: provider,
          child: AttendanceScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Registro Ana'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hijo Bruno').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Registro Ana'), findsNothing);
      expect(find.textContaining('Registro anterior'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(provider.user!.activeStudentId, 'child-b');
      second.complete(('Registro Bruno', <AttendanceOwnRecord>[]));
      await tester.pumpAndSettle();
      expect(find.text('Registro Bruno'), findsOneWidget);
      expect(
        find.text('Todavía no hay registros de asistencia.'),
        findsOneWidget,
      );
      expect(service.studentRequests, ['child-a', 'child-b']);
      expect(selection.selected, ['child-b']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hijos retirados no dejan nombre ni asistencia previa al recargar',
    (tester) async {
      final service = _FakeAttendanceGateway(
        linkedChildren: const [
          AttendanceChild(id: 'child-a', name: 'Hija Ana'),
        ],
      );
      await tester.pumpWidget(
        _app(
          provider: _provider('Familiar', const [
            'asistencia.ver',
          ], activeStudentId: 'child-a'),
          child: AttendanceScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sara Prueba'), findsOneWidget);
      service.linkedChildren = [];
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('Sara Prueba'), findsNothing);
      expect(find.textContaining('Llegó a las 7:10'), findsNothing);
      expect(
        find.text('No hay un estudiante activo vinculado.'),
        findsOneWidget,
      );
      expect(service.studentRequests, ['child-a']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'consulta sin permiso de crear no ofrece nueva lista y maneja fallos de carga',
    (tester) async {
      await tester.pumpWidget(
        _app(
          provider: _provider('Administrador', const ['asistencia.ver']),
          child: AttendanceScreen(
            service: _FakeAttendanceGateway(
              loadError: FirebaseFunctionsException(
                code: 'permission-denied',
                message: 'PERMISSION_DENIED',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nueva lista'), findsNothing);
      expect(find.textContaining('Aún no hay listas'), findsNothing);
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
      expect(find.byTooltip('Actualizar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'una respuesta tardía no reemplaza la última asistencia cargada',
    (tester) async {
      final service = _FakeAttendanceGateway();
      await tester.pumpWidget(
        _app(
          provider: _provider('Estudiante', const ['asistencia.ver']),
          child: AttendanceScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      final requests = <Completer<(String, List<AttendanceOwnRecord>)>>[];
      service.onOwn = (_) {
        final request = Completer<(String, List<AttendanceOwnRecord>)>();
        requests.add(request);
        return request.future;
      };
      final refresh = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Actualizar',
            ),
          )
          .onPressed!;
      refresh();
      refresh();
      await tester.pump();
      expect(requests, hasLength(2));
      requests.last.complete(('Registro vigente', <AttendanceOwnRecord>[]));
      await tester.pumpAndSettle();
      requests.first.complete(('Registro anterior', <AttendanceOwnRecord>[]));
      await tester.pumpAndSettle();
      expect(find.text('Registro vigente'), findsOneWidget);
      expect(find.text('Registro anterior'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallo de selección no deja registros y actualizar recupera contexto',
    (tester) async {
      final provider = _provider('Familiar', const [
        'asistencia.ver',
      ], activeStudentId: 'child-a');
      final service = _FakeAttendanceGateway(
        linkedChildren: const [
          AttendanceChild(id: 'child-a', name: 'Hija Ana'),
          AttendanceChild(id: 'child-b', name: 'Hijo Bruno'),
        ],
      );
      await tester.pumpWidget(
        _app(
          provider: provider,
          child: AttendanceScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      provider.setActiveStudentId('child-retired');
      selection.deniedStudentId = 'child-b';
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hijo Bruno').last);
      await tester.pumpAndSettle();
      expect(find.text('Sara Prueba'), findsNothing);
      expect(
        find.text('Todavía no hay registros de asistencia.'),
        findsNothing,
      );
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
      expect(tester.takeException(), isNull);
      selection.deniedStudentId = null;
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(provider.user!.activeStudentId, 'child-a');
      expect(find.text('Sara Prueba'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('respuesta de asistencia después de salir no actualiza widget', (
    tester,
  ) async {
    final pending = Completer<(String, List<AttendanceOwnRecord>)>();
    await tester.pumpWidget(
      _app(
        provider: _provider('Estudiante', const ['asistencia.ver']),
        child: AttendanceScreen(
          service: _FakeAttendanceGateway(onOwn: (_) => pending.future),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(('Fuera de pantalla', <AttendanceOwnRecord>[]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('estudiante consulta su asistencia en una pantalla estrecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        provider: _provider('Estudiante', const ['asistencia.ver']),
        child: AttendanceScreen(service: _FakeAttendanceGateway()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sara Prueba'), findsOneWidget);
    expect(find.textContaining('Tarde'), findsOneWidget);
    expect(find.textContaining('Llegó a las 7:10 a. m.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administración puede corregir una lista cerrada', (
    tester,
  ) async {
    final service = _FakeAttendanceGateway(
      currentSession: const AttendanceSession(
        id: 'session',
        groupName: 'Séptimo A',
        date: '2026-09-08',
        status: 'closed',
        revision: 3,
        studentCount: 1,
        markedCount: 1,
        responsibleTeacherName: 'Docente Prueba',
      ),
      roster: const [
        AttendanceEntry(
          studentId: 'student',
          studentName: 'Estudiante Prueba',
          state: AttendanceState.absent,
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        provider: _provider('Administrador', const ['asistencia.editar']),
        child: AttendanceSessionScreen(sessionId: 'session', service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guardar corrección'), findsOneWidget);
    final dropdown = tester.widget<DropdownButtonFormField<AttendanceState>>(
      find.byType(DropdownButtonFormField<AttendanceState>),
    );
    expect(dropdown.onChanged, isNotNull);
    await tester.tap(find.text('Guardar corrección'));
    await tester.pumpAndSettle();
    expect(service.saveCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
