import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/modules/auth/utils/auth_error_mapper.dart';
import 'package:sistema_educativo/utils/validators.dart';

void main() {
  group('correo de acceso', () {
    test('acepta correos normales, etiquetas y dominios modernos', () {
      for (final email in [
        'docente@colegio.edu.co',
        'Padre.Apellido+acudiente@example.education',
        ' admin_1@subdominio.colegio.org ',
      ]) {
        expect(Validators.isValidEmail(email), isTrue, reason: email);
      }
    });

    test('rechaza identificadores que no son correos validos', () {
      for (final email in [
        '',
        '123456789',
        '@colegio.edu.co',
        'usuario@',
        'usuario@localhost',
        'usuario@@colegio.edu.co',
        '.usuario@colegio.edu.co',
        'usuario.@colegio.edu.co',
        'usuario..doble@colegio.edu.co',
        'usuario con espacio@colegio.edu.co',
      ]) {
        expect(Validators.isValidEmail(email), isFalse, reason: email);
      }
    });
  });

  group('mensajes de autenticacion', () {
    test('no revela si fallo el correo o la contrasena', () {
      expect(
        AuthErrorMapper.mapFirebaseCode('invalid-credential'),
        contains('No existe una cuenta'),
      );
    });

    test('el error desconocido conserva el codigo sin texto corrupto', () {
      final message = AuthErrorMapper.mapFirebaseCode('codigo-nuevo');
      expect(message, contains('iniciar sesion'));
      expect(message, contains('codigo-nuevo'));
      expect(message, isNot(contains('Ã')));
    });
  });
}
