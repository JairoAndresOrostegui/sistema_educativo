import 'package:flutter/material.dart';

class InstitutionSection extends StatelessWidget {
  final TextEditingController institucion;
  final TextEditingController sede;
  final bool soloLectura;
  final bool esSuperadminActual;
  const InstitutionSection({
    super.key,
    required this.institucion,
    required this.sede,
    required this.soloLectura,
    required this.esSuperadminActual,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: institucion,
          readOnly: soloLectura || !esSuperadminActual,
          decoration: const InputDecoration(
            labelText: 'Institucion',
            border: OutlineInputBorder(),
          ),
          validator:
              (value) =>
                  (value == null || value.isEmpty)
                      ? 'Este campo es obligatorio'
                      : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: sede,
          readOnly: soloLectura || !esSuperadminActual,
          decoration: const InputDecoration(
            labelText: 'Sede',
            border: OutlineInputBorder(),
          ),
          validator:
              (value) =>
                  (value == null || value.isEmpty)
                      ? 'Este campo es obligatorio'
                      : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
