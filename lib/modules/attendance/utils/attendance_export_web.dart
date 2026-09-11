// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:excel/excel.dart';

import '../models/attendance_models.dart';

class AttendanceExportPlatform {
  static void export(AttendanceReport report) {
    final excel = Excel.createExcel();
    const sheetName = 'Asistencia';
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.rename(defaultSheet, sheetName);
    }
    final sheet = excel[sheetName];
    sheet.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Grupo'),
      TextCellValue('Asignatura'),
      TextCellValue('Estudiante'),
      TextCellValue('Estado'),
      TextCellValue('Observación'),
      TextCellValue('Responsable'),
    ]);
    for (final row in report.rows) {
      sheet.appendRow([
        TextCellValue(row.date),
        TextCellValue(row.groupName),
        TextCellValue(row.subjectName),
        TextCellValue(row.studentName),
        TextCellValue(row.state.label),
        TextCellValue(row.observation),
        TextCellValue(row.responsibleTeacherName),
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
      ..download = 'Asistencia_${report.dateFrom}_${report.dateTo}.xlsx'
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
