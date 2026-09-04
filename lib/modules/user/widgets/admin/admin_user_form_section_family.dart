import 'package:flutter/material.dart';

import 'package:sistema_educativo/models/user/user_model_v2.dart';

class FamilySection extends StatelessWidget {
  final TextEditingController familyRelation;
  final List<userModelv2> availableStudents;
  final List<String> studentIds;
  final void Function(List<String>) onStudentIdsChanged;
  final bool soloLectura;
  const FamilySection({
    super.key,
    required this.familyRelation,
    required this.availableStudents,
    required this.studentIds,
    required this.onStudentIdsChanged,
    required this.soloLectura,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: familyRelation,
          decoration: const InputDecoration(labelText: 'Relación familiar'),
          readOnly: soloLectura,
          validator: (value) => (value == null || value.isEmpty)
              ? 'Este campo es obligatorio'
              : null,
        ),
        const SizedBox(height: 8),
        Autocomplete<userModelv2>(
          initialValue: const TextEditingValue(text: ''),
          displayStringForOption: (option) =>
              '${option.firstName} ${option.lastName} (${option.document})',
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<userModelv2>.empty();
            }
            final query = textEditingValue.text.toLowerCase();
            return availableStudents.where((option) {
              final name = '${option.firstName} ${option.lastName}'
                  .toLowerCase();
              final document = option.document.toLowerCase();
              return name.contains(query) || document.contains(query);
            });
          },
          onSelected: (selection) {
            if (!studentIds.contains(selection.id)) {
              final updatedStudentIds = List<String>.from(studentIds)
                ..add(selection.id);
              onStudentIdsChanged(updatedStudentIds);
            }
          },
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Estudiantes a cargo',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        textEditingController.clear();
                        onStudentIdsChanged([]);
                      },
                    ),
                  ),
                );
              },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (final id in studentIds)
              _buildChip(
                id: id,
                students: availableStudents,
                onRemove: (removeId) {
                  final updated = List<String>.from(studentIds)
                    ..remove(removeId);
                  onStudentIdsChanged(updated);
                },
                soloLectura: soloLectura,
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildChip({
    required String id,
    required List<userModelv2> students,
    required void Function(String) onRemove,
    required bool soloLectura,
  }) {
    final student = students.firstWhere(
      (s) => s.id == id,
      orElse: () => userModelv2(
        id: id,
        firstName: 'Estudiante',
        lastName: 'No encontrado',
        document: '',
        documentType: '',
        personalEmail: '',
        institutionalEmail: '',
        role: 'Estudiante',
        institution: '',
        campus: '',
        isSuperadmin: false,
        status: 'activo',
        phones: [],
        permissions: [],
      ),
    );
    return Chip(
      label: Text('${student.firstName} ${student.lastName}'),
      onDeleted: soloLectura ? null : () => onRemove(id),
    );
  }
}
