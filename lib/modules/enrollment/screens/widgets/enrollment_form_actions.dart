import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';

class EnrollmentFormActions extends StatelessWidget {
  final bool isAdmin;
  final bool disabled;
  final String? currentEstado;
  final VoidCallback onGuardarRevision;
  final VoidCallback onMatricular;

  const EnrollmentFormActions({
    super.key,
    required this.isAdmin,
    required this.disabled,
    required this.currentEstado,
    required this.onGuardarRevision,
    required this.onMatricular,
  });

  @override
  Widget build(BuildContext context) {
    final primaryBlue = AppPalette.info;
    if (isAdmin) {
      final isMatriculado = currentEstado == 'matriculado';
      if (isMatriculado) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: disabled ? null : onGuardarRevision,
            icon: Icon(Icons.save),
            label: Text('Guardar cambios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: AppPalette.surface,
              padding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        );
      }
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: disabled ? null : onGuardarRevision,
              icon: Icon(Icons.pending_actions),
              label: Text('Guardar en revisi\u00f3n'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: AppPalette.surface,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: disabled ? null : onMatricular,
              icon: Icon(Icons.check_circle),
              label: Text('Matricular ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: AppPalette.surface,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : onGuardarRevision,
        icon: Icon(Icons.save),
        label: Text('Guardar solicitud'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: AppPalette.surface,
          padding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
