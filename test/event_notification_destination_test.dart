import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/utils/notification_destination.dart';

void main() {
  test(
    'el aviso abre la ficha del evento, sin cambiar el hijo seleccionado',
    () {
      expect(
        notificationDestination({'type': 'event', 'eventId': 'evento-qa'}),
        '/events?eventId=evento-qa',
      );
    },
  );
  test('avisos anteriores o identificadores inválidos abren la lista', () {
    for (final value in [null, '', '  ', 42, '../private', 'a' * 161]) {
      expect(
        notificationDestination({'type': 'event', 'eventId': value}),
        '/events',
      );
    }
  });
  test('el identificador no puede inyectar otra ruta ni parámetros', () {
    final route = notificationDestination({
      'type': 'event',
      'eventId': 'evento?otro=valor&x=1',
    });
    final uri = Uri.parse(route!);
    expect(uri.path, '/events');
    expect(uri.queryParameters, {'eventId': 'evento?otro=valor&x=1'});
  });
}
