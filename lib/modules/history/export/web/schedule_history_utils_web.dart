// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class ExportUtilsPlatform {
  static void exportarExcel(List<Map<String, dynamic>> logs) {
    final excel = Excel.createExcel();

    final sheetName = 'HistorialHorarios';
    final def = excel.getDefaultSheet();
    if (def != null && def != sheetName) {
      excel.rename(def, sheetName);
    }
    final Sheet sheet = excel[sheetName]!;

    sheet.appendRow([
      TextCellValue('Grado'),
      TextCellValue('Día'),
      TextCellValue('Materia'),
      TextCellValue('Acción'),
      TextCellValue('Usuario'),
      TextCellValue('Fecha'),
    ]);

    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final log in logs) {
      final raw = log['fecha'];
      DateTime? fecha;
      if (raw is DateTime) {
        fecha = raw;
      } else if (raw is Timestamp) {
        fecha = raw.toDate();
      } else if (raw is num) {
        final ms = raw.abs() > 1e12 ? raw ~/ 1000 : raw;
        fecha = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
      } else if (raw is String && raw.isNotEmpty) {
        try {
          fecha = DateTime.parse(raw);
        } catch (_) {}
      }
      final fechaTexto = fecha != null ? df.format(fecha) : '';

      sheet.appendRow([
        TextCellValue(log['grado']?.toString() ?? ''),
        TextCellValue(log['dia']?.toString() ?? ''),
        TextCellValue(log['materia']?.toString() ?? ''),
        TextCellValue(log['accion']?.toString() ?? ''),
        TextCellValue(log['usuarioNombre']?.toString() ?? ''),
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
    final anchor =
        html.AnchorElement(href: url)
          ..download = 'HistorialHorarios.xlsx'
          ..click();
    html.Url.revokeObjectUrl(url);
  }
}
