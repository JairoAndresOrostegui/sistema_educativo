import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

Future<void> descargarArchivoPlataforma(
  Uint8List bytes,
  String nombreArchivo,
) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', nombreArchivo)
    ..style.display = 'none';
  try {
    html.document.body?.append(anchor);
    anchor.click();
  } finally {
    anchor.remove();
    // Dejar que el navegador inicie la transferencia antes de revocar el Blob.
    Future<void>.delayed(const Duration(seconds: 30), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}
