// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExportUtilsPlatform {
  static void exportarExcel(List<Map<String, dynamic>> logs) {
    final excel = Excel.createExcel();
    final sheet = excel['HistorialHorarios'];

    sheet.appendRow([
      TextCellValue('Grado'),
      TextCellValue('Día'),
      TextCellValue('Materia'),
      TextCellValue('Acción'),
      TextCellValue('Usuario'),
      TextCellValue('Fecha'),
    ]);

    for (final log in logs) {
      final fecha = log['fecha']?.toDate();
      final fechaTexto =
          fecha != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha) : '';

      sheet.appendRow([
        TextCellValue(log['grado'] ?? ''),
        TextCellValue(log['dia'] ?? ''),
        TextCellValue(log['materia'] ?? ''),
        TextCellValue(log['accion'] ?? ''),
        TextCellValue(log['usuarioNombre'] ?? ''),
        TextCellValue(fechaTexto),
      ]);
    }

    final bytes = excel.encode();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor =
        html.AnchorElement(href: url)
          ..setAttribute("download", "HistorialHorarios.xlsx")
          ..click();
    html.Url.revokeObjectUrl(url);
  }
}
