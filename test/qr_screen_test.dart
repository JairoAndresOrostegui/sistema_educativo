import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';
import 'package:sistema_educativo/modules/qr/screens/qr_screen.dart';

void main() {
  testWidgets('QR familiar permite elegir hijo y desplazarse a 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = UserProviderV2()
      ..setUser(
        userModelv2.fromFirestore({
          'role': 'Familiar',
          'firstName': 'Familiar de prueba',
          'lastName': 'Con un nombre largo para probar diseño adaptable',
          'institution': 'i',
          'campus': 'c',
          'studentIds': ['child'],
        }, 'family'),
      );
    final calls = <String>[];
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: QrScreen(
            invoke: (name, data) async {
              calls.add(name);
              if (name == 'obtenerHijosVinculados') {
                return {
                  'children': [
                    {
                      'id': 'child',
                      'firstName': 'Hijo',
                      'lastName': 'Prueba',
                      'groupName': 'Cuarto A',
                    },
                  ],
                };
              }
              return {'payload': 'LLQ1:${'a' * 43}'};
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Hijo Prueba'));
    await tester.tap(find.text('Hijo Prueba'));
    await tester.pumpAndSettle();
    expect(provider.user!.activeStudentId, 'child');
    expect(calls, contains('seleccionarHijoActivo'));
    await tester.ensureVisible(find.byType(QrImageView));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
