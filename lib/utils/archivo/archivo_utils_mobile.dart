import 'package:open_filex/open_filex.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<void> descargarArchivoPlataforma(String url, String nombreArchivo) async {
  final ref = FirebaseStorage.instance.refFromURL(url);
  final bytes = await ref.getData();

  if (bytes == null) throw Exception('No se pudo descargar el archivo');

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$nombreArchivo');
  await file.writeAsBytes(bytes);

  final result = await OpenFilex.open(file.path);
  if (result.type != ResultType.done) {
    throw Exception('No se pudo abrir el archivo');
  }
}
