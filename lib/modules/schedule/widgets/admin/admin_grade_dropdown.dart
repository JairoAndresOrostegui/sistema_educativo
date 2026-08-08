import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';

import '../../../../models/academic/academic_group.dart';

class AdminGradeDropdown extends StatelessWidget {
  final String? selectedGroupId;
  final ValueChanged<String?> onChanged;
  final List<AcademicGroup> availableGroups;

  const AdminGradeDropdown({
    super.key,
    required this.selectedGroupId,
    required this.onChanged,
    required this.availableGroups,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppPalette.primary.withValues(alpha: .15)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppPalette.primary.withValues(alpha: .06),
            AppPalette.surface,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.onSurface.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedGroupId,
          hint: const Text('Selecciona un grupo'),
          isExpanded: true,
          items: availableGroups
              .map(
                (group) => DropdownMenuItem<String>(
                  value: group.id,
                  child: Text(group.name),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
