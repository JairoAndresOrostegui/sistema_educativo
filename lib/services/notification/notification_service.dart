import 'package:cloud_functions/cloud_functions.dart';

Future<void> enviarNotificacion({
  required List<String> tokens,
  required String titulo,
  required String cuerpo,
  String? grado,
}) async {
  try {
    final funciones = FirebaseFunctions.instance;
    final callable = funciones.httpsCallable('enviarNotificacionRuta');

    final resultado = await callable
        .call({
          'grado': grado,
          'tokens': tokens,
          'titulo': titulo,
          'cuerpo': cuerpo,
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Timeout al enviar notificación'),
        );

    final data = resultado.data;
  } catch (e) {
    rethrow;
  }
}
