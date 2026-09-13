import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/modules/route/widgets/route_qr_pickup_button.dart';

void main() {
  final prepared = {
    'dailyRouteId': 'daily',
    'studentId': 'student',
    'studentName': 'Estudiante de prueba',
    'routeName': 'Ruta de prueba',
    'credentialRevision': 2,
    'identificationOnly': true,
  };
  testWidgets('leer QR prepara y cancelar nunca registra recogida', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteQrPickupButton(
            dailyRouteId: 'daily',
            scan: (_) async => 'LLQ1:${'a' * 43}',
            invoke: (name, data) async {
              calls.add(name);
              return prepared;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Recogida con QR'));
    await tester.pumpAndSettle();
    expect(calls, ['prepararRecogidaQr']);
    expect(find.text('Confirmar recogida'), findsOneWidget);
    expect(find.text('Estudiante de prueba'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, ['prepararRecogidaQr']);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'confirmación reintenta el mismo requestId sin volver a escanear',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final operations = <Map<String, dynamic>>[];
      var scans = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteQrPickupButton(
              dailyRouteId: 'daily',
              scan: (_) async {
                scans++;
                return 'LLQ1:${'a' * 43}';
              },
              invoke: (name, data) async {
                if (name == 'prepararRecogidaQr') return prepared;
                expect(name, 'operarRecorrido');
                operations.add(data);
                if (operations.length == 1) {
                  throw FirebaseFunctionsException(
                    code: 'unavailable',
                    message: 'INTERNAL transport detail',
                  );
                }
                return {'ok': true};
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Recogida con QR'));
      await tester.pumpAndSettle();
      expect(operations, isEmpty);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('INTERNAL'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(scans, 1);
      expect(operations, hasLength(2));
      expect(operations[0]['requestId'], operations[1]['requestId']);
      expect(operations[1]['command'], 'pickup');
      expect(operations[1]['studentId'], 'student');
      expect(operations[1]['identification']['credentialRevision'], 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('QR ajeno muestra error amigable sin habilitar confirmación', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteQrPickupButton(
            dailyRouteId: 'daily',
            scan: (_) async => 'LLQ1:${'a' * 43}',
            invoke: (name, data) async {
              calls.add(name);
              throw FirebaseFunctionsException(
                code: 'permission-denied',
                message: 'PERMISSION_DENIED',
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Recogida con QR'));
    await tester.pumpAndSettle();
    expect(calls, ['prepararRecogidaQr']);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('No tienes permiso para realizar esta operación.'),
      findsOneWidget,
    );
    expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
