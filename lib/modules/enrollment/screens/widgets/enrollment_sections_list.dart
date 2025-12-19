import 'package:flutter/material.dart';

import '../../models/enrollment_field.dart';
import '../../models/enrollment_section.dart';
import 'enrollment_fields_section.dart';

class EnrollmentSectionsList extends StatelessWidget {
  final List<EnrollmentField> visibleFields;
  final Map<String, TextEditingController> controllers;
  final bool Function(EnrollmentField field) isReadOnly;
  final List<String> Function(EnrollmentField field) optionsFor;
  final Future<void> Function(EnrollmentField field, bool withTime) onPickDate;
  final void Function(String fieldName, String? value) onChanged;
  final List<EnrollmentSection> sections;

  const EnrollmentSectionsList({
    super.key,
    required this.visibleFields,
    required this.controllers,
    required this.isReadOnly,
    required this.optionsFor,
    required this.onPickDate,
    required this.onChanged,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final mappedNames = <String>{};
    final tiles = <Widget>[];

    for (final section in sections) {
      final fields = section
          .fieldsFrom(visibleFields)
          .toList()
          ..sort((a, b) => section.fieldNames.indexOf(a.name).compareTo(section.fieldNames.indexOf(b.name)));
      if (fields.isEmpty) continue;
      mappedNames.addAll(fields.map((f) => f.name));
      tiles.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.redAccent.withValues(alpha: .12),
            ),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: Text(
              section.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
            children: [
              EnrollmentFieldsSection(
                fields: fields,
                controllers: controllers,
                isReadOnly: isReadOnly,
                optionsFor: optionsFor,
                onPickDate: onPickDate,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      );
    }

    final remaining = visibleFields.where((f) => !mappedNames.contains(f.name)).toList();
    if (remaining.isNotEmpty) {
      tiles.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.redAccent.withValues(alpha: .12),
            ),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: const Text(
              'Otros',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
            children: [
              EnrollmentFieldsSection(
                fields: remaining,
                controllers: controllers,
                isReadOnly: isReadOnly,
                optionsFor: optionsFor,
                onPickDate: onPickDate,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: tiles);
  }
}
