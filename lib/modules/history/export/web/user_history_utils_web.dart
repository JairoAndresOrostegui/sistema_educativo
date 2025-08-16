// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExportUtilsPlatform {
  static void exportarExcel(List<Map<String, dynamic>> historial) {
    final excel = Excel.createExcel();

    // Renombrar y usar la hoja por defecto para evitar "Sheet1" vacío
    final sheetName = 'HistorialUsuarios';
    final def = excel.getDefaultSheet();
    if (def != null && def != sheetName) {
      excel.rename(def, sheetName);
    }
    final Sheet sheet = excel[sheetName]!;

    // Encabezados
    sheet.appendRow([
      TextCellValue('Acción'),
      TextCellValue('Nombres'),
      TextCellValue('Apellidos'),
      TextCellValue('Rol'),
      TextCellValue('Realizado por'),
      TextCellValue('Fecha'),
    ]);

    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    // Filas
    for (final h in historial) {
      final fecha = h['fecha'];
      final fechaTexto = fecha != null ? df.format(fecha) : '';

      sheet.appendRow([
        TextCellValue(h['accion'] ?? ''),
        TextCellValue(h['nombres'] ?? ''),
        TextCellValue(h['apellidos'] ?? ''),
        TextCellValue(h['rol'] ?? ''),
        TextCellValue(h['realizadoPor'] ?? ''),
        TextCellValue(fechaTexto),
      ]);
    }

    // Eliminar 'Sheet1' si existiera
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    // Descargar
    final bytes = excel.encode();
    if (bytes == null) return;

    final blob = html.Blob([
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor =
        html.AnchorElement(href: url)
          ..download = 'HistorialUsuarios.xlsx'
          ..click();
    html.Url.revokeObjectUrl(url);
  }
}
