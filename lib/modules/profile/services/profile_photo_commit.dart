import 'package:cloud_functions/cloud_functions.dart';

/// Una respuesta de red perdida no prueba que el servidor haya rechazado la
/// foto: nunca borrar el objeto que podría estar referenciado por el perfil.
Future<void> commitProfilePhoto({
  required Future<String> Function() confirm,
  required Future<void> Function() discardUpload,
  required Future<void> Function(String previousUrl) cleanupPrevious,
}) async {
  late final String previousUrl;
  try {
    previousUrl = await confirm();
  } on FirebaseFunctionsException catch (error) {
    const definitiveRejections = {
      'invalid-argument',
      'permission-denied',
      'unauthenticated',
      'not-found',
      'failed-precondition',
    };
    if (definitiveRejections.contains(error.code)) {
      try {
        await discardUpload();
      } catch (_) {
        // Conservar la causa inicial. Nunca intentar borrar otra referencia.
      }
    }
    rethrow;
  }

  try {
    await cleanupPrevious(previousUrl);
  } catch (_) {
    // El perfil ya se confirmó. La limpieza anterior es recuperable; su fallo
    // no debe eliminar la nueva foto ni informar que no se guardó el perfil.
  }
}
