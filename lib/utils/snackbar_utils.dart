import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/material.dart';

void mostrarSnack(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppPalette.onSurface.withValues(alpha: .87),
    ),
  );
}
