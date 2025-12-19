// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExportUtilsPlatform {
  static void exportarExcel(List<Map<String, dynamic>> historial) {
    final excel = Excel.createExcel();

    const String sheetName = 'HistorialUsuarios';
    final def = excel.getDefaultSheet();
    if (def != null && def != sheetName) {
      excel.rename(def, sheetName);
    }
    final Sheet sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('Accion'),
      TextCellValue('Nombres'),
      TextCellValue('Apellidos'),
      TextCellValue('Rol'),
      TextCellValue('Realizado por'),
      TextCellValue('Fecha'),
    ]);

    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

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

    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final blob = html.Blob([
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = 'HistorialUsuarios.xlsx'
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
