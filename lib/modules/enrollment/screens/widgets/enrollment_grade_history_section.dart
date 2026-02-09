import 'package:flutter/material.dart';

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
          Table(
            columnWidths: const {
              0: FlexColumnWidth(0.9),
              1: FlexColumnWidth(2.2),
              2: FlexColumnWidth(1.4),
              3: FixedColumnWidth(88),
            },
            border: TableBorder.all(color: Colors.grey.shade300),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Año', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Institución', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Grado', style: TextStyle(fontWeight: FontWeight.w700)),
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
                      child: Text(entry['grado']?.toString() ?? '-'),
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
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
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
          ),
        const SizedBox(height: 8),
        if (!readOnly)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle, color: Colors.redAccent),
              label: const Text('Agregar'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ),
      ],
    );
  }
}
