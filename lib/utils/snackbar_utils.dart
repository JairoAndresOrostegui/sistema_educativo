import 'package:flutter/material.dart';

void mostrarSnack(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
    ),
  );
}
