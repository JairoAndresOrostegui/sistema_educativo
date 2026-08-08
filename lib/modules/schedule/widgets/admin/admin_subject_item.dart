import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';

import '../../../../models/schedule/subject_model.dart';

class AdminSubjectItem extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showEdit;
  final bool showDelete;

  const AdminSubjectItem({
    super.key,
    required this.subject,
    required this.onEdit,
    required this.onDelete,
    this.showEdit = true,
    this.showDelete = true,
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
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppPalette.primary.withValues(alpha: .06),
            AppPalette.surface,
          ],
        ),
      ),
      child: ListTile(
        title: Text(
          subject.subject,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${TimeOfDay.fromDateTime(subject.startTime.toDate()).format(context)} '
          'to ${TimeOfDay.fromDateTime(subject.endTime.toDate()).format(context)} - ${subject.teacherName}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showEdit)
              IconButton(
                icon: Icon(Icons.edit, color: AppPalette.info),
                onPressed: onEdit,
              ),
            if (showDelete)
              IconButton(
                icon: Icon(Icons.delete, color: AppPalette.primary),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
