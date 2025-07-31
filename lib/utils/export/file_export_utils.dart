import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Solo para Web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class DocumentHistoryUtils {
  static void exportarExcel(List<Map<String, dynamic>> logs) {
    final excel = Excel.createExcel();
    final sheet = excel['HistorialDocumentos'];

    sheet.appendRow([
      TextCellValue('Nombre del archivo'),
      TextCellValue('Grado'),
      TextCellValue('Subido por'),
      TextCellValue('Fecha de subida'),
    ]);

    for (final log in logs) {
      final fecha = log['fechaSubida'];
      final fechaTexto = fecha != null
          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
          : '';

      sheet.appendRow([
        TextCellValue(log['nombre'] ?? ''),
        TextCellValue(log['grado'] ?? ''),
        TextCellValue(log['subidoPor'] ?? ''),
        TextCellValue(fechaTexto),
      ]);
    }

    final bytes = excel.encode();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "HistorialDocumentos.xlsx")
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
            'Historial de Documentos Subidos',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [
              'Nombre del archivo',
              'Grado',
              'Subido por',
              'Fecha de subida',
            ],
            data: logs.map((log) {
              final fecha = log['fechaSubida'];
              final fechaTexto = fecha != null
                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
                  : '-';
              return [
                log['nombre'] ?? '',
                log['grado'] ?? '',
                log['subidoPor'] ?? '',
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
