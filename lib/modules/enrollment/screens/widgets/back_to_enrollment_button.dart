import 'package:flutter/material.dart';

class BackToEnrollmentButton extends StatelessWidget {
  final Color? color;
  const BackToEnrollmentButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back),
      color: color ?? Colors.redAccent,
      tooltip: 'Volver a gestión de matrículas',
    );
  }
}
