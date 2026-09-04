// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class ExportUtilsPlatform {
  static void exportarExcel(List<Map<String, dynamic>> logs) {
    final excel = Excel.createExcel();

    const sheetName = 'HistorialLogsUsuarios';
    final def = excel.getDefaultSheet();
    if (def != null && def != sheetName) {
      excel.rename(def, sheetName);
    }
    final Sheet sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('Nombre'),
      TextCellValue('Rol'),
      TextCellValue('Evento'),
      TextCellValue('Campus'),
      TextCellValue('Institucion'),
      TextCellValue('Grupo'),
      TextCellValue('Fecha'),
    ]);

    DateTime? asDateTime(dynamic raw) {
      if (raw is DateTime) return raw;
      if (raw is Timestamp) return raw.toDate();
      if (raw is num) {
        final v = raw.toDouble().abs();
        if (v > 1e14) {
          return DateTime.fromMicrosecondsSinceEpoch(raw.toInt());
        }
        if (v > 1e11) {
          return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
        }
        return DateTime.fromMillisecondsSinceEpoch((raw * 1000).toInt());
      }
      if (raw is String && raw.isNotEmpty) {
        try {
          return DateTime.parse(raw);
        } catch (_) {}
      }
      return null;
    }

    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final log in logs) {
      final fecha = asDateTime(log['timestamp']);
      final fechaTexto = fecha != null ? df.format(fecha) : '';

      sheet.appendRow([
        TextCellValue((log['fullName'] ?? '').toString()),
        TextCellValue((log['role'] ?? '').toString()),
        TextCellValue((log['event'] ?? '').toString()),
        TextCellValue((log['campus'] ?? '').toString()),
        TextCellValue((log['institution'] ?? '').toString()),
        TextCellValue((log['groupName'] ?? '').toString()),
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
      ..download = 'HistorialLogsUsuarios.xlsx'
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
