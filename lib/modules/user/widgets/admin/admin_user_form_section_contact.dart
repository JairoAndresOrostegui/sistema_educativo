import 'package:flutter/material.dart';

class ContactSection extends StatelessWidget {
  final TextEditingController direccion;
  final TextEditingController telefonos;
  final TextEditingController fechaNacimiento;
  final VoidCallback onPickDate;
  final TextEditingController birthCountry;
  final TextEditingController birthDepartment;
  final TextEditingController birthCity;
  final TextEditingController residenceCountry;
  final TextEditingController residenceDepartment;
  final TextEditingController residenceCity;
  final bool soloLectura;
  const ContactSection({
    super.key,
    required this.direccion,
    required this.telefonos,
    required this.fechaNacimiento,
    required this.onPickDate,
    required this.birthCountry,
    required this.birthDepartment,
    required this.birthCity,
    required this.residenceCountry,
    required this.residenceDepartment,
    required this.residenceCity,
    required this.soloLectura,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: direccion,
          decoration: const InputDecoration(labelText: 'Direccion'),
          readOnly: soloLectura,
          validator:
              (value) =>
                  (value == null || value.isEmpty)
                      ? 'Este campo es obligatorio'
                      : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: telefonos,
          decoration: const InputDecoration(
            labelText: 'Telefonos: si son varios se separan con ","',
          ),
          readOnly: soloLectura,
          validator:
              (value) =>
                  (value == null || value.isEmpty)
                      ? 'Este campo es obligatorio'
                      : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: fechaNacimiento,
          decoration: const InputDecoration(
            labelText: 'Fecha de Nacimiento',
            suffixIcon: Icon(Icons.calendar_today),
          ),
          readOnly: true,
          onTap: soloLectura ? null : onPickDate,
          validator:
              (value) =>
                  (value == null || value.isEmpty)
                      ? 'La fecha de nacimiento es obligatoria'
                      : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: birthCountry,
          decoration: const InputDecoration(labelText: 'Pais de Nacimiento'),
          readOnly: soloLectura,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: birthDepartment,
          decoration: const InputDecoration(
            labelText: 'Departamento de Nacimiento',
          ),
          readOnly: soloLectura,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: birthCity,
          decoration: const InputDecoration(labelText: 'Ciudad de Nacimiento'),
          readOnly: soloLectura,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: residenceCountry,
          decoration: const InputDecoration(labelText: 'Pais de Residencia'),
          readOnly: soloLectura,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: residenceDepartment,
          decoration: const InputDecoration(
            labelText: 'Departamento de Residencia',
          ),
          readOnly: soloLectura,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: residenceCity,
          decoration: const InputDecoration(labelText: 'Ciudad de Residencia'),
          readOnly: soloLectura,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
