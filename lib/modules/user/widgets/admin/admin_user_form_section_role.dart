import 'package:flutter/material.dart';

import 'package:sistema_educativo/utils/parameters_service.dart';
import 'package:sistema_educativo/models/academic/academic_group.dart';

class RoleSection extends StatelessWidget {
  final String? safeRole;
  final List<Parameter> roles;
  final void Function(String?) onRolChanged;
  final String status;
  final void Function(String?) onStatusChanged;
  final String rol;
  final String? safeGroupId;
  final List<AcademicGroup> groups;
  final void Function(String?) onGroupChanged;
  final bool soloLectura;
  const RoleSection({
    super.key,
    required this.safeRole,
    required this.roles,
    required this.onRolChanged,
    required this.status,
    required this.onStatusChanged,
    required this.rol,
    required this.safeGroupId,
    required this.groups,
    required this.onGroupChanged,
    required this.soloLectura,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
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
                child: Text(
                  r.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: soloLectura ? null : onRolChanged,
          validator: (value) => value == null ? 'El rol es obligatorio' : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Estado'),
          initialValue: status,
          items: const [
            DropdownMenuItem(value: 'activo', child: Text('Activo')),
            DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
          ],
          onChanged: soloLectura ? null : onStatusChanged,
          validator: (value) =>
              value == null ? 'El estado es obligatorio' : null,
        ),
        const SizedBox(height: 8),
        if (rol == 'Estudiante' || rol == 'Docente')
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Grupo'),
            initialValue: safeGroupId,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Seleccione un grupo'),
              ),
              ...groups.map(
                (g) => DropdownMenuItem<String>(
                  value: g.id,
                  child: Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: soloLectura ? null : onGroupChanged,
            validator: (value) =>
                value == null ? 'El grupo es obligatorio' : null,
          ),
      ],
    );
  }
}
