import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/authorization/authorization_request_model.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/authorization/screens/student_authorization_screen.dart';
import 'package:sistema_educativo/modules/authorization/screens/teacher_authorization_screen.dart';
import 'package:sistema_educativo/modules/authorization/services/authorization_service.dart';
import 'package:sistema_educativo/modules/user/services/active_student_service.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';

class _Authorizations implements AuthorizationService {
  final controller = StreamController<List<AuthorizationRequest>>.broadcast();
  List<ChildRef> children = [];

  @override
  Future<List<ChildRef>> getChildrenForFamily({
    required String institutionId,
    required String campusId,
    required List<String> studentIds,
  }) async => children;

  @override
  Stream<List<AuthorizationRequest>> watchForStudent({
    required String institutionId,
    required String campusId,
    required String studentId,
    int limit = 20,
  }) => controller.stream;

  @override
  Stream<List<AuthorizationRequest>> watchForGroup({
    required String institutionId,
    required String campusId,
    required String groupId,
    int limit = 20,
  }) => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SelectChild implements ActiveStudentService {
  @override
  Future<void> select({
    required UserProviderV2 userProvider,
    required String studentId,
  }) async => userProvider.setActiveStudentId(studentId);
}

Widget _host(Widget screen, String role, {String? groupId}) {
  final provider = UserProviderV2()
    ..setUser(
      userModelv2.fromFirestore({
        'role': role,
        'status': 'activo',
        'institution': 'i',
        'campus': 'c',
        'permissions': ['autorizaciones.ver'],
        'groupId': groupId,
        'activeStudentId': 'child',
        'studentIds': ['child'],
      }, 'user'),
    );
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(home: screen),
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
