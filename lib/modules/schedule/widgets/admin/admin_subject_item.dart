import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';

import '../../../../models/schedule/subject_model.dart';

class AdminSubjectItem extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showEdit;
  final bool showDelete;
  final bool showGroupName;

  const AdminSubjectItem({
    super.key,
    required this.subject,
    required this.onEdit,
    required this.onDelete,
    this.showEdit = true,
    this.showDelete = true,
    this.showGroupName = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.primary.withValues(alpha: .15)),
        color: AppPalette.surfaceContainer,
      ),
      child: ListTile(
        title: Text(
          subject.subject,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${TimeOfDay.fromDateTime(subject.startTime.toDate()).format(context)} '
          'a ${TimeOfDay.fromDateTime(subject.endTime.toDate()).format(context)}'
          '${showGroupName ? ' · ${subject.groupName}' : ' · ${subject.teacherName}'}',
        ),
        trailing: showEdit || showDelete
            ? PopupMenuButton<String>(
                tooltip: 'Acciones de la materia',
                onSelected: (action) {
                  if (action == 'edit') onEdit();
                  if (action == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  if (showEdit)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Editar'),
                      ),
                    ),
                  if (showDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete),
                        title: Text('Eliminar'),
                      ),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}
