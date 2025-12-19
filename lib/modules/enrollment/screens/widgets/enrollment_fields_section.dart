import 'package:flutter/material.dart';

import '../../models/enrollment_field.dart';
import '../../widgets/enrollment_field_input.dart';

class EnrollmentFieldsSection extends StatelessWidget {
  final List<EnrollmentField> fields;
  final Map<String, TextEditingController> controllers;
  final bool Function(EnrollmentField field) isReadOnly;
  final List<String> Function(EnrollmentField field) optionsFor;
  final Future<void> Function(EnrollmentField field, bool withTime) onPickDate;
  final void Function(String fieldName, String? value) onChanged;

  const EnrollmentFieldsSection({
    super.key,
    required this.fields,
    required this.controllers,
    required this.isReadOnly,
    required this.optionsFor,
    required this.onPickDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        ...fields.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EnrollmentFieldInput(
              field: f,
              controller: controllers[f.name]!,
              readOnly: isReadOnly(f),
              required: f.required,
              options: optionsFor(f),
              onPickDate: (withTime) => onPickDate(f, withTime),
              onChanged: (v) => onChanged(f.name, v),
            ),
          ),
        ),
      ],
    );
  }
}
