import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

// Solo para Web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:printing/printing.dart';

class UserHistoryUtils {
  static void exportarExcel(List<Map<String, dynamic>> historial) {
    if (!kIsWeb) return;

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
      final fechaTexto = fecha != null
          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
          : '';

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
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "HistorialUsuarios.xlsx")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static Future<void> exportarPDF(List<Map<String, dynamic>> logs) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Text(
            'Historial de Cambios de Usuarios',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [
              'Acción',
              'Nombres',
              'Apellidos',
              'Rol',
              'Realizado por',
              'Fecha',
            ],
            data: logs.map((log) {
              final fecha = log['fecha'];
              final fechaTexto = fecha != null
                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
                  : '-';
              return [
                log['accion'] ?? '',
                log['nombres'] ?? '',
                log['apellidos'] ?? '',
                log['rol'] ?? '',
                log['realizadoPor'] ?? '',
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
