// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExportUtilsPlatform {
  static void exportarExcel(List<Map<String, dynamic>> logs) {
    final excel = Excel.createExcel();

    // Renombrar y usar la hoja por defecto
    const String sheetName = 'HistorialDocumentos';
    final def = excel.getDefaultSheet();
    if (def != null && def != sheetName) {
      excel.rename(def, sheetName);
    }
    final Sheet sheet = excel[sheetName]!;

    sheet.appendRow([
      TextCellValue('Nombre del archivo'),
      TextCellValue('Grado'),
      TextCellValue('Subido por'),
      TextCellValue('Fecha de subida'),
    ]);

    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final log in logs) {
      final fecha = log['fechaSubida'];
      final fechaTexto = fecha != null ? df.format(fecha) : '';

      sheet.appendRow([
        TextCellValue(log['nombre'] ?? ''),
        TextCellValue(log['grado'] ?? ''),
        TextCellValue(log['subidoPor'] ?? ''),
        TextCellValue(fechaTexto),
      ]);
    }

    // Por seguridad elimina Sheet1 si existiera
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final blob = html.Blob([
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor =
        html.AnchorElement(href: url)
          ..download = 'HistorialDocumentos.xlsx'
          ..click();
    html.Url.revokeObjectUrl(url);
  }
}
