import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';

import '../../../../models/schedule/subject_model.dart';
import 'admin_subject_item.dart';

class AdminDayColumn extends StatelessWidget {
  final String day;
  final List<SubjectModel> subjects;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onAddSubject;
  final void Function(SubjectModel) onEditSubject;
  final void Function(SubjectModel) onDeleteSubject;

  const AdminDayColumn({
    super.key,
    required this.day,
    required this.subjects,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.onEditSubject,
    required this.onDeleteSubject,
    this.onAddSubject,
  });

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppPalette.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              _cap(day),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppPalette.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppPalette.primary.withValues(alpha: .15),
            ),
            color: AppPalette.surfaceContainer,
            boxShadow: [
              BoxShadow(
                color: AppPalette.onSurface.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: subjects.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No hay materias para este día.'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: subjects.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => AdminSubjectItem(
                      subject: subjects[i],
                      onEdit: () => onEditSubject(subjects[i]),
                      onDelete: () => onDeleteSubject(subjects[i]),
                      showEdit: canEdit,
                      showDelete: canDelete,
                    ),
                  ),
          ),
        ),
        if (canCreate && onAddSubject != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: AppPalette.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: onAddSubject,
              child: const Text('Agregar materia'),
            ),
          ),
      ],
    );
  }
}
