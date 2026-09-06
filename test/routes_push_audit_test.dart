import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/models/route/route_model.dart';
import 'package:sistema_educativo/modules/route/widgets/teacher/teacher_route_header.dart';
import 'package:sistema_educativo/utils/notification_tokens.dart';
import 'package:sistema_educativo/widgets/push_preferences.dart';

void main() {
  test('Tokens: ninguno, solo movil, solo web, ambos y duplicados', () {
    expect(extractNotificationTokens({}), isEmpty);
    expect(
      extractNotificationTokens({
        'notificationTokens': {'mobile': 'm'},
      }),
      ['m'],
    );
    expect(
      extractNotificationTokens({
        'notificationTokens': {'web': 'w'},
      }),
      ['w'],
    );
    expect(
      extractNotificationTokens({
        'notificationTokens': {'web': 'w', 'mobile': 'm'},
      }),
      ['w', 'm'],
    );
    expect(
      extractNotificationTokens({
        'notificationTokens': {'web': 'same', 'mobile': 'same'},
      }),
      ['same'],
    );
  });

  testWidgets('Selector de ruta largo no desborda a 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const route = RouteModel(
      id: 'audit',
      name: 'Ruta de recogida de estudiantes sector norte de Piedecuesta',
      startAddress: 'Direccion ficticia',
      students: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TeacherRouteHeader(
              routes: const [route],
              selected: route,
              onRouteChanged: (_) {},
              showGrouping: true,
              groupSameAddress: false,
              onToggleGrouping: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'El selector debe adaptarse al ancho móvil.',
    );
  });

  testWidgets('Control de notificaciones visible a 320 px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: PushPreferences())),
      ),
    );
    expect(find.text('Notificaciones en este equipo'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
