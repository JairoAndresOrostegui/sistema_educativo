import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'stub/export_utils_stub.dart'
    if (dart.library.html) 'web/schedule_history_utils_web.dart'
    if (dart.library.io) 'mobile/export_utils_mobile.dart';

class ScheduleHistoryUtils {
  /// Exportar historial a Excel (solo Web)
  static void exportarExcel(List<Map<String, dynamic>> objeto) {
    ExportUtilsPlatform.exportarExcel(objeto);
  }

  /// Exportar historial a PDF (todas las plataformas)
  static Future<void> exportarPDF(List<Map<String, dynamic>> logs) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build:
            (context) => [
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
                data:
                    logs.map((log) {
                      final fecha = log['fecha']?.toDate();
                      final fechaTexto =
                          fecha != null
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
