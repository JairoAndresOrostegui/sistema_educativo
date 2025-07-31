import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'stub/export_utils_stub.dart'
    if (dart.library.html) 'web/daily_route_export_web.dart'
    if (dart.library.io) 'mobile/export_utils_mobile.dart';

class DailyRouteExportUtils {
  /// Exportar a Excel (solo en Web)
  static void exportarExcel(List<Map<String, dynamic>> objeto) {
    ExportUtilsPlatform.exportarExcel(objeto);
  }

  /// Exportar a PDF (todas las plataformas)
  static Future<void> exportarPDF(List<Map<String, dynamic>> rutas) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build:
            (context) => [
              pw.Text(
                'Historial de Rutas Diarias',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              ...rutas.map((ruta) {
                final nombre = ruta['nombreRuta'] ?? '';
                final fecha = ruta['fecha']?.toDate();
                final fechaTexto =
                    fecha != null
                        ? DateFormat('yyyy-MM-dd').format(fecha)
                        : '-';
                final docente =
                    ruta['gestionadaPorNombre'] ?? ruta['docenteNombre'] ?? '';
                final inicio = ruta['horaInicio']?.toDate();
                final fin = ruta['horaFin']?.toDate();
                final duracion =
                    (inicio != null && fin != null)
                        ? '${fin.difference(inicio).inMinutes} min'
                        : '-';
                final horaInicio =
                    inicio != null ? DateFormat.Hm().format(inicio) : '-';
                final horaFin = fin != null ? DateFormat.Hm().format(fin) : '-';
                final estado = ruta['estado'] ?? '';
                final estudiantes = List<Map<String, dynamic>>.from(
                  ruta['estudiantes'] ?? [],
                );
                final totalEstudiantes = estudiantes.length;
                final avisos =
                    estudiantes.where((e) => e['avisoEnviado'] == true).length;

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ruta: $nombre',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text('Fecha: $fechaTexto'),
                    pw.Text('Docente: $docente'),
                    pw.Text(
                      'Inicio: $horaInicio  Fin: $horaFin  Duración: $duracion',
                    ),
                    pw.Text(
                      'Estado: $estado | Estudiantes: $totalEstudiantes | Avisos: $avisos',
                    ),
                    pw.SizedBox(height: 8),
                    if (estudiantes.isNotEmpty)
                      pw.TableHelper.fromTextArray(
                        headers: [
                          'Nombre',
                          'Dirección',
                          'Hora',
                          'Recogido',
                          'Anulado',
                          'En Ruta',
                          'Avisos',
                        ],
                        data:
                            estudiantes.map((e) {
                              final hora =
                                  e['horaRecogida'] != null
                                      ? DateFormat.Hm().format(
                                        (e['horaRecogida'] as Timestamp)
                                            .toDate(),
                                      )
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
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                        ),
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

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
