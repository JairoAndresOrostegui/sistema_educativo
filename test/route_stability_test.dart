import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/modules/route/utils/route_ui_helpers.dart';

void main() {
  group('Rutas presenta estados seguros', () {
    test(
      'distingue preparación, recorrido, cierre, cancelación y dato inválido',
      () {
        expect(routeStatusLabel('pendiente'), 'Preparado · aún no ha iniciado');
        expect(routeStatusLabel('activa'), 'Recorrido en curso');
        expect(routeStatusLabel('finalizada'), 'Recorrido finalizado');
        expect(routeStatusLabel('cancelada'), 'Recorrido cancelado');
        expect(routeStatusLabel(42), 'Estado del recorrido no disponible');
      },
    );

    test('explica cada motivo por el que el mapa no se muestra', () {
      String message({
        Object? status = 'activa',
        bool travels = true,
        bool picked = false,
        bool absent = false,
        bool enabled = false,
      }) => routeMapUnavailableMessage(
        routeStatus: status,
        travelsToday: travels,
        pickedUp: picked,
        absent: absent,
        mapEnabled: enabled,
      );

      expect(message(status: 'pendiente'), contains('todavía no ha iniciado'));
      expect(message(status: 'finalizada'), contains('terminó'));
      expect(message(status: 'cancelada'), contains('cancelado'));
      expect(message(picked: true), contains('recogida ya fue registrada'));
      expect(message(absent: true), contains('no viaja'));
      expect(message(travels: false), contains('no viaja'));
      expect(message(), contains('10 minutos'));
      expect(message(enabled: true), contains('ubicación reciente'));
      expect(message(status: null), contains('determinar el estado'));
    });

    test('errores desconocidos no exponen excepciones ni trazas', () {
      final message = routeErrorMessage(
        Exception('[firebase_functions/internal] fallo\n#0 stack'),
      );
      expect(
        message,
        'No fue posible completar la operación. Intenta nuevamente.',
      );
      expect(message, isNot(contains('firebase_functions')));
      expect(message, isNot(contains('#0')));
      expect(
        routeErrorMessage(StateError('Activa el GPS para continuar.')),
        'Activa el GPS para continuar.',
      );
    });

    test('datos inesperados usan etiquetas controladas', () {
      expect(routeText(null, fallback: 'Ruta escolar'), 'Ruta escolar');
      expect(routeText(500, fallback: 'Ruta escolar'), 'Ruta escolar');
      expect(routeText('  Norte  '), 'Norte');
    });
  });
}
