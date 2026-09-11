import 'package:flutter/material.dart';

import '../../../../utils/parameters_service.dart';

class EnrollmentScopeSelector extends StatelessWidget {
  final List<InstitutionOption> institutions;
  final List<String> campuses;
  final String? institutionId;
  final String? campusId;
  final ValueChanged<String> onInstitutionChanged;
  final ValueChanged<String> onCampusChanged;

  const EnrollmentScopeSelector({
    super.key,
    required this.institutions,
    required this.campuses,
    required this.institutionId,
    required this.campusId,
    required this.onInstitutionChanged,
    required this.onCampusChanged,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Institución y sede de la matrícula',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: institutions.any((item) => item.id == institutionId)
                ? institutionId
                : null,
            decoration: const InputDecoration(
              labelText: 'Institución',
              border: OutlineInputBorder(),
            ),
            items: institutions
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onInstitutionChanged(value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('$institutionId-$campusId'),
            isExpanded: true,
            initialValue: campuses.contains(campusId) ? campusId : null,
            decoration: const InputDecoration(
              labelText: 'Sede',
              border: OutlineInputBorder(),
            ),
            items: campuses
                .map(
                  (campus) => DropdownMenuItem(
                    value: campus,
                    child: Text(
                      campus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onCampusChanged(value);
            },
          ),
        ],
      ),
    ),
  );
}
