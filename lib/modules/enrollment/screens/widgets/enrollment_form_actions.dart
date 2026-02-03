import 'package:flutter/material.dart';

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
    if (isAdmin) {
      final isMatriculado = currentEstado == 'matriculado';
      if (isMatriculado) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: disabled ? null : onGuardarRevision,
            icon: const Icon(Icons.save),
            label: const Text('Guardar cambios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
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
              icon: const Icon(Icons.pending_actions),
              label: const Text('Guardar en revisi\u00f3n'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: disabled ? null : onMatricular,
              icon: const Icon(Icons.check_circle),
              label: const Text('Matricular ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
        icon: const Icon(Icons.save),
        label: const Text('Guardar solicitud'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
