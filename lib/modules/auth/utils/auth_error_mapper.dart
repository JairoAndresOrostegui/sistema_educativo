class AuthErrorMapper {
  static const Map<String, String> _firebaseMessages = {
    'invalid-credential':
        'No existe una cuenta con ese correo o la contrasena es incorrecta.',
    'wrong-password': 'Contrasena incorrecta.',
    'user-disabled': 'La cuenta esta deshabilitada.',
    'too-many-requests': 'Demasiados intentos. Intenta mas tarde.',
    'network-request-failed': 'Error de red. Verifica tu conexion.',
  };

  static String mapFirebaseCode(String code) {
    return _firebaseMessages[code] ??
        'Ocurrio un error al iniciar sesión. Codigo: $code';
  }

  static const String lockMessage =
      'Cuenta bloqueada por intentos fallidos. Intenta de nuevo en 15 minutos.';
  static const String missingTenantMessage =
      'El usuario no tiene institucion o campus configurado. Contacte al administrador.';
  static const String invalidRoleMessage =
      'Rol de usuario no permitido en esta aplicacion.';
}
