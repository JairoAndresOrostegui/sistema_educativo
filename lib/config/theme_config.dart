import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeConfig {
  final String nombre;
  final String logoUrl;
  final String colorFondo;
  final String colorTextoTitulo;
  final String colorLabel;
  final String fuenteGeneral;
  final String fuenteTitulos;

  ThemeConfig({
    required this.nombre,
    required this.logoUrl,
    required this.colorFondo,
    required this.colorTextoTitulo,
    required this.colorLabel,
    required this.fuenteGeneral,
    required this.fuenteTitulos,
  });

  factory ThemeConfig.fromMap(Map<String, dynamic> map) {
    return ThemeConfig(
      nombre: map['nombre'] ?? 'Sistema Educativo',
      logoUrl: map['logoUrl'] ?? '',
      colorFondo: map['colorFondo'] ?? '#FFFFFF',
      colorTextoTitulo: map['colorTextoTitulo'] ?? '#000000',
      colorLabel: map['colorLabel'] ?? '#333333',
      fuenteGeneral: map['fuenteGeneral'] ?? 'Roboto',
      // ⬇️ Default cambiado a Alex Brush
      fuenteTitulos: map['fuenteTitulos'] ?? 'Alex Brush',
    );
  }
}

class ThemeProvider {
  static ThemeConfig? config;

  static Future<void> cargarConfiguracion(String docId) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('configuracion_colegios')
            .doc(docId)
            .get();

    if (snapshot.exists) {
      config = ThemeConfig.fromMap(snapshot.data()!);
    } else {
      throw Exception('No se encontró la configuración del colegio');
    }
  }
}
