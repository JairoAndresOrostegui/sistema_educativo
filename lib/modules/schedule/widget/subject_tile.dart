import 'package:flutter/material.dart';
import 'package:sistema_educativo/utils/format_utils.dart';

import '../../../models/schedule/subject_model.dart';

class SubjectTile extends StatelessWidget {
  final MateriaModel materia;
  final int index;
  final String dia;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SubjectTile({
    super.key,
    required this.materia,
    required this.index,
    required this.dia,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hora = FormatUtils.formatHourRange(
      materia.horaInicio,
      materia.horaFin,
    );
    final labelBase = 'Materia ${materia.materia} de $hora';

    return Semantics(
      label: labelBase,
      readOnly: true,
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.book),
          title: Text(materia.materia),
          subtitle: Text(hora),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onEdit != null)
                Semantics(
                  button: true,
                  label: 'Editar $labelBase',
                  enabled: true,
                  focusable: true,
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.green),
                    onPressed: onEdit,
                    tooltip: 'Editar materia',
                  ),
                ),
              if (onDelete != null)
                Semantics(
                  button: true,
                  label: 'Eliminar $labelBase',
                  enabled: true,
                  focusable: true,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Eliminar materia',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
