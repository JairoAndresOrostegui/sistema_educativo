import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../stub/export_utils_stub.dart'
    if (dart.library.html) '../web/admin_route_log_utils_web.dart'
    if (dart.library.io) '../mobile/export_utils_mobile.dart';

class AdminRouteLogUtils {
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
                'Historial de Gestión de Rutas',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Ruta', 'Acción', 'Administrador', 'Fecha'],
                data:
                    logs.map((log) {
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
                      final fechaTexto =
                          fecha != null
                              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
                              : '-';

                      return [
                        log['nombreRuta'] ?? '',
                        log['accion'] ?? '',
                        log['nombreAdmin'] ?? '',
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
