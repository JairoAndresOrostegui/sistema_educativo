import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/enrollment_field.dart';

class EnrollmentFieldInput extends StatelessWidget {
  final EnrollmentField field;
  final TextEditingController controller;
  final bool readOnly;
  final bool required;
  final List<String> options;
  final String Function(String value) labelForValue;
  final Future<void> Function(bool withTime) onPickDate;
  final void Function(String) onChanged;

  const EnrollmentFieldInput({
    super.key,
    required this.field,
    required this.controller,
    required this.readOnly,
    required this.required,
    required this.options,
    required this.labelForValue,
    required this.onPickDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (field.type) {
      case 'bool':
        // Special UI for tieneAcudienteDiferente: two toggle buttons 'Si' / 'No'
        if (field.name == 'tieneAcudienteDiferente') {
          final current = (controller.text.toLowerCase() == 'true');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                field.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          readOnly
                              ? null
                              : () {
                                controller.text = 'true';
                                onChanged('true');
                              },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: current ? Colors.red : Colors.white,
                          border: Border.all(
                            color: current ? Colors.red : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              current
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: current ? Colors.white : Colors.grey[400],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Si',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color:
                                    current ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          readOnly
                              ? null
                              : () {
                                controller.text = 'false';
                                onChanged('false');
                              },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: !current ? Colors.red : Colors.white,
                          border: Border.all(
                            color: !current ? Colors.red : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              !current
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: !current ? Colors.white : Colors.grey[400],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'No',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color:
                                    !current ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        // Special UI for fueReferido: two toggle buttons 'Si' / 'No'
        if (field.name == 'fueReferido') {
          final current = (controller.text.toLowerCase() == 'true');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                field.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          readOnly
                              ? null
                              : () {
                                controller.text = 'true';
                                onChanged('true');
                              },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: current ? Colors.red : Colors.white,
                          border: Border.all(
                            color: current ? Colors.red : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              current
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: current ? Colors.white : Colors.grey[400],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Si',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color:
                                    current ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          readOnly
                              ? null
                              : () {
                                controller.text = 'false';
                                onChanged('false');
                              },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: !current ? Colors.red : Colors.white,
                          border: Border.all(
                            color: !current ? Colors.red : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              !current
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: !current ? Colors.white : Colors.grey[400],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'No',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color:
                                    !current ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
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
        // Special UI for servicioTransporteTipo: two toggle buttons
        if (field.name == 'servicioTransporteTipo') {
          final opts =
              [
                'medio_tiempo',
                'tiempo_completo',
              ].where((o) => distinctOptions.contains(o)).toList();
          final current = controller.text;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                field.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int i = 0; i < opts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap:
                            readOnly
                                ? null
                                : () {
                                  controller.text = opts[i];
                                  onChanged(opts[i]);
                                },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: current == opts[i]
                                ? Colors.red
                                : Colors.white,
                            border: Border.all(
                              color: current == opts[i]
                                  ? Colors.red
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                current == opts[i]
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: current == opts[i]
                                    ? Colors.white
                                    : Colors.grey[400],
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  labelForValue(opts[i]),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: current == opts[i]
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        }

        // Special UI for acudientePrincipal: radio buttons
        if (field.name == 'acudientePrincipal') {
          final opts =
              [
                'padre',
                'madre',
              ].where((o) => distinctOptions.contains(o)).toList();
          final current = controller.text;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...opts.map(
                (o) => RadioListTile<String>(
                  title: Text(labelForValue(o)),
                  value: o,
                  groupValue: current,
                  onChanged:
                      readOnly
                          ? null
                          : (v) {
                            if (v != null) {
                              controller.text = v;
                              onChanged(v);
                            }
                          },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          );
        }

        // Special UI for facturaElectronica: radio buttons with conditional options
        if (field.name == 'facturaElectronica') {
          final current = controller.text;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...distinctOptions.map(
                (o) => RadioListTile<String>(
                  title: Text(labelForValue(o)),
                  value: o,
                  groupValue: current,
                  onChanged:
                      readOnly
                          ? null
                          : (v) {
                            if (v != null) {
                              controller.text = v;
                              onChanged(v);
                            }
                          },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          );
        }

        final raw = controller.text;
        final current =
            raw.isEmpty || !distinctOptions.contains(raw) ? null : raw;
        return DropdownButtonFormField<String>(
          decoration: _decoration(field.label, required),
          initialValue: current,
          items:
              distinctOptions
                  .map(
                    (o) => DropdownMenuItem<String>(
                      value: o,
                      child: Text(labelForValue(o)),
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
          validator:
              (v) =>
                  (required && (v == null || v.isEmpty)) ? 'Requerido' : null,
        );
      case 'date':
      case 'datetime':
        return TextFormField(
          controller: controller,
          readOnly: true,
          decoration: _decoration(
            field.label,
            required,
          ).copyWith(suffixIcon: const Icon(Icons.calendar_today)),
          onTap: () => onPickDate(field.type == 'datetime'),
          validator:
              (v) =>
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
          validator:
              (v) =>
                  (required && (v == null || v.isEmpty)) ? 'Requerido' : null,
        );
      case 'string':
      default:
        return TextFormField(
          controller: controller,
          decoration: _decoration(field.label, required),
          readOnly: readOnly,
          onChanged: onChanged,
          validator:
              (v) =>
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
