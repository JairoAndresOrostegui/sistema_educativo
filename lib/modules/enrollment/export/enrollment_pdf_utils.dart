import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/enrollment_fields.dart';
import '../config/enrollment_sections.dart';

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
    final currentYear = now.year;
    final currentDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final logoHeader = pw.MemoryImage(
      (await rootBundle.load('assets/Logo.jpeg')).buffer.asUint8List(),
    );
    final logoFondo = pw.MemoryImage(
      (await rootBundle.load('assets/logo_fondo.png')).buffer.asUint8List(),
    );

    final fieldsByName = {
      for (final field in enrollmentFieldConfig) field.name: field,
    };

    String normalizeValue(dynamic value) {
      if (value == null) return '-';
      if (value is bool) return value ? 'Si' : 'No';
      if (value is List) {
        if (value.isEmpty) return '-';
        return value.map((e) => e.toString()).join(', ');
      }
      final text = value.toString().trim();
      if (text.isEmpty) return '-';
      if (text.toLowerCase() == 'true') return 'Si';
      if (text.toLowerCase() == 'false') return 'No';
      return text;
    }

    final hasDifferentGuardian =
        data['tieneAcudienteDiferente']?.toString().toLowerCase() == 'true';

    bool shouldIncludeField(String name) {
      if (name == 'acudientePrincipal') return !hasDifferentGuardian;
      if ([
        'nombreAcudiente',
        'cedulaAcudiente',
        'emailAcudiente',
        'celularAcudiente',
        'lugarTrabajoAcudiente',
        'ocupacionAcudiente',
        'cargoAcudiente',
      ].contains(name)) {
        return hasDifferentGuardian;
      }
      return true;
    }

    pw.Widget dataRow(String label, String value) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 220,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget sectionTitle(String title) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 4),
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: pdf.PdfColors.red,
          ),
        ),
      );
    }

    List<pw.Widget> sectionRows(List<String> fieldNames) {
      return fieldNames
          .where(shouldIncludeField)
          .map((name) {
            final label = fieldsByName[name]?.label ?? name;
            return dataRow(label, normalizeValue(data[name]));
          })
          .toList();
    }

    List<pw.Widget> sectionWidgets(String title, List<String> fieldNames) {
      return [
        sectionTitle(title),
        ...sectionRows(fieldNames),
      ];
    }

    final sectionsToPrint = enrollmentSections.take(4).toList();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          margin: const pw.EdgeInsets.fromLTRB(58, -18, 38, -68),
          buildBackground:
              (context) => pw.Align(
                alignment: const pw.Alignment(0, -0.20),
                child: pw.Opacity(
                  opacity: 1,
                  child: pw.Image(
                    logoFondo,
                    width: 360,
                    height: 360,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
        ),
        maxPages: 200,
        header:
            (context) => pw.Container(
              margin: pw.EdgeInsets.only(
                top: 0,
                bottom: context.pageNumber == 1 ? -46 : 8,



              ),
              child: pw.Image(logoHeader, fit: pw.BoxFit.fitWidth),
            ),
        build:
            (context) => [
              pw.Stack(
                children: [
                  pw.Container(
                    height: 140,
                    alignment: pw.Alignment.topLeft,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12, right: 110),
                      child: pw.Column(
                        children: [
                          pw.SizedBox(height: 0),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 95),
                            child: pw.Align(
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                'DATOS DEL ALUMNO(A)',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdf.PdfColors.red,
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 95),
                            child: pw.Align(
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                'Año $currentYear',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdf.PdfColors.red,
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Align(
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Text(
                              'Fecha de inscripcion: $currentDate',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.Positioned(
                    right: 0,
                    top: 0,
                    child: pw.Container(
                      width: 110,
                      height: 140,
                      child: pw.Stack(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Container(
                              alignment: pw.Alignment.center,
                              decoration: pw.BoxDecoration(
                                color: pdf.PdfColors.white,
                                border: pw.Border.all(
                                  color: pdf.PdfColors.grey600,
                                  width: 0.8,
                                ),
                                borderRadius: pw.BorderRadius.circular(12),
                              ),
                              child: pw.Text(
                                'Foto de\n3 x 4 cm',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              ...sectionsToPrint.expand(
                (section) => sectionWidgets(section.title, section.fieldNames),
              ),
            ],
      ),
    );

    try {
      final bytes = await doc.save();
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (_) {
      final fallback = pw.Document();
      fallback.addPage(
        pw.MultiPage(
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          header:
              (context) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Image(logoHeader, fit: pw.BoxFit.fitWidth),
              ),
          build:
              (context) => [
                pw.Text(
                  'No se pudo renderizar el formato completo. Se muestra una version simplificada.',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: pdf.PdfColors.red,
                  ),
                ),
                pw.SizedBox(height: 12),
                ...sectionsToPrint.expand(
                  (section) => sectionWidgets(section.title, section.fieldNames),
                ),
              ],
        ),
      );
      final fallbackBytes = await fallback.save();
      await Printing.layoutPdf(onLayout: (format) async => fallbackBytes);
    }
  }
}
