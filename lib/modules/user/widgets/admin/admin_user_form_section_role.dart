import 'package:flutter/material.dart';

import 'package:sistema_educativo/utils/parameters_service.dart';

class RoleSection extends StatelessWidget {
  final String? safeRole;
  final List<Parameter> roles;
  final void Function(String?) onRolChanged;
  final String status;
  final void Function(String?) onStatusChanged;
  final String rol;
  final String? safeGrade;
  final List<Parameter> grades;
  final void Function(String?) onGradeChanged;
  final bool soloLectura;
  const RoleSection({
    super.key,
    required this.safeRole,
    required this.roles,
    required this.onRolChanged,
    required this.status,
    required this.onStatusChanged,
    required this.rol,
    required this.safeGrade,
    required this.grades,
    required this.onGradeChanged,
    required this.soloLectura,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Rol'),
          initialValue: safeRole,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Seleccione un rol'),
            ),
            ...roles.map(
              (r) => DropdownMenuItem<String>(
                value: r.valor,
                child: Text(r.etiqueta),
              ),
            ),
          ],
          onChanged: soloLectura ? null : onRolChanged,
          validator: (value) => value == null ? 'El rol es obligatorio' : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Estado'),
          initialValue: status,
          items: const [
            DropdownMenuItem(value: 'activo', child: Text('Activo')),
            DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
          ],
          onChanged: soloLectura ? null : onStatusChanged,
          validator:
              (value) => value == null ? 'El estado es obligatorio' : null,
        ),
        const SizedBox(height: 8),
        if (rol == 'Estudiante' || rol == 'Docente')
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Grado'),
            initialValue: safeGrade,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Seleccione un grado'),
              ),
              ...grades.map(
                (g) => DropdownMenuItem<String>(
                  value: g.valor,
                  child: Text('${g.valor} - ${g.etiqueta}'),
                ),
              ),
            ],
            onChanged: soloLectura ? null : onGradeChanged,
            validator:
                (value) => value == null ? 'El grado es obligatorio' : null,
          ),
      ],
    );
  }
}
