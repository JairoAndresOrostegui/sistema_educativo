import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';

class EnrollmentGradeHistorySection extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> entries;
  final bool readOnly;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic> entry) onRemove;
  final void Function(Map<String, dynamic> entry)? onEdit;

  const EnrollmentGradeHistorySection({
    super.key,
    required this.label,
    required this.entries,
    required this.readOnly,
    required this.onAdd,
    required this.onRemove,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Text('Sin registros')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                return Column(
                  children: entries
                      .map((entry) => _mobileEntry(context, entry))
                      .toList(),
                );
              }
              return Table(
                columnWidths: const {
                  0: FlexColumnWidth(0.9),
                  1: FlexColumnWidth(2.2),
                  2: FlexColumnWidth(1.4),
                  3: FixedColumnWidth(88),
                },
                border: TableBorder.all(
                  color: AppPalette.outline.withValues(alpha: .35),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: AppPalette.surface),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Año',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Institución',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Grado',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox.shrink(),
                    ],
                  ),
                  ...entries.map((entry) {
                    final interno = entry['interno'] == true;
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(entry['anio']?.toString() ?? '-'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(entry['institucion']?.toString() ?? '-'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(entry['groupName']?.toString() ?? '-'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: (!readOnly && !interno)
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (onEdit != null)
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => onEdit!(entry),
                                        tooltip: 'Editar',
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: AppPalette.primary,
                                      ),
                                      onPressed: () => onRemove(entry),
                                      tooltip: 'Eliminar',
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        if (!readOnly)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add_circle, color: AppPalette.primary),
              label: const Text('Agregar'),
              style: TextButton.styleFrom(foregroundColor: AppPalette.primary),
            ),
          ),
      ],
    );
  }

  Widget _mobileEntry(BuildContext context, Map<String, dynamic> entry) {
    final interno = entry['interno'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppPalette.outline.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _mobileValue('Año', entry['anio']?.toString() ?? '-'),
            _mobileValue(
              'Institución',
              entry['institucion']?.toString() ?? '-',
            ),
            _mobileValue('Grado', entry['groupName']?.toString() ?? '-'),
            if (!readOnly && !interno)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: () => onEdit!(entry),
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                    ),
                  TextButton.icon(
                    onPressed: () => onRemove(entry),
                    icon: Icon(Icons.delete, color: AppPalette.primary),
                    label: const Text('Eliminar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _mobileValue(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
