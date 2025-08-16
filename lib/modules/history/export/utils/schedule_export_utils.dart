import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../stub/export_utils_stub.dart'
    if (dart.library.html) '../web/schedule_history_utils_web.dart'
    if (dart.library.io) '../mobile/export_utils_mobile.dart';

class ScheduleHistoryUtils {
  static void exportarExcel(List<Map<String, dynamic>> objeto) {
    ExportUtilsPlatform.exportarExcel(objeto);
  }

  static Future<void> exportarPDF(List<Map<String, dynamic>> logs) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    DateTime? _asDateTime(dynamic raw) {
      if (raw is DateTime) return raw;
      if (raw is Timestamp) return raw.toDate();
      if (raw is num) {
        final v = raw.toDouble().abs();
        if (v > 1e14)
          return DateTime.fromMicrosecondsSinceEpoch(raw.toInt()); // µs
        if (v > 1e11)
          return DateTime.fromMillisecondsSinceEpoch(raw.toInt()); // ms
        return DateTime.fromMillisecondsSinceEpoch((raw * 1000).toInt()); // s
      }
      if (raw is String && raw.isNotEmpty) {
        try {
          return DateTime.parse(raw);
        } catch (_) {}
      }
      return null;
    }

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
                      final fecha = _asDateTime(log['fecha']);
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
