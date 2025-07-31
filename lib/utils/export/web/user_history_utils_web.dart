// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExportUtilsPlatform {
  static void exportarExcel(List<Map<String, dynamic>> historial) {
    final excel = Excel.createExcel();
    final sheet = excel['HistorialUsuarios'];

    sheet.appendRow([
      TextCellValue('Acción'),
      TextCellValue('Nombres'),
      TextCellValue('Apellidos'),
      TextCellValue('Rol'),
      TextCellValue('Realizado por'),
      TextCellValue('Fecha'),
    ]);

    for (final h in historial) {
      final fecha = h['fecha'];
      final fechaTexto =
          fecha != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha) : '';

      sheet.appendRow([
        TextCellValue(h['accion'] ?? ''),
        TextCellValue(h['nombres'] ?? ''),
        TextCellValue(h['apellidos'] ?? ''),
        TextCellValue(h['rol'] ?? ''),
        TextCellValue(h['realizadoPor'] ?? ''),
        TextCellValue(fechaTexto),
      ]);
    }

    final bytes = excel.encode();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor =
        html.AnchorElement(href: url)
          ..setAttribute("download", "HistorialUsuarios.xlsx")
          ..click();
    html.Url.revokeObjectUrl(url);
  }
}
