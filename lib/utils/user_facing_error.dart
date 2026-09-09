import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

const _defaultErrorMessage =
    'No fue posible completar la operación. Intenta nuevamente.';

String userFacingError(Object error, {String fallback = _defaultErrorMessage}) {
  if (error is TimeoutException) {
    return 'La operación tardó demasiado. Revisa tu conexión e intenta nuevamente.';
  }

  if (error is FirebaseFunctionsException) {
    final safeMessage = _safeMessage(error.message);
    if (safeMessage != null) return safeMessage;
    return _firebaseCodeMessage(error.code, fallback: fallback);
  }

  if (error is FirebaseAuthException) {
    return _authCodeMessage(error.code, fallback: fallback);
  }

  if (error is FirebaseException) {
    final mapped = _firebaseCodeMessage(error.code, fallback: '');
    if (mapped.isNotEmpty) return mapped;
    final safeMessage = _safeMessage(error.message);
    return safeMessage ?? fallback;
  }

  if (error is StateError) {
    final safeMessage = _safeMessage(error.message.toString());
    if (safeMessage != null) return safeMessage;
  }

  final safeMessage = _safeMessage(error.toString());
  return safeMessage ?? fallback;
}

String? _safeMessage(String? value) {
  if (value == null) return null;
  var message = value.trim();
  message = message.replaceFirst(RegExp(r'^Exception:\s*'), '');
  if (message.isEmpty || message.length > 300) return null;

  final technical = RegExp(
    r'(\[firebase_|firebase_|package:|cloudfunctions|stacktrace|#\d+\s|'
    r'error\s+(creating|editing|deleting)|https?://|\bat\s+object\b)',
    caseSensitive: false,
  );
  if (technical.hasMatch(message) || message.contains('\n#')) return null;
  return message;
}

String _firebaseCodeMessage(String code, {required String fallback}) {
  switch (code.toLowerCase()) {
    case 'unauthenticated':
    case 'user-token-expired':
      return 'Tu sesión venció. Inicia sesión nuevamente.';
    case 'permission-denied':
      return 'No tienes permiso para realizar esta operación.';
    case 'not-found':
    case 'object-not-found':
      return 'La información solicitada ya no está disponible.';
    case 'failed-precondition':
      return 'La operación no está disponible en el estado actual.';
    case 'invalid-argument':
      return 'Revisa la información ingresada e intenta nuevamente.';
    case 'already-exists':
      return 'La solicitud ya fue registrada.';
    case 'deadline-exceeded':
    case 'unavailable':
    case 'network-request-failed':
      return 'No fue posible conectarse al servicio. Intenta nuevamente.';
    case 'resource-exhausted':
      return 'El servicio alcanzó temporalmente su límite. Intenta más tarde.';
    case 'cancelled':
      return 'La operación fue cancelada.';
    default:
      return fallback;
  }
}

String _authCodeMessage(String code, {required String fallback}) {
  switch (code.toLowerCase()) {
    case 'user-token-expired':
    case 'requires-recent-login':
      return 'Tu sesión venció. Inicia sesión nuevamente.';
    case 'network-request-failed':
      return 'No fue posible conectarse. Revisa tu conexión e intenta nuevamente.';
    case 'too-many-requests':
      return 'Se realizaron demasiados intentos. Espera un momento e inténtalo de nuevo.';
    case 'weak-password':
      return 'La contraseña no cumple los requisitos de seguridad.';
    case 'email-already-in-use':
      return 'El correo ya está asociado a otra cuenta.';
    case 'invalid-email':
      return 'El correo ingresado no es válido.';
    case 'wrong-password':
    case 'invalid-credential':
    case 'user-not-found':
      return 'El correo o la contraseña no son correctos.';
    default:
      return fallback;
  }
}
