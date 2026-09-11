import 'dart:typed_data';

import 'file_utils_mobile.dart' if (dart.library.html) 'file_utils_web.dart';

Future<void> descargarArchivoDesdeBytes(Uint8List bytes, String nombreArchivo) {
  return descargarArchivoPlataforma(bytes, nombreArchivo);
}
