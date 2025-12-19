import 'package:universal_html/html.dart' as html;

Future<void> descargarArchivoPlataforma(String url, String nombreArchivo) async {
  html.AnchorElement(href: url)
    ..setAttribute('download', nombreArchivo)
    ..click();
}
