import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/attendance/models/attendance_models.dart';
import 'package:sistema_educativo/modules/attendance/screens/attendance_screen.dart';
import 'package:sistema_educativo/modules/attendance/services/attendance_service.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';

class _FakeAttendanceGateway implements AttendanceGateway {
  _FakeAttendanceGateway({
    this.currentSession,
    this.roster = const [],
    this.loadError,
  });

  AttendanceSession? currentSession;
  List<AttendanceEntry> roster;
  final Object? loadError;
  int saveCalls = 0;

  @override
  Future<List<AttendanceChild>> children() async => const [];

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
  Future<(String, List<AttendanceOwnRecord>)> own({String? studentId}) async =>
      (
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

UserProviderV2 _provider(String role, List<String> permissions) =>
    UserProviderV2()..setUser(
      userModelv2.fromFirestore({
        'role': role,
        'firstName': 'Usuario',
        'lastName': 'Prueba',
        'institution': 'institution',
        'campus': 'campus',
        'permissions': permissions,
      }, 'user'),
    );

Widget _app({required UserProviderV2 provider, required Widget child}) =>
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: child),
    );

void main() {
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
