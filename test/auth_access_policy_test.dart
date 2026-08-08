import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/modules/auth/utils/auth_access_policy.dart';

void main() {
  group('verificacion de correo por rol', () {
    test('los estudiantes nunca requieren correo verificado', () {
      expect(AuthAccessPolicy.requiresEmailVerification('Estudiante'), isFalse);
      expect(
        AuthAccessPolicy.requiresEmailVerification(' estudiante '),
        isFalse,
      );
    });

    test('adultos y roles desconocidos requieren correo verificado', () {
      for (final role in ['Administrador', 'Docente', 'Familiar', '', null]) {
        expect(
          AuthAccessPolicy.requiresEmailVerification(role),
          isTrue,
          reason: 'rol: $role',
        );
      }
    });
  });

  group('roles y pagina inicial', () {
    test('ningun rol puede iniciar sesion con estado no activo', () {
      expect(AuthAccessPolicy.isActiveStatus(' activo '), isTrue);
      for (final status in ['inactivo', 'eliminado', 'eliminando', '', null]) {
        expect(
          AuthAccessPolicy.isActiveStatus(status),
          isFalse,
          reason: 'estado: $status',
        );
      }
    });

    test('solo acepta los cuatro roles configurados', () {
      for (final role in AuthAccessPolicy.allowedRoles) {
        expect(AuthAccessPolicy.isAllowedRole(role), isTrue);
      }
      expect(AuthAccessPolicy.isAllowedRole('Rector'), isFalse);
      expect(AuthAccessPolicy.isAllowedRole('administrador'), isFalse);
      expect(AuthAccessPolicy.isAllowedRole(null), isFalse);
    });

    test('redirige cada rol a su tablero', () {
      expect(AuthAccessPolicy.homeForRole('Administrador'), '/admin_dashboard');
      expect(AuthAccessPolicy.homeForRole('Docente'), '/teacher_dashboard');
      expect(AuthAccessPolicy.homeForRole('Estudiante'), '/student_dashboard');
      expect(AuthAccessPolicy.homeForRole('Familiar'), '/student_dashboard');
      expect(AuthAccessPolicy.homeForRole('Rector'), '/access_denied');
    });
  });

  group('acceso por rutas y permisos', () {
    bool allowed({
      required String role,
      required String path,
      List<String> permissions = const [],
      bool superadmin = false,
      bool web = true,
    }) {
      return AuthAccessPolicy.isPathAllowed(
        role: role,
        isSuperadmin: superadmin,
        permissions: permissions,
        path: path,
        isWeb: web,
      );
    }

    test(
      'todos los usuarios autenticados pueden ver solo su perfil y salir',
      () {
        for (final role in AuthAccessPolicy.allowedRoles) {
          expect(allowed(role: role, path: '/profile'), isTrue);
          expect(allowed(role: role, path: '/logout'), isTrue);
        }
      },
    );

    test('un administrador no salta la matriz escribiendo la URL', () {
      expect(allowed(role: 'Administrador', path: '/admin_dashboard'), isTrue);
      expect(allowed(role: 'Administrador', path: '/admin_user'), isFalse);
      expect(
        allowed(role: 'Administrador', path: '/management_route'),
        isFalse,
      );
      expect(allowed(role: 'Administrador', path: '/messages'), isFalse);
      expect(allowed(role: 'Administrador', path: '/website_admin'), isFalse);
    });

    test('cada permiso administrativo habilita unicamente su modulo', () {
      const cases = {
        'usuarios.ver': '/admin_user',
        'rutas.ver': '/management_route',
        'horarios.ver': '/management_schedule',
        'archivos.ver': '/management_document',
        'historial_rutas.ver': '/view_history',
        'autorizaciones.ver': '/admin_authorization',
        'matricula.ver': '/enrollment',
        'codigoqr.crear': '/admin_qr',
        'mensajeria.ver': '/messages',
        'sitio_web.ver': '/website_admin',
        'sitio_web.editar': '/website_messages',
      };
      for (final entry in cases.entries) {
        expect(
          allowed(
            role: 'Administrador',
            path: entry.value,
            permissions: [entry.key.toUpperCase()],
          ),
          isTrue,
          reason: entry.key,
        );
      }
    });

    test('las pantallas del sitio administrativo solo existen en web', () {
      expect(
        allowed(
          role: 'Administrador',
          path: '/website_admin',
          permissions: const ['sitio_web.ver'],
          web: false,
        ),
        isFalse,
      );
      expect(
        allowed(
          role: 'Administrador',
          path: '/website_messages',
          permissions: const ['sitio_web.editar'],
          web: false,
        ),
        isFalse,
      );
    });

    test('el superadmin accede a los modulos administrativos', () {
      for (final path in [
        '/admin_user',
        '/management_route',
        '/management_schedule',
        '/management_document',
        '/view_history',
        '/admin_authorization',
        '/enrollment',
        '/admin_qr',
        '/messages',
        '/website_admin',
        '/website_messages',
      ]) {
        expect(
          allowed(role: 'Administrador', path: path, superadmin: true),
          isTrue,
          reason: path,
        );
      }
    });

    test('docente solo entra a sus modulos expresamente asignados', () {
      expect(allowed(role: 'Docente', path: '/execute_route'), isFalse);
      expect(
        allowed(
          role: 'Docente',
          path: '/execute_route',
          permissions: const [' rutas.ver '],
        ),
        isTrue,
      );
      expect(
        allowed(
          role: 'Docente',
          path: '/admin_user',
          permissions: const ['usuarios.ver'],
        ),
        isTrue,
      );
      expect(allowed(role: 'Docente', path: '/admin_user'), isFalse);
      expect(
        allowed(
          role: 'Docente',
          path: '/admin_user',
          permissions: const ['usuarios.editar'],
        ),
        isTrue,
      );
      expect(allowed(role: 'Docente', path: '/enrollment'), isFalse);
      expect(
        allowed(
          role: 'Docente',
          path: '/enrollment',
          permissions: const ['matricula.editar'],
        ),
        isTrue,
      );
    });

    test('estudiante y familiar no acceden a rutas de otros roles', () {
      for (final role in ['Estudiante', 'Familiar']) {
        expect(
          allowed(
            role: role,
            path: '/my_schedule',
            permissions: const ['horarios.ver'],
          ),
          isTrue,
        );
        expect(
          allowed(
            role: role,
            path: '/admin_user',
            permissions: const ['usuarios.ver'],
          ),
          isFalse,
        );
        expect(allowed(role: role, path: '/teacher_dashboard'), isFalse);
      }
    });

    test('solo el familiar puede abrir la solicitud de matricula', () {
      expect(
        allowed(
          role: 'Familiar',
          path: '/enrollment',
          permissions: const ['matricula.ver'],
        ),
        isTrue,
      );
      expect(
        allowed(
          role: 'Estudiante',
          path: '/enrollment',
          permissions: const ['matricula.ver'],
        ),
        isFalse,
      );
    });

    test('autorizaciones excluye estudiantes y usa ver para familiares', () {
      expect(
        allowed(
          role: 'Familiar',
          path: '/student_authorization',
          permissions: const ['autorizaciones.ver'],
        ),
        isTrue,
      );
      expect(
        allowed(
          role: 'Estudiante',
          path: '/student_authorization',
          permissions: const ['autorizaciones.ver'],
        ),
        isFalse,
      );
      expect(
        allowed(
          role: 'Administrador',
          path: '/admin_authorization',
          permissions: const ['autorizaciones.editar'],
        ),
        isTrue,
      );
    });

    test('el QR de acudiente no se expone al estudiante', () {
      expect(allowed(role: 'Estudiante', path: '/student_qr'), isFalse);
      expect(allowed(role: 'Familiar', path: '/student_qr'), isTrue);
    });
  });
}
