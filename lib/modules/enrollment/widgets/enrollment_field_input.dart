import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/enrollment_field.dart';

class EnrollmentFieldInput extends StatelessWidget {
  final EnrollmentField field;
  final TextEditingController controller;
  final bool readOnly;
  final bool required;
  final List<String> options;
  final Future<void> Function(bool withTime) onPickDate;
  final void Function(String) onChanged;

  const EnrollmentFieldInput({
    super.key,
    required this.field,
    required this.controller,
    required this.readOnly,
    required this.required,
    required this.options,
    required this.onPickDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (field.type) {
      case 'bool':
        final current = (controller.text.toLowerCase() == 'true');
        return Row(
          children: [
            Expanded(child: Text(field.label)),
            Switch.adaptive(
              value: current,
              onChanged:
                  readOnly
                      ? null
                      : (v) {
                          controller.text = v.toString();
                          onChanged(v.toString());
                        },
            ),
          ],
        );
      case 'enum':
        final distinctOptions = LinkedHashSet<String>.from(options);
        final raw = controller.text;
        final current = raw.isEmpty || !distinctOptions.contains(raw) ? null : raw;
        return DropdownButtonFormField<String>(
          decoration: _decoration(field.label, required),
          initialValue: current,
          items:
              distinctOptions
                  .map(
                    (o) => DropdownMenuItem<String>(
                      value: o,
                      child: Text(o),
                    ),
                  )
                  .toList(),
          onChanged:
              readOnly
                  ? null
                  : (v) {
                      controller.text = v ?? '';
                      if (v != null) onChanged(v);
                    },
          validator: (v) =>
              (required && (v == null || v.isEmpty)) ? 'Requerido' : null,
        );
      case 'date':
      case 'datetime':
        return TextFormField(
          controller: controller,
          readOnly: true,
          decoration: _decoration(field.label, required).copyWith(
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () => onPickDate(field.type == 'datetime'),
          validator: (v) =>
              (required && (v == null || v.isEmpty)) ? 'Requerido' : null,
        );
      case 'int':
        return TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: _decoration(field.label, required),
          readOnly: readOnly,
          onChanged: onChanged,
          validator: (v) {
            if (required && (v == null || v.isEmpty)) return 'Requerido';
            if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
              return 'Debe ser un número';
            }
            return null;
          },
        );
      case 'text':
        return TextFormField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: _decoration(field.label, required),
          readOnly: readOnly,
          onChanged: onChanged,
          validator: (v) =>
              (required && (v == null || v.isEmpty)) ? 'Requerido' : null,
        );
      case 'string':
      default:
        return TextFormField(
          controller: controller,
          decoration: _decoration(field.label, required),
          readOnly: readOnly,
          onChanged: onChanged,
          validator: (v) =>
              (required && (v == null || v.isEmpty)) ? 'Requerido' : null,
        );
    }
  }

  InputDecoration _decoration(String label, bool required) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
