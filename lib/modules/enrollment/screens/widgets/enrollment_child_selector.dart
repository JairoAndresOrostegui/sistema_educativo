import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';

import '../../models/child_option.dart';

class EnrollmentChildSelector extends StatelessWidget {
  final List<ChildOption> options;
  final String? selectedChildId;
  final ValueChanged<ChildOption?> onChanged;

  const EnrollmentChildSelector({
    super.key,
    required this.options,
    required this.selectedChildId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona al estudiante vinculado',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppPalette.primary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(selectedChildId ?? 'none'),
          initialValue: selectedChildId,
          decoration: const InputDecoration(
            labelText: 'Estudiante',
            border: OutlineInputBorder(),
          ),
          items: options
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    '${c.nombre} • ${c.data['groupName'] ?? 'Sin grupo'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val == null) {
              onChanged(null);
              return;
            }
            final selected = options.firstWhere(
              (c) => c.id == val,
              orElse: () => options.first,
            );
            onChanged(selected);
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
