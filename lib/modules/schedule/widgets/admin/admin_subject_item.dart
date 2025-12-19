import 'package:flutter/material.dart';

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
        border: Border.all(color: Colors.red.withValues(alpha: .15)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.red.withValues(alpha: .06), Colors.white],
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
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: onEdit,
              ),
            if (showDelete)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
