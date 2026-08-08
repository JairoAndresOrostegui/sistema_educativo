import 'package:flutter/material.dart';
import 'package:sistema_educativo/utils/parameters_service.dart';

class InstitutionSection extends StatelessWidget {
  final TextEditingController institucion;
  final TextEditingController sede;
  final bool soloLectura;
  final bool esSuperadminActual;
  final List<InstitutionOption> institutions;
  final List<String> campuses;
  final ValueChanged<String> onInstitutionChanged;
  final ValueChanged<String> onCampusChanged;
  const InstitutionSection({
    super.key,
    required this.institucion,
    required this.sede,
    required this.soloLectura,
    required this.esSuperadminActual,
    required this.institutions,
    required this.campuses,
    required this.onInstitutionChanged,
    required this.onCampusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('institution-${institucion.text}'),
          initialValue: institutions.any((item) => item.id == institucion.text)
              ? institucion.text
              : null,
          items: institutions
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.label)),
              )
              .toList(),
          onChanged: soloLectura || !esSuperadminActual
              ? null
              : (value) {
                  if (value != null) onInstitutionChanged(value);
                },
          decoration: const InputDecoration(
            labelText: 'Institucion',
            border: OutlineInputBorder(),
          ),
          validator: (value) => (value == null || value.isEmpty)
              ? 'Este campo es obligatorio'
              : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('campus-${institucion.text}-${sede.text}'),
          initialValue: campuses.contains(sede.text) ? sede.text : null,
          items: campuses
              .map(
                (campus) =>
                    DropdownMenuItem(value: campus, child: Text(campus)),
              )
              .toList(),
          onChanged: soloLectura || !esSuperadminActual
              ? null
              : (value) {
                  if (value != null) onCampusChanged(value);
                },
          decoration: const InputDecoration(
            labelText: 'Sede',
            border: OutlineInputBorder(),
          ),
          validator: (value) => (value == null || value.isEmpty)
              ? 'Este campo es obligatorio'
              : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
