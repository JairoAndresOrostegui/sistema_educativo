// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExportUtilsPlatform {
  static void exportarExcel(List<Map<String, dynamic>> logs) {
    final excel = Excel.createExcel();
    final sheet = excel['HistorialDocumentos'];

    sheet.appendRow([
      TextCellValue('Nombre del archivo'),
      TextCellValue('Grado'),
      TextCellValue('Subido por'),
      TextCellValue('Fecha de subida'),
    ]);

    for (final log in logs) {
      final fecha = log['fechaSubida'];
      final fechaTexto =
          fecha != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha) : '';

      sheet.appendRow([
        TextCellValue(log['nombre'] ?? ''),
        TextCellValue(log['grado'] ?? ''),
        TextCellValue(log['subidoPor'] ?? ''),
        TextCellValue(fechaTexto),
      ]);
    }

    final bytes = excel.encode();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor =
        html.AnchorElement(href: url)
          ..setAttribute("download", "HistorialDocumentos.xlsx")
          ..click();
    html.Url.revokeObjectUrl(url);
  }
}
