import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/utils/user_facing_error.dart';

void main() {
  group('userFacingError', () {
    test('oculta trazas y errores técnicos', () {
      expect(
        userFacingError(
          Exception(
            '[firebase_functions/internal] Error\n#0 package:app/service.dart:9',
          ),
        ),
        'No fue posible completar la operación. Intenta nuevamente.',
      );
    });

    test('conserva un mensaje funcional breve del backend', () {
      expect(
        userFacingError(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Debes cambiar la contraseña temporal.',
          ),
        ),
        'Debes cambiar la contraseña temporal.',
      );
    });

    test('traduce códigos sin mensaje seguro', () {
      expect(
        userFacingError(
          FirebaseFunctionsException(
            code: 'permission-denied',
            message: '[firebase_functions/permission-denied]',
          ),
        ),
        'No tienes permiso para realizar esta operación.',
      );
    });

    test('traduce el error Firestore de la captura incluso envuelto', () {
      const message =
          '[cloud_firestore/permission-denied] '
          'PERMISSION_DENIED: Missing or insufficient permissions.';
      for (final error in <Object>[message, Exception(message)]) {
        expect(
          userFacingError(error),
          'No tienes permiso para realizar esta operación.',
        );
      }
    });

    test('no muestra errores nativos de permisos ni detalles internos', () {
      expect(
        userFacingError(
          Exception('PERMISSION_DENIED: Missing or insufficient permissions.'),
        ),
        'No fue posible completar la operación. Intenta nuevamente.',
      );
    });
  });
}
