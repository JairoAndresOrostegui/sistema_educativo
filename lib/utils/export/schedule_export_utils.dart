import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Solo para Web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ScheduleHistoryUtils {
  /// Exportar historial a Excel (solo Web)
  static void exportarExcel(List<Map<String, dynamic>> logs) {
    if (!kIsWeb) return;

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

  /// Exportar historial a PDF (todas las plataformas)
  static Future<void> exportarPDF(List<Map<String, dynamic>> logs) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Text(
            'Historial de Horarios',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [
              'Grado',
              'Día',
              'Materia',
              'Acción',
              'Usuario',
              'Fecha',
            ],
            data: logs.map((log) {
              final fecha = log['fecha']?.toDate();
              final fechaTexto = fecha != null
                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
                  : '-';
              return [
                log['grado'] ?? '',
                log['dia'] ?? '',
                log['materia'] ?? '',
                log['accion'] ?? '',
                log['usuarioNombre'] ?? '',
                fechaTexto,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
