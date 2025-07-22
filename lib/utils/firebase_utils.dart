import 'package:cloud_functions/cloud_functions.dart';

Future<void> enviarNotificacionRuta({
  required List<String> tokens,
  required String titulo,
  required String cuerpo,
}) async {
  try {
    final funciones = FirebaseFunctions.instance;
    final callable = funciones.httpsCallable('enviarNotificacionRuta');

    final resultado = await callable.call({
      'tokens': tokens,
      'titulo': titulo,
      'cuerpo': cuerpo,
    });

    final data = resultado.data;
  } catch (e) {
    //Error al enviar
  }
}
