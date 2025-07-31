import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Solo para Web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ExportUtils {
  /// Exportar a Excel (solo en Web)
  static void exportarExcel(List<Map<String, dynamic>> rutas) {
    if (!kIsWeb) return;

    final excel = Excel.createExcel();
    final sheet = excel['HistorialRutas'];

    sheet.appendRow([
      TextCellValue('Nombre Ruta'),
      TextCellValue('Fecha'),
      TextCellValue('Docente'),
      TextCellValue('Hora Inicio'),
      TextCellValue('Hora Fin'),
      TextCellValue('Estado'),
      TextCellValue('Duración (min)'),
      TextCellValue('Total Estudiantes'),
      TextCellValue('Avisos Enviados'),
    ]);

    for (final r in rutas) {
      final inicio = r['horaInicio']?.toDate();
      final fin = r['horaFin']?.toDate();
      final duracion =
          (inicio != null && fin != null)
              ? fin.difference(inicio).inMinutes.toString()
              : '';
      // Agrega la fila de la ruta
      sheet.appendRow([
        TextCellValue(r['nombreRuta'] ?? ''),
        TextCellValue(r['fecha']?.toDate().toString() ?? ''),
        TextCellValue(r['gestionadaPorNombre'] ?? r['docenteNombre'] ?? ''),
        TextCellValue(r['horaInicio']?.toDate().toString() ?? ''),
        TextCellValue(r['horaFin']?.toDate().toString() ?? ''),
        TextCellValue(r['estado'] ?? ''),
        TextCellValue(duracion),
        TextCellValue((r['estudiantes']?.length ?? 0).toString()),
        TextCellValue(
          (r['estudiantes']?.where((e) => e['avisoEnviado'] == true).length ??
                  0)
              .toString(),
        ),
      ]);

      // Encabezados de los estudiantes
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Nombre Estudiante'),
        TextCellValue('Dirección'),
        TextCellValue('Hora Recogida'),
        TextCellValue('Recogido'),
        TextCellValue('Anulado'),
        TextCellValue('Activo'),
        TextCellValue('Avisos Enviados'),
      ]);

      final estudiantes = List<Map<String, dynamic>>.from(
        r['estudiantes'] ?? [],
      );
      for (final est in estudiantes) {
        sheet.appendRow([
          TextCellValue(''),
          TextCellValue(est['nombre'] ?? ''),
          TextCellValue(est['direccion'] ?? ''),
          TextCellValue(est['horaRecogida']?.toDate().toString() ?? ''),
          TextCellValue(est['recogido'] == true ? 'Sí' : 'No'),
          TextCellValue(est['anulado'] == true ? 'Sí' : 'No'),
          TextCellValue(est['activo'] == true ? 'Sí' : 'No'),
          TextCellValue((est['avisosEnviados'] ?? 0).toString()),
        ]);
      }

      // Línea vacía para separar rutas
      sheet.appendRow([]);
    }

    final fileBytes = excel.encode();
    final blob = html.Blob([fileBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor =
        html.AnchorElement(href: url)
          ..setAttribute("download", "HistorialRutas.xlsx")
          ..click();

    html.Url.revokeObjectUrl(url);
  }

  /// Exportar a PDF (todas las plataformas)
  static Future<void> exportarPDF(List<Map<String, dynamic>> rutas) async {
  final pdf = pw.Document();

  final font = await PdfGoogleFonts.openSansRegular();
  final fontBold = await PdfGoogleFonts.openSansBold();

  pdf.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
      build: (context) => [
        pw.Text(
          'Historial de Rutas Diarias',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 20),
        ...rutas.map((ruta) {
          final nombre = ruta['nombreRuta'] ?? '';
          final fecha = ruta['fecha']?.toDate();
          final fechaTexto = fecha != null
              ? DateFormat('yyyy-MM-dd').format(fecha)
              : '-';
          final docente = ruta['gestionadaPorNombre'] ?? ruta['docenteNombre'] ?? '';
          final inicio = ruta['horaInicio']?.toDate();
          final fin = ruta['horaFin']?.toDate();
          final duracion = (inicio != null && fin != null)
              ? '${fin.difference(inicio).inMinutes} min'
              : '-';
          final horaInicio = inicio != null ? DateFormat.Hm().format(inicio) : '-';
          final horaFin = fin != null ? DateFormat.Hm().format(fin) : '-';
          final estado = ruta['estado'] ?? '';
          final estudiantes = List<Map<String, dynamic>>.from(ruta['estudiantes'] ?? []);
          final totalEstudiantes = estudiantes.length;
          final avisos = estudiantes.where((e) => e['avisoEnviado'] == true).length;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Ruta: $nombre', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Fecha: $fechaTexto'),
              pw.Text('Docente: $docente'),
              pw.Text('Inicio: $horaInicio  Fin: $horaFin  Duración: $duracion'),
              pw.Text('Estado: $estado | Estudiantes: $totalEstudiantes | Avisos: $avisos'),
              pw.SizedBox(height: 8),
              if (estudiantes.isNotEmpty)
                pw.TableHelper.fromTextArray(
                  headers: ['Nombre', 'Dirección', 'Hora', 'Recogido', 'Anulado', 'En Ruta', 'Avisos'],
                  data: estudiantes.map((e) {
                    final hora = e['horaRecogida'] != null
                        ? DateFormat.Hm().format((e['horaRecogida'] as Timestamp).toDate())
                        : '-';
                    return [
                      e['nombre'] ?? '',
                      e['direccion'] ?? '',
                      hora,
                      e['recogido'] == true ? 'Sí' : 'No',
                      e['anulado'] == true ? 'Sí' : 'No',
                      e['activo'] == true ? 'Sí' : 'No',
                      (e['avisosEnviados'] ?? 0).toString(),
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellStyle: const pw.TextStyle(fontSize: 10),
                ),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 10),
            ],
          );
        }),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
  );
}

}
