import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/authorization/authorization_request_model.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/authorization/screens/admin_authorization_screen.dart';
import 'package:sistema_educativo/modules/authorization/screens/student_authorization_screen.dart';
import 'package:sistema_educativo/modules/authorization/screens/teacher_authorization_screen.dart';
import 'package:sistema_educativo/modules/authorization/services/authorization_service.dart';
import 'package:sistema_educativo/modules/user/services/active_student_service.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';

class _Authorizations implements AuthorizationService {
  final controller = StreamController<List<AuthorizationRequest>>.broadcast();
  final studentControllers =
      <String, StreamController<List<AuthorizationRequest>>>{};
  final watchedStudentIds = <String>[];
  final watchedAdminScopes = <String>[];
  List<ChildRef> children = [];
  int childrenLoads = 0;
  Object? childrenError;

  Future<void> close() async {
    await controller.close();
    for (final stream in studentControllers.values) {
      await stream.close();
    }
  }

  @override
  Future<List<ChildRef>> getChildrenForFamily({
    required String institutionId,
    required String campusId,
    required List<String> studentIds,
  }) async {
    childrenLoads++;
    final error = childrenError;
    if (error != null) throw error;
    return children;
  }

  @override
  Stream<List<AuthorizationRequest>> watchForStudent({
    required String institutionId,
    required String campusId,
    required String studentId,
    int limit = 20,
  }) {
    watchedStudentIds.add(studentId);
    return studentControllers[studentId]?.stream ?? controller.stream;
  }

  @override
  Stream<List<AuthorizationRequest>> watchForGroup({
    required String institutionId,
    required String campusId,
    required String groupId,
    int limit = 20,
  }) => controller.stream;

  @override
  Stream<List<AuthorizationRequest>> watchForAdmin({
    String? institutionId,
    String? campusId,
    int limit = 50,
  }) {
    watchedAdminScopes.add('$institutionId/$campusId');
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SelectChild implements ActiveStudentService {
  final selectedStudentIds = <String>[];
  void Function(String studentId)? beforeSelect;
  String? rejectedStudentId;

  @override
  Future<void> select({
    required UserProviderV2 userProvider,
    required String studentId,
  }) async {
    selectedStudentIds.add(studentId);
    beforeSelect?.call(studentId);
    if (studentId == rejectedStudentId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'UNAVAILABLE: internal transport detail',
      );
    }
    userProvider.setActiveStudentId(studentId);
  }
}

UserProviderV2 _user(
  String role, {
  String? groupId,
  List<String> studentIds = const ['child'],
}) => UserProviderV2()
  ..setUser(
    userModelv2.fromFirestore({
      'role': role,
      'status': 'activo',
      'institution': 'i',
      'campus': 'c',
      'permissions': ['autorizaciones.ver'],
      'groupId': groupId,
      'activeStudentId': 'child',
      'studentIds': studentIds,
    }, 'user'),
  );

Widget _host(
  Widget screen,
  String role, {
  String? groupId,
  UserProviderV2? userProvider,
}) {
  final provider = userProvider ?? _user(role, groupId: groupId);
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(home: screen),
  );
}

const _firstChild = ChildRef(
  id: 'child',
  fullName: 'Primer estudiante',
  groupId: 'group',
  groupName: 'Cuarto A',
);
const _secondChild = ChildRef(
  id: 'child2',
  fullName: 'Segundo estudiante',
  groupId: 'group2',
  groupName: 'Quinto B',
);

AuthorizationRequest _request(ChildRef child) => AuthorizationRequest(
  id: 'request-${child.id}',
  institutionId: 'i',
  campusId: 'c',
  studentId: child.id,
  studentFullName: child.fullName,
  groupId: child.groupId,
  groupName: child.groupName,
  requesterId: 'user',
  requesterFullName: 'Familiar de prueba',
  allDay: true,
  multiDay: false,
  dateFrom: DateTime(2026, 9, 11),
  status: AuthorizationStatus.pending,
);

Future<void> _chooseSecondChild(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Segundo estudiante • Quinto B').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() complete) async {
  for (var frame = 0; frame < 50 && !complete(); frame++) {
    // StreamSubscription.cancel may reuse Dart's completed future from the
    // outer zone. Drain that real microtask queue before advancing fake time.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(
    complete(),
    isTrue,
    reason: 'La operación debe completar sin bloquearse.',
  );
}

