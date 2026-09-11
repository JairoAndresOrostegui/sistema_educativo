// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:excel/excel.dart';

import '../models/event_models.dart';

class EventExportPlatform {
  static void export({
    required List<EventReportRow> rows,
    required DateTime from,
    required DateTime to,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'Eventos';
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.rename(defaultSheet, sheetName);
    }
    final sheet = excel[sheetName];
    sheet.appendRow([
      TextCellValue('Evento'),
      TextCellValue('Estado'),
      TextCellValue('Fecha y hora de inicio'),
      TextCellValue('Fecha y hora de finalización'),
      TextCellValue('Lugar'),
      TextCellValue('Destinatarios'),
      TextCellValue('Confirmados'),
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.title),
        TextCellValue(row.status.label),
        TextCellValue(_dateTime(row.startAt)),
        TextCellValue(_dateTime(row.endAt)),
        TextCellValue(row.location),
        IntCellValue(row.targetCount),
        IntCellValue(row.confirmedCount),
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
      ..download = 'Eventos_${_date(from)}_${_date(to)}.xlsx'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _dateTime(DateTime value) =>
      '${_date(value)} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
