import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/modules/profile/services/profile_photo_commit.dart';

void main() {
  test('fallar limpieza anterior nunca elimina foto ya confirmada', () async {
    var discarded = false;
    await commitProfilePhoto(
      confirm: () async => 'previous',
      discardUpload: () async => discarded = true,
      cleanupPrevious: (previous) async {
        expect(previous, 'previous');
        throw StateError('storage unavailable');
      },
    );
    expect(discarded, isFalse);
  });

  test(
    'respuesta perdida conserva foto que el servidor pudo confirmar',
    () async {
      var discarded = false;
      await expectLater(
        commitProfilePhoto(
          confirm: () async => throw FirebaseFunctionsException(
            code: 'unavailable',
            message: '',
          ),
          discardUpload: () async => discarded = true,
          cleanupPrevious: (_) async => fail('No hay confirmación conocida'),
        ),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(discarded, isFalse);
    },
  );

  test('rechazo definitivo permite compensar la carga no confirmada', () async {
    var discarded = false;
    await expectLater(
      commitProfilePhoto(
        confirm: () async => throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: '',
        ),
        discardUpload: () async => discarded = true,
        cleanupPrevious: (_) async => fail('No debe borrar la foto anterior'),
      ),
      throwsA(isA<FirebaseFunctionsException>()),
    );
    expect(discarded, isTrue);
  });
}