void main() {
  testWidgets('docente sin grupo no queda cargando ni abre modal', (
    tester,
  ) async {
    final service = _Authorizations();
    addTearDown(service.controller.close);
    await tester.pumpWidget(
      _host(AuthorizationTeacherScreen(service: service), 'Docente'),
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay grupo asignado al docente.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'familiar con error ve reintento y recupera stream sin falso vacío',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Authorizations()
        ..children = [
          const ChildRef(
            id: 'child',
            fullName: 'Estudiante de prueba',
            groupId: 'group',
            groupName: 'Cuarto A',
          ),
        ];
      addTearDown(service.controller.close);
      await tester.pumpWidget(
        _host(
          AuthorizationStudentScreen(
            service: service,
            activeStudentService: _SelectChild(),
          ),
          'Familiar',
        ),
      );
      await tester.pump();
      service.controller.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No tienes permiso para realizar esta operación.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('No hay solicitudes'), findsNothing);
      service.controller.add([]);
      await tester.pumpAndSettle();
      expect(find.text('No hay solicitudes'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pulsar Reintentar vuelve a cargar hijos y sus solicitudes', (
    tester,
  ) async {
    final service = _Authorizations()..children = [_firstChild];
    final selection = _SelectChild();
    addTearDown(service.close);
    await tester.pumpWidget(
      _host(
        AuthorizationStudentScreen(
          service: service,
          activeStudentService: selection,
        ),
        'Familiar',
      ),
    );
    await tester.pump();
    service.controller.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await tester.pumpAndSettle();
    expect(service.childrenLoads, 1);
    expect(service.watchedStudentIds, ['child']);
    expect(find.text('No hay solicitudes'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await _pumpUntil(tester, () => service.watchedStudentIds.length == 2);
    expect(service.childrenLoads, 2);
    expect(service.watchedStudentIds, ['child', 'child']);
    expect(selection.selectedStudentIds, ['child', 'child']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.controller.add([_request(_firstChild)]);
    await tester.pumpAndSettle();

    expect(find.text('Primer estudiante — Cuarto A'), findsOneWidget);
    expect(find.text('Total: 1'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.text('No hay solicitudes'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reintento recupera fallo al consultar los hijos iniciales', (
    tester,
  ) async {
    final service = _Authorizations()
      ..children = [_firstChild]
      ..childrenError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'PERMISSION_DENIED: Missing or insufficient permissions.',
      );
    addTearDown(service.close);
    await tester.pumpWidget(
      _host(
        AuthorizationStudentScreen(
          service: service,
          activeStudentService: _SelectChild(),
        ),
        'Familiar',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(
      find.text('No tienes permiso para realizar esta operación.'),
      findsOneWidget,
    );
    expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
    expect(find.text('No hay solicitudes'), findsNothing);
    expect(service.watchedStudentIds, isEmpty);

    service.childrenError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(service.childrenLoads, 2);
    expect(service.watchedStudentIds, ['child']);
    service.controller.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No hay solicitudes'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('familiar sin hijos no consulta solicitudes ni queda cargando', (
    tester,
  ) async {
    final service = _Authorizations();
    final selection = _SelectChild();
    addTearDown(service.close);
    await tester.pumpWidget(
      _host(
        AuthorizationStudentScreen(
          service: service,
          activeStudentService: selection,
        ),
        'Familiar',
      ),
    );
    await tester.pumpAndSettle();
    expect(service.childrenLoads, 1);
    expect(service.watchedStudentIds, isEmpty);
    expect(selection.selectedStudentIds, isEmpty);
    expect(find.text('No hay solicitudes'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    expect(find.text('Sin estudiantes'), findsOneWidget);
    expect(
      find.text('No se encontraron estudiantes vinculados.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.watchedStudentIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cambio de hijo cancela la consulta previa y muestra solo la nueva',
    (tester) async {
      final firstStream =
          StreamController<List<AuthorizationRequest>>.broadcast();
      final secondStream =
          StreamController<List<AuthorizationRequest>>.broadcast();
      final service = _Authorizations()
        ..children = [_firstChild, _secondChild]
        ..studentControllers.addAll({
          'child': firstStream,
          'child2': secondStream,
        });
      final selection = _SelectChild();
      final provider = _user('Familiar', studentIds: ['child', 'child2']);
      addTearDown(service.close);
      await tester.pumpWidget(
        _host(
          AuthorizationStudentScreen(
            service: service,
            activeStudentService: selection,
          ),
          'Familiar',
          userProvider: provider,
        ),
      );
      await tester.pump();
      firstStream.add([_request(_firstChild)]);
      await tester.pumpAndSettle();
      expect(find.text('Primer estudiante — Cuarto A'), findsOneWidget);
      var checkedCancellation = false;
      selection.beforeSelect = (studentId) {
        expect(studentId, 'child2');
        expect(firstStream.hasListener, isFalse);
        checkedCancellation = true;
      };

      await _chooseSecondChild(tester);
      await _pumpUntil(tester, () => checkedCancellation);
      expect(checkedCancellation, isTrue);
      expect(provider.user!.activeStudentId, 'child2');
      expect(service.watchedStudentIds, ['child', 'child2']);
      expect(firstStream.hasListener, isFalse);
      expect(secondStream.hasListener, isTrue);
      expect(find.text('Primer estudiante — Cuarto A'), findsNothing);
      firstStream.add([_request(_firstChild)]);
      secondStream.add([_request(_secondChild)]);
      await tester.pumpAndSettle();
      expect(find.text('Segundo estudiante — Quinto B'), findsOneWidget);
      expect(find.text('Primer estudiante — Cuarto A'), findsNothing);
      expect(find.text('Total: 1'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallo de cambio de hijo conserva el anterior y permite reintentar',
    (tester) async {
      final firstStream =
          StreamController<List<AuthorizationRequest>>.broadcast();
      final secondStream =
          StreamController<List<AuthorizationRequest>>.broadcast();
      final service = _Authorizations()
        ..children = [_firstChild, _secondChild]
        ..studentControllers.addAll({
          'child': firstStream,
          'child2': secondStream,
        });
      final selection = _SelectChild()..rejectedStudentId = 'child2';
      final provider = _user('Familiar', studentIds: ['child', 'child2']);
      addTearDown(service.close);
      await tester.pumpWidget(
        _host(
          AuthorizationStudentScreen(
            service: service,
            activeStudentService: selection,
          ),
          'Familiar',
          userProvider: provider,
        ),
      );
      await tester.pump();
      firstStream.add([_request(_firstChild)]);
      await tester.pumpAndSettle();
      selection.beforeSelect = (studentId) {
        if (studentId == 'child2') expect(firstStream.hasListener, isFalse);
      };

      await _chooseSecondChild(tester);
      await _pumpUntil(tester, () => selection.selectedStudentIds.length == 2);
      await tester.pumpAndSettle();
      expect(find.text('No fue posible cambiar de estudiante'), findsOneWidget);
      expect(
        find.text('Verifica la conexión e inténtalo nuevamente.'),
        findsOneWidget,
      );
      expect(find.textContaining('UNAVAILABLE'), findsNothing);
      expect(provider.user!.activeStudentId, 'child');
      expect(service.watchedStudentIds, ['child']);
      expect(secondStream.hasListener, isFalse);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(service.watchedStudentIds, ['child', 'child']);
      expect(firstStream.hasListener, isTrue);
      firstStream.add([_request(_firstChild)]);
      await tester.pumpAndSettle();
      expect(find.text('Primer estudiante — Cuarto A'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      selection.rejectedStudentId = null;
      await _chooseSecondChild(tester);
      await _pumpUntil(tester, () => service.watchedStudentIds.length == 3);
      secondStream.add([_request(_secondChild)]);
      await tester.pumpAndSettle();
      expect(provider.user!.activeStudentId, 'child2');
      expect(service.watchedStudentIds, ['child', 'child', 'child2']);
      expect(find.text('Segundo estudiante — Quinto B'), findsOneWidget);
      expect(find.text('Primer estudiante — Cuarto A'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('administrador con lista vacía termina carga sin modal', (
    tester,
  ) async {
    final service = _Authorizations();
    addTearDown(service.close);
    await tester.pumpWidget(
      _host(AuthorizationAdminScreen(service: service), 'Administrador'),
    );
    await tester.pump();
    expect(service.watchedAdminScopes, ['i/c']);
    service.controller.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No hay solicitudes'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Reintentar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'administrador reintenta error y muestra solicitud sin excepción',
    (tester) async {
      final service = _Authorizations();
      addTearDown(service.close);
      await tester.pumpWidget(
        _host(AuthorizationAdminScreen(service: service), 'Administrador'),
      );
      await tester.pump();
      service.controller.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('No hay solicitudes'), findsNothing);
      expect(find.textContaining('permission-denied'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(service.watchedAdminScopes, ['i/c', 'i/c']);
      service.controller.add([_request(_firstChild)]);
      await tester.pumpAndSettle();
      expect(find.text('Solicitante: Familiar de prueba'), findsOneWidget);
      expect(
        find.textContaining('Primer estudiante — Cuarto A'),
        findsOneWidget,
      );
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('docente muestra solicitud real sin errores de superficie', (
    tester,
  ) async {
    final service = _Authorizations();
    addTearDown(service.close);
    await tester.pumpWidget(
      _host(
        AuthorizationTeacherScreen(service: service),
        'Docente',
        groupId: 'group',
      ),
    );
    await tester.pump();
    service.controller.add([_request(_firstChild)]);
    await tester.pumpAndSettle();
    expect(find.text('Primer estudiante — Cuarto A'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('estudiante no accede aun con permiso manipulado', (
    tester,
  ) async {
    final service = _Authorizations();
    addTearDown(service.controller.close);
    await tester.pumpWidget(
      _host(AuthorizationStudentScreen(service: service), 'Estudiante'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acceso denegado.'), findsOneWidget);
    expect(find.text('Nueva'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
