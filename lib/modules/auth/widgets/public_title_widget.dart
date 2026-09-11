import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/theme_config.dart';

class PublicTitleWidget extends StatelessWidget {
  const PublicTitleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final title = ThemeProvider.config.nombre;
    final isWideWeb = kIsWeb && MediaQuery.of(context).size.width >= 900;

    final base = Theme.of(context).textTheme.titleLarge;
    final color = Theme.of(context).colorScheme.primary;

    // Fuerza una fuente tipo "brush" (Alex Brush)
    TextStyle style = GoogleFonts.alexBrush(
      textStyle: base,
    ).copyWith(color: color, fontWeight: FontWeight.w500, letterSpacing: .4);

    if (isWideWeb) {
      final fs = style.fontSize ?? base?.fontSize ?? 32;
      style = style.copyWith(fontSize: fs * 3.3);
    }

    return Semantics(
      label: 'Nombre de la institución',
      header: true,
      child: Text(title, textAlign: TextAlign.center, style: style),
    );
  }
}
