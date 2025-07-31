import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sistema_educativo/models/user/user_model.dart';
import 'package:sistema_educativo/utils/grades_utils.dart';
import 'package:sistema_educativo/modules/auth/widgets/profile_photo_widget.dart';

class AdminUserFormBody extends StatelessWidget {
  final UsuarioModel? usuario;
  final bool soloLectura;
  final bool esSuperadminActual;
  final String? fotoUrl;
  final TextEditingController nombres;
  final TextEditingController apellidos;
  final TextEditingController correo;
  final TextEditingController correoInstitucional;
  final TextEditingController documento;
  final TextEditingController direccion;
  final TextEditingController telefonos;
  final TextEditingController fechaNacimiento;
  final String rol;
  final String grado;
  final String institucion;
  final String sede;
  final List<String> funcionalidades;
  final List<String> todasFuncionalidades;
  final void Function(String?) setRol;
  final void Function(String?) setGrado;
  final void Function(String) setInstitucion;
  final void Function(String) setSede;
  final void Function(String, bool?) onFuncionalidadChanged;
  final VoidCallback? onPickPhoto;

  const AdminUserFormBody({
    super.key,
    required this.usuario,
    required this.soloLectura,
    required this.esSuperadminActual,
    required this.fotoUrl,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    required this.correoInstitucional,
    required this.documento,
    required this.direccion,
    required this.telefonos,
    required this.fechaNacimiento,
    required this.rol,
    required this.grado,
    required this.institucion,
    required this.sede,
    required this.funcionalidades,
    required this.todasFuncionalidades,
    required this.setRol,
    required this.setGrado,
    required this.setInstitucion,
    required this.setSede,
    required this.onFuncionalidadChanged,
    this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, List<String>> agruparFuncionalidades() {
      final mapa = <String, List<String>>{};
      for (final f in todasFuncionalidades) {
        final partes = f.split('.');
        if (partes.length == 2) {
          mapa.putIfAbsent(partes[0], () => []).add(partes[1]);
        }
      }
      return mapa;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Foto de perfil del usuario. Toca para cambiarla.',
          enabled: true,
          focusable: true,
          child: ProfilePhotoWidget(
            imageUrl: fotoUrl,
            enableHoverEdit: !soloLectura,
            onTap: soloLectura ? null : onPickPhoto,
          ),
        ),

        const SizedBox(height: 12),
        _buildField(nombres, 'Nombres'),
        _buildField(apellidos, 'Apellidos'),
        _buildField(correo, 'Correo personal'),
        _buildField(correoInstitucional, 'Correo institucional'),
        _buildField(documento, 'Documento'),
        _buildField(direccion, 'Dirección'),
        _buildField(telefonos, 'Teléfonos (separados por coma)'),
        _buildField(
          fechaNacimiento,
          'Fecha de nacimiento',
          isDate: true,
          context: context,
        ),
        _buildDropdown('Rol', ['admin', 'docente', 'estudiante'], rol, setRol),
        _buildDropdown('Grado', gradosColombia, grado, setGrado),
        const SizedBox(height: 10),
        esSuperadminActual
            ? Column(
              children: [
                _buildTextFieldSoloTexto(
                  institucion,
                  'Institución',
                  setInstitucion,
                ),
                _buildTextFieldSoloTexto(sede, 'Sede', setSede),
              ],
            )
            : Column(
              children: [
                _buildReadOnly('Institución', institucion),
                _buildReadOnly('Sede', sede),
              ],
            ),
        const SizedBox(height: 10),
        if (!soloLectura)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Permisos asignados:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              ...agruparFuncionalidades().entries.map((entry) {
                final grupo = entry.key;
                final permisos = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Semantics(
                        label: 'Grupo de permisos para el módulo $grupo',
                        header: true,
                        child: Text(
                          grupo[0].toUpperCase() + grupo.substring(1),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    ...permisos.map(
                      (permiso) => Semantics(
                        label: 'Permiso $permiso para módulo $grupo',
                        enabled: true,
                        focusable: true,
                        child: CheckboxListTile(
                          title: Text(permiso),
                          value: funcionalidades.contains('$grupo.$permiso'),
                          onChanged:
                              soloLectura
                                  ? null
                                  : (bool? newValue) {
                                    onFuncionalidadChanged(
                                      '$grupo.$permiso',
                                      newValue,
                                    );
                                  },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool isDate = false,
    BuildContext? context,
  }) {
    final nombreCampo = label.toLowerCase().replaceAll(' ', '');

    final error =
        (controller.text.trim().isEmpty &&
                (nombreCampo.contains('nombres') ||
                    nombreCampo.contains('apellidos') ||
                    (nombreCampo == 'correopersonal') ||
                    (nombreCampo == 'correoinstitucional') ||
                    nombreCampo.contains('documento')))
            ? 'Campo obligatorio'
            : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: label,
        textField: true,
        enabled: true,
        focusable: true,
        child: TextField(
          controller: controller,
          readOnly: isDate,
          enabled: !soloLectura,
          onTap:
              isDate && !soloLectura
                  ? () async {
                    final picked = await showDatePicker(
                      context: context!,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      controller.text = DateFormat('yyyy-MM-dd').format(picked);
                    }
                  }
                  : null,
          decoration: InputDecoration(
            labelText:
                (label == 'Nombres' ||
                        label == 'Apellidos' ||
                        label == 'Correo personal' ||
                        label == 'Correo institucional' ||
                        label == 'Documento')
                    ? '$label *'
                    : label,
            border: const OutlineInputBorder(),
            errorText: !soloLectura ? error : null,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> opciones,
    String valor,
    Function(String?) onChanged,
  ) {
    final valorValido = opciones.contains(valor) ? valor : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: 'Campo desplegable: $label',
        enabled: true,
        focusable: true,
        child: DropdownButtonFormField<String>(
          value: valorValido,
          items:
              opciones
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
          onChanged: soloLectura ? null : onChanged,
          decoration: InputDecoration(
            labelText:
                (label == 'Rol' || label == 'Grado') ? '$label *' : label,
            helperText: 'Selecciona un $label',
            border: const OutlineInputBorder(),
            enabledBorder:
                (valor.isEmpty || valor == '')
                    ? OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    )
                    : const OutlineInputBorder(),
            errorText:
                (!soloLectura && (valor.isEmpty || valor == ''))
                    ? 'Campo obligatorio'
                    : null,
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: label,
        textField: true,
        enabled: true,
        focusable: true,
        child: TextField(
          controller: TextEditingController(text: value),
          readOnly: true,
          enabled: false,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldSoloTexto(
    String value,
    String label,
    Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label:
            '$label, campo de selección de fecha. Toca para abrir el calendario',
        textField: true,
        enabled: true,
        focusable: true,
        child: TextField(
          controller: TextEditingController(text: value),
          onChanged: onChanged,
          enabled: !soloLectura,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
