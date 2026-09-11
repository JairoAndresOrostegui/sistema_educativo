import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/user/screens/admin_users_screen.dart';
import 'package:sistema_educativo/modules/user/services/user_service_v2.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';

class _Users implements UserServiceV2 {
  final scopes = <String>[];

  @override
  Future<List<userModelv2>> obtenerTodos({
    required String institutionId,
    required String campusId,
    bool isSuperadmin = false,
  }) async {
    scopes.add('$institutionId/$campusId/$isSuperadmin');
    return [_person('student', 'Estudiante', 'Estudiante de prueba')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

userModelv2 _person(String id, String role, String name) =>
    userModelv2.fromFirestore({
      'firstName': name,
      'lastName': 'Llinás',
      'personalEmail': '$id@example.test',
      'role': role,
      'institution': 'institution',
      'campus': 'campus',
      'status': 'activo',
      'permissions': ['usuarios.ver'],
    }, id);

void main() {
  for (final width in [320.0, 1000.0]) {
    testWidgets('populated user tiles have visible ink at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final users = _Users();
      final provider = UserProviderV2()
        ..setUser(_person('admin', 'Administrador', 'Administración'));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(home: AdminUsersScreen(userService: users)),
        ),
      );
      await tester.pumpAndSettle();

      expect(users.scopes, ['institution/campus/false']);
      expect(find.text('Estudiante de prueba Llinás'), findsOneWidget);
      expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNotNull);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'no coincide');
      await tester.pump();
      expect(find.byType(ListTile), findsNothing);
      await tester.enterText(find.byType(TextField), 'estudiante');
      await tester.pump();
      expect(find.text('Estudiante de prueba Llinás'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
