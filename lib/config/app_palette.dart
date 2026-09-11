import 'package:flutter/material.dart';

import 'theme_config.dart';

/// Paleta semántica derivada de la marca configurada en Firestore.
abstract final class AppPalette {
  static ColorScheme get _colors => ThemeProvider.themeData.colorScheme;

  static Color get primary => _colors.primary;
  static Color get onPrimary => _colors.onPrimary;
  static Color get primaryContainer => _colors.primaryContainer;
  static Color get surface => _colors.surface;
  static Color get surfaceContainer => _colors.surfaceContainer;
  static Color get onSurface => _colors.onSurface;
  static Color get outline => _colors.outline;
  static Color get error => _colors.error;
  static Color get onError => _colors.onError;
  static Color get success => _colors.tertiary;
  static Color get warning => _colors.secondary;
  static Color get info => _colors.tertiary;
  static Color get shadow => _colors.shadow;
  static Color get muted => _colors.onSurfaceVariant;
  static Color get transparent => _colors.surface.withValues(alpha: 0);
}
