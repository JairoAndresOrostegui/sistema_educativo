import 'package:flutter/material.dart';

import 'package:sistema_educativo/utils/parameters_service.dart';
import 'package:sistema_educativo/utils/validators.dart';

class PersonalSection extends StatelessWidget {
  final TextEditingController nombres;
  final TextEditingController apellidos;
  final TextEditingController correo;
  final TextEditingController correoInstitucional;
  final TextEditingController documento;
  final String? safeDocType;
  final List<Parameter> documentTypes;
  final void Function(String?) onDocumentTypeChanged;
  final bool soloLectura;
  final bool esNuevo;
  const PersonalSection({
    super.key,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    required this.correoInstitucional,
    required this.documento,
    required this.safeDocType,
    required this.documentTypes,
    required this.onDocumentTypeChanged,
    required this.soloLectura,
    required this.esNuevo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nombres,
          decoration: const InputDecoration(labelText: 'Nombres'),
          readOnly: soloLectura,
          validator: (value) => (value == null || value.isEmpty)
              ? 'Este campo es obligatorio'
              : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: apellidos,
          decoration: const InputDecoration(labelText: 'Apellidos'),
          readOnly: soloLectura,
          validator: (value) => (value == null || value.isEmpty)
              ? 'Este campo es obligatorio'
              : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: correo,
          decoration: const InputDecoration(labelText: 'Correo Personal'),
          readOnly: soloLectura,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            if (!Validators.isValidEmail(value)) {
              return 'El correo personal no es valido';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: correoInstitucional,
          decoration: InputDecoration(
            labelText: esNuevo
                ? 'Correo Institucional'
                : 'Correo Institucional (no editable)',
          ),
          readOnly: soloLectura || !esNuevo,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            if (!Validators.isValidEmail(value)) {
              return 'El correo institucional no es valido';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: documento,
          decoration: const InputDecoration(labelText: 'Nro. de documento'),
          readOnly: soloLectura,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            if (value.trim().length < 6) {
              return 'El documento debe tener minimo 6 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Tipo de documento'),
          initialValue: safeDocType,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Seleccione un tipo de documento'),
            ),
            ...documentTypes.map(
              (type) => DropdownMenuItem<String>(
                value: type.valor,
                child: Text(
                  '${type.etiqueta} - ${type.valor}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: soloLectura ? null : onDocumentTypeChanged,
          validator: (value) =>
              value == null ? 'El tipo de documento es obligatorio' : null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
