// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'package:excel/excel.dart';
import '../../services/history_query_utils.dart';

class ExportUtilsPlatform {
  static void exportarExcel(List<Map<String, dynamic>> rutas) {
    final excel = Excel.createExcel();

    const String sheetName = 'HistorialRutas';
    final def = excel.getDefaultSheet();
    if (def != null && def != sheetName) {
      excel.rename(def, sheetName);
    }
    final Sheet sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('Nombre Ruta'),
      TextCellValue('Fecha'),
      TextCellValue('Docente'),
      TextCellValue('Hora Inicio'),
      TextCellValue('Hora Fin'),
      TextCellValue('Estado'),
      TextCellValue('Duracion (min)'),
      TextCellValue('Total Estudiantes'),
      TextCellValue('Avisos Enviados'),
    ]);

    for (final r in rutas) {
      final inicio = historyDate(r['horaInicio']);
      final fin = historyDate(r['horaFin']);
      final duracion = (inicio != null && fin != null)
          ? fin.difference(inicio).inMinutes.toString()
          : '';

      sheet.appendRow([
        TextCellValue(r['nombreRuta'] ?? ''),
        TextCellValue(historyDate(r['fecha'])?.toString() ?? ''),
        TextCellValue(r['gestionadaPorNombre'] ?? r['docenteNombre'] ?? ''),
        TextCellValue(inicio?.toString() ?? ''),
        TextCellValue(fin?.toString() ?? ''),
        TextCellValue(r['estado'] ?? ''),
        TextCellValue(duracion),
        TextCellValue(
          (r['estudiantes'] is List ? (r['estudiantes'] as List).length : 0)
              .toString(),
        ),
        TextCellValue(
          (r['estudiantes'] is List
                  ? (r['estudiantes'] as List)
                        .whereType<Map>()
                        .where((e) => e['avisoEnviado'] == true)
                        .length
                  : 0)
              .toString(),
        ),
      ]);

      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Nombre Estudiante'),
        TextCellValue('Direccion'),
        TextCellValue('Hora Recogida'),
        TextCellValue('Recogido'),
        TextCellValue('Anulado'),
        TextCellValue('Activo'),
        TextCellValue('Avisos Enviados'),
      ]);

      final rawStudents = r['estudiantes'];
      final estudiantes = rawStudents is List
          ? rawStudents
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      for (final est in estudiantes) {
        sheet.appendRow([
          TextCellValue(''),
          TextCellValue(est['nombre'] ?? ''),
          TextCellValue(est['direccion'] ?? ''),
          TextCellValue(historyDate(est['horaRecogida'])?.toString() ?? ''),
          TextCellValue(est['recogido'] == true ? 'Si' : 'No'),
          TextCellValue(est['anulado'] == true ? 'Si' : 'No'),
          TextCellValue(est['activo'] == true ? 'Si' : 'No'),
          TextCellValue((est['avisosEnviados'] ?? 0).toString()),
        ]);
      }

      sheet.appendRow(const []);
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
      ..download = 'HistorialRutas.xlsx'
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
