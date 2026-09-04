import 'package:flutter/material.dart';

import '../../../../models/academic/academic_group.dart';
import '../searchable_schedule_selector.dart';

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
    return SearchableScheduleSelector(
      label: 'Grupo',
      hint: 'Selecciona un grupo',
      searchHint: 'Buscar grupo',
      emptyMessage: 'No se encontraron grupos.',
      selectedId: selectedGroupId,
      options: availableGroups
          .map(
            (group) => ScheduleSelectorOption(
              id: group.id,
              label: group.name,
              searchText: '${group.level} ${group.section}',
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
