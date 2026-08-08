import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeConfig {
  final String nombre;
  final String logoUrl;
  final String primaryColor;
  final String footerColor;
  final String fontFamily;

  const ThemeConfig({
    required this.nombre,
    required this.logoUrl,
    required this.primaryColor,
    required this.footerColor,
    required this.fontFamily,
  });

  factory ThemeConfig.fromMaps({
    Map<String, dynamic> website = const {},
    Map<String, dynamic> school = const {},
  }) {
    final footer = Map<String, dynamic>.from(
      website['footer'] is Map ? website['footer'] as Map : const {},
    );
    return ThemeConfig(
      nombre: (school['nombre'] ?? website['schoolName'] ?? 'Sistema Educativo')
          .toString(),
      logoUrl: (school['logoUrl'] ?? website['logoUrl'] ?? '').toString(),
      primaryColor: (website['primaryColor'] ?? '#B71C1C').toString(),
      footerColor: (footer['backgroundColor'] ?? '#25090A').toString(),
      fontFamily: (website['fontFamily'] ?? 'Montserrat').toString(),
    );
  }
}

class ThemeProvider {
  static ThemeConfig config = ThemeConfig.fromMaps();
  static ThemeData? _cachedTheme;

  static Future<void> cargarConfiguracion() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('website').doc('config').get(),
      db
          .collection('configuracion_colegios')
          .doc('desarrolloytecnologiasantander.com')
          .get(),
    ]);
    config = ThemeConfig.fromMaps(
      website: results[0].data() ?? const {},
      school: results[1].data() ?? const {},
    );
    _cachedTheme = null;
  }

  static void usarConfiguracionPredeterminada() {
    config = ThemeConfig.fromMaps();
    _cachedTheme = null;
  }

  static ThemeData get themeData => _cachedTheme ??= _buildTheme();

  static ThemeData _buildTheme() {
    final seed = _parseHex(config.primaryColor) ?? const Color(0xFFB71C1C);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFBFF),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    TextTheme textTheme;
    try {
      textTheme = GoogleFonts.getTextTheme(config.fontFamily, base.textTheme);
    } catch (_) {
      textTheme = GoogleFonts.montserratTextTheme(base.textTheme);
    }
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static Color? _parseHex(String value) {
    final cleaned = value.trim().replaceFirst('#', '');
    if (cleaned.length != 6 && cleaned.length != 8) return null;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return null;
    return Color(cleaned.length == 6 ? 0xFF000000 | parsed : parsed);
  }
}
