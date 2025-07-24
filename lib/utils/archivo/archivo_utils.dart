import 'archivo_utils_mobile.dart' if (dart.library.html) 'archivo_utils_web.dart';

Future<void> descargarArchivoDesdeURL(String url, String nombreArchivo) {
  return descargarArchivoPlataforma(url, nombreArchivo);
}
