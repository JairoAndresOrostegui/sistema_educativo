import 'package:open_filex/open_filex.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> descargarArchivoPlataforma(
  Uint8List bytes,
  String nombreArchivo,
) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$nombreArchivo');
  await file.writeAsBytes(bytes);

  final result = await OpenFilex.open(file.path);
  if (result.type != ResultType.done) {
    throw Exception('No se pudo abrir el archivo');
  }
}
