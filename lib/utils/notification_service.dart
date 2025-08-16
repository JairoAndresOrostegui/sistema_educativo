import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

Future<void> enviarNotificacion({
  required List<String> tokens,
  required String titulo,
  required String cuerpo,
  String? grado,
}) async {
  try {
    // Limpieza básica de tokens y dedupe
    final cleanTokens =
        tokens
            .whereType<String>()
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList();

    if (kDebugMode) {
      /*print('[NOTIFY REQ] tokens=${cleanTokens.length} '
          'sample=${cleanTokens.take(3).toList()} '
          'title="$titulo" body="$cuerpo" grade="$grado"');*/
    }

    if (cleanTokens.isEmpty) {
      if (kDebugMode) {
        //print('[NOTIFY SKIP] No hay tokens, no se envía.');
      }
      return;
    }

    final funciones = FirebaseFunctions.instance;
    final callable = funciones.httpsCallable('enviarNotificacion');

    final resultado = await callable
        .call({
          'grado': grado,
          'tokens': cleanTokens,
          'titulo': titulo,
          'cuerpo': cuerpo,
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Timeout al enviar notificación'),
        );

    if (kDebugMode) {
      //print('[NOTIFY RES] ${resultado.data}');
    }
  } catch (e, st) {
    if (kDebugMode) {
      //print('[NOTIFY ERR] $e');
      //print(st);
    }
    rethrow;
  }
}
