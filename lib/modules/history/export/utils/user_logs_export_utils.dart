import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../stub/export_utils_stub.dart'
    if (dart.library.html) '../web/user_logs_utils_web.dart'
    if (dart.library.io) '../mobile/export_utils_mobile.dart';

class UserLogsExportUtils {
  static void exportarExcel(List<Map<String, dynamic>> objeto) {
    ExportUtilsPlatform.exportarExcel(objeto);
  }

  static Future<void> exportarPDF(List<Map<String, dynamic>> logs) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

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

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Text(
            'Historial de Logs de Usuario',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [
              'Nombre',
              'Rol',
              'Evento',
              'Campus',
              'Institucion',
              'Grado',
              'Fecha',
            ],
            data: logs.map((log) {
              final fecha = asDateTime(log['timestamp']);
              final fechaTexto =
                  fecha != null
                      ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
                      : '-';
              return [
                (log['fullName'] ?? '').toString(),
                (log['role'] ?? '').toString(),
                (log['event'] ?? '').toString(),
                (log['campus'] ?? '').toString(),
                (log['institution'] ?? '').toString(),
                (log['grade'] ?? '').toString(),
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
