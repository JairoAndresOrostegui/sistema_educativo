import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EnrollmentPdfUtils {
  static Future<void> export(
    Map<String, dynamic> data, {
    String? estado,
    int? anio,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm');

    pw.Widget row(String label, String? value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 160,
              child: pw.Text(
                label,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value ?? '-',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Text(
            'Formulario de Matrícula',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Estado: ${estado ?? '-'}   •   Año: ${anio ?? '-'}   •   Generado: ${formatter.format(now)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: pdf.PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                row(
                  'Estudiante',
                  (data['nombresApellidosAlumno'] ??
                          '${data['nombresAlumno'] ?? ''} ${data['apellidosAlumno'] ?? ''}')
                      .toString()
                      .trim(),
                ),
                row('Documento', data['numeroIdentidad']?.toString()),
                row('Tipo documento', data['tipoIdentidad']?.toString()),
                row('Fecha nacimiento', data['fechaNacimiento']?.toString()),
                row('Edad', data['edad']?.toString()),
                row('Dirección', data['direccionAlumno']?.toString()),
                row('Grado aspirado', data['gradoAspirado']?.toString()),
                row('Sede', data['sedeAspirada']?.toString()),
                row('EPS', data['epsEstudiante']?.toString()),
                row('Teléfono', data['telefonoAlumno']?.toString()),
                row('Observaciones', data['observacionesPadres']?.toString()),
                row('Padre', data['nombrePadre']?.toString()),
                row('Madre', data['nombreMadre']?.toString()),
                row('Email padre', data['emailPadre']?.toString()),
                row('Email madre', data['emailMadre']?.toString()),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
