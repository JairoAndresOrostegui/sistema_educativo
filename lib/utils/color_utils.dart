import 'package:flutter/material.dart';

Color? parseColor(String? hexColor) {
  if (hexColor == null || hexColor.isEmpty) return null;

  hexColor = hexColor.replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF$hexColor"; // Añade opacidad completa
  }

  try {
    return Color(int.parse("0x$hexColor"));
  } catch (_) {
    return null;
  }
}
