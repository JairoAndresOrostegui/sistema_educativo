abstract final class AuthAccessPolicy {
  static const Set<String> allowedRoles = {
    'Administrador',
    'Docente',
    'Estudiante',
    'Familiar',
  };

  static const Set<String> _commonPaths = {
    '/profile',
    '/logout',
    '/access_denied',
  };

  static Set<String> normalizePermissions(Iterable<Object?> permissions) {
    return permissions
        .map((permission) => permission?.toString().trim().toLowerCase() ?? '')
        .where((permission) => permission.isNotEmpty)
        .toSet();
  }

  static bool requiresEmailVerification(String? role) {
    return role?.trim().toLowerCase() != 'estudiante';
  }

  static bool isAllowedRole(String? role) {
    return allowedRoles.contains(role?.trim());
  }

  static bool isActiveStatus(String? status) {
    return status?.trim().toLowerCase() == 'activo';
  }

  static String homeForRole(String? role) {
    switch (role?.trim()) {
      case 'Administrador':
        return '/admin_dashboard';
      case 'Docente':
        return '/teacher_dashboard';
      case 'Estudiante':
      case 'Familiar':
        return '/student_dashboard';
      default:
        return '/access_denied';
    }
  }

  static bool isPathAllowed({
    required String? role,
    required bool isSuperadmin,
    required Iterable<Object?> permissions,
    required String path,
    required bool isWeb,
  }) {
    if (_commonPaths.contains(path)) return true;

    final normalizedRole = role?.trim();
    final perms = normalizePermissions(permissions);
    bool has(String permission) =>
        isSuperadmin || perms.contains(permission.toLowerCase());

    switch (normalizedRole) {
      case 'Administrador':
        if (path == '/admin_dashboard' || path == '/admin_parameters') {
          return true;
        }
        return switch (path) {
          '/admin_user' => has('usuarios.ver'),
          '/management_route' => has('rutas.ver'),
          '/management_schedule' =>
            has('horarios.ver') ||
                has('horarios.crear') ||
                has('horarios.editar') ||
                has('horarios.eliminar'),
          '/management_document' => has('archivos.ver'),
          '/view_history' => has('historial_rutas.ver'),
          '/admin_authorization' =>
            has('autorizaciones.ver') || has('autorizaciones.editar'),
          '/enrollment' => has('matricula.ver') || has('matricula.editar'),
          '/admin_qr' => has('codigoqr.crear') || has('codigoqr.editar'),
          '/messages' => has('mensajeria.ver'),
          '/website_admin' =>
            isWeb && (has('sitio_web.ver') || has('sitio_web.editar')),
          '/website_messages' => isWeb && has('sitio_web.editar'),
          _ => false,
        };
      case 'Docente':
        if (path == '/teacher_dashboard') return true;
        return switch (path) {
          '/admin_user' => has('usuarios.ver') || has('usuarios.editar'),
          '/execute_route' => has('rutas.ver'),
          '/teacher_schedule' => has('horarios.ver'),
          '/teacher_document' => has('archivos.ver'),
          '/teacher_authorization' => has('autorizaciones.ver'),
          '/enrollment' => has('matricula.ver') || has('matricula.editar'),
          '/messages' => has('mensajeria.ver'),
          _ => false,
        };
      case 'Estudiante':
      case 'Familiar':
        if (path == '/student_dashboard') return true;
        return switch (path) {
          '/my_route' => has('rutas.ver'),
          '/my_schedule' => has('horarios.ver'),
          '/student_document' => has('archivos.ver'),
          '/student_authorization' =>
            normalizedRole == 'Familiar' && has('autorizaciones.ver'),
          '/enrollment' => normalizedRole == 'Familiar' && has('matricula.ver'),
          '/messages' => has('mensajeria.ver'),
          '/student_qr' => normalizedRole == 'Familiar',
          _ => false,
        };
      default:
        return false;
    }
  }
}
