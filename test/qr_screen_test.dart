import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';
import 'package:sistema_educativo/modules/qr/screens/qr_screen.dart';
import 'package:sistema_educativo/modules/qr/screens/qr_scanner_screen.dart';

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

  testWidgets('administración puede reconocer y reemplazar un QR revocado', (
    tester,
  ) async {
    final provider = UserProviderV2()
      ..setUser(
        userModelv2.fromFirestore({
          'role': 'Administrador',
          'firstName': 'Admin',
          'lastName': 'Prueba',
          'institution': 'i',
          'campus': 'c',
          'permissions': ['codigoqr.editar'],
        }, 'admin'),
      );
    final calls = <String>[];
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: QrScreen(
            manage: true,
            invoke: (name, data) async {
              calls.add(name);
              if (name == 'listarEntidadesQr') {
                return {
                  'entities': [
                    {
                      'targetType': 'user',
                      'targetId': 'student',
                      'name': 'Estudiante Prueba',
                      'role': 'Estudiante',
                      'institutionId': 'i',
                      'campusId': 'c',
                    },
                  ],
                };
              }
              if (name == 'obtenerCredencialQr') {
                return {'payload': null, 'status': 'revoked', 'revision': 3};
              }
              return {'success': true, 'status': 'active', 'revision': 4};
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estudiante Prueba'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Credencial revocada'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Revocar'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reemplazar'))
          .onPressed,
      isNotNull,
    );
    expect(calls, contains('obtenerCredencialQr'));
  });

  testWidgets('administración lee con cámara y valida en backend', (
    tester,
  ) async {
    final provider = UserProviderV2()
      ..setUser(
        userModelv2.fromFirestore({
          'role': 'Administrador',
          'firstName': 'Admin',
          'lastName': 'Prueba',
          'institution': 'i',
          'campus': 'c',
          'permissions': ['codigoqr.crear'],
        }, 'admin'),
      );
    final calls = <Map<String, dynamic>>[];
    final payload = 'LLQ1:${'b' * 43}';
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: QrScreen(
            manage: true,
            scan: (_) async => payload,
            invoke: (name, data) async {
              if (name == 'listarEntidadesQr') return {'entities': []};
              calls.add({'name': name, ...data});
              return {
                'targetType': 'user',
                'name': 'Estudiante Prueba',
                'children': [],
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leer con cámara'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(calls, contains(containsPair('name', 'resolverCredencialQr')));
    expect(calls.single['payload'], payload);
    expect(calls.single['source'], 'camera');
    expect(find.text('Estudiante Prueba'), findsOneWidget);
  });

  test('el lector solo acepta credenciales opacas institucionales', () {
    expect(isInstitutionalQrPayload('LLQ1:${'a' * 43}'), isTrue);
    expect(isInstitutionalQrPayload('  LLQ1:${'A' * 43}  '), isTrue);
    expect(isInstitutionalQrPayload('{"uid":"student"}'), isFalse);
    expect(isInstitutionalQrPayload('https://example.com'), isFalse);
    expect(isInstitutionalQrPayload('LLQ1:${'a' * 42}'), isFalse);
  });
}
