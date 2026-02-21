import 'package:flutter/material.dart';

import '../../models/enrollment_field.dart';
import '../../widgets/enrollment_field_input.dart';

class EnrollmentFieldsSection extends StatelessWidget {
  final List<EnrollmentField> fields;
  final Map<String, TextEditingController> controllers;
  final bool Function(EnrollmentField field) isReadOnly;
  final List<String> Function(EnrollmentField field) optionsFor;
  final String Function(EnrollmentField field, String value) labelForValue;
  final Future<void> Function(EnrollmentField field, bool withTime) onPickDate;
  final void Function(String fieldName, String? value) onChanged;
  final Widget Function(EnrollmentField field)? gradeHistoryBuilder;

  const EnrollmentFieldsSection({
    super.key,
    required this.fields,
    required this.controllers,
    required this.isReadOnly,
    required this.optionsFor,
    required this.labelForValue,
    required this.onPickDate,
    required this.onChanged,
    this.gradeHistoryBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        ...fields.map((f) {
          // Show acudientePrincipal only if tieneAcudienteDiferente is FALSE
          if (f.name == 'acudientePrincipal') {
            final tieneAcudiente =
                (controllers['tieneAcudienteDiferente']?.text ?? '')
                    .toLowerCase() ==
                'true';
            if (tieneAcudiente) {
              return const SizedBox.shrink();
            }
          }
          // Hide other acudiente fields unless tieneAcudienteDiferente is enabled
          if ([
            'nombreAcudiente',
            'cedulaAcudiente',
            'emailAcudiente',
            'celularAcudiente',
            'lugarTrabajoAcudiente',
            'ocupacionAcudiente',
            'cargoAcudiente',
          ].contains(f.name)) {
            final tieneAcudiente =
                (controllers['tieneAcudienteDiferente']?.text ?? '')
                    .toLowerCase() ==
                'true';
            if (!tieneAcudiente) {
              return const SizedBox.shrink();
            }
          }
          // Hide the transporte tipo field unless the transporte switch is enabled
          if (f.name == 'servicioTransporteTipo') {
            final transporteVal =
                (controllers['servicioTransporte']?.text ?? 'false')
                    .toLowerCase();
            if (transporteVal != 'true') {
              return const SizedBox.shrink();
            }
          }
          // Hide reference fields unless fueReferido is enabled
          if ([
            'nombrePadresReferentes',
            'telefonoReferentes',
            'celularReferentes',
            'nombreReferido',
          ].contains(f.name)) {
            final fueReferido =
                (controllers['fueReferido']?.text ?? '').toLowerCase() ==
                'true';
            if (!fueReferido) {
              return const SizedBox.shrink();
            }
          }
          if (f.name == 'nivelesCursadosInstitucion' &&
              gradeHistoryBuilder != null) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: gradeHistoryBuilder!(f),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EnrollmentFieldInput(
              field: f,
              controller: controllers[f.name]!,
              readOnly: isReadOnly(f),
              required: f.required,
              options: optionsFor(f),
              labelForValue: (value) => labelForValue(f, value),
              onPickDate: (withTime) => onPickDate(f, withTime),
              onChanged: (v) => onChanged(f.name, v),
            ),
          );
        }),
      ],
    );
  }
}
