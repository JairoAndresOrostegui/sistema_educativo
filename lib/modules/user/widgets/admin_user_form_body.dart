import 'package:flutter/material.dart';

import '../../../models/user/userModelV2.dart';
import '../../../utils/parameters_service.dart';
import '../../../utils/validators.dart';
import 'admin_photo_widget.dart';

class _ShrinkOneLine extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Alignment alignment;

  const _ShrinkOneLine(
    this.text, {
    this.style,
    this.textAlign = TextAlign.left,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder:
          (ctx, constraints) => SizedBox(
            width: constraints.maxWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: alignment,
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: textAlign,
                style: style,
              ),
            ),
          ),
    );
  }
}

class AdminUserFormBody extends StatelessWidget {
  final UserModelV2? usuario;
  final bool soloLectura;
  final bool esSuperadminActual;
  final String? fotoUrl;
  final TextEditingController nombres;
  final TextEditingController apellidos;
  final TextEditingController correo;
  final TextEditingController correoInstitucional;
  final TextEditingController documento;
  final TextEditingController tipoDocumento;
  final List<Parameter> documentTypes;
  final String? selectedDocumentType;
  final void Function(String?) onDocumentTypeChanged;
  final TextEditingController direccion;
  final TextEditingController telefonos;
  final TextEditingController fechaNacimiento;
  final String rol;
  final List<Parameter> roles;
  final void Function(String?) onRolChanged;
  final String grado;
  final List<Parameter> grades;
  final String? selectedGrade;
  final void Function(String?) onGradeChanged;
  final TextEditingController institucion;
  final TextEditingController sede;
  final List<String> funcionalidades;
  final TextEditingController birthCountry;
  final TextEditingController birthDepartment;
  final TextEditingController birthCity;
  final TextEditingController residenceCountry;
  final TextEditingController residenceDepartment;
  final TextEditingController residenceCity;
  final TextEditingController familyRelation;
  final List<String> studentIds;
  final String? activeStudentId;
  final void Function(String?) setRol;
  final void Function(String?) setGrado;
  final void Function(String) setInstitucion;
  final void Function(String) setSede;
  final void Function(String permiso, bool? isChecked) onFuncionalidadChanged;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickDate;
  final bool esNuevo;
  final List<Parameter> allPermissions;
  final List<UserModelV2> availableStudents;
  final void Function(List<String>) onStudentIdsChanged;

  final String status; // 'activo' | 'inactivo'
  final void Function(String?) onStatusChanged;

  const AdminUserFormBody({
    super.key,
    this.usuario,
    required this.soloLectura,
    required this.esSuperadminActual,
    this.fotoUrl,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    required this.correoInstitucional,
    required this.documento,
    required this.tipoDocumento,
    required this.documentTypes,
    required this.selectedDocumentType,
    required this.onDocumentTypeChanged,
    required this.direccion,
    required this.telefonos,
    required this.fechaNacimiento,
    required this.rol,
    required this.roles,
    required this.onRolChanged,
    required this.grado,
    required this.grades,
    required this.selectedGrade,
    required this.onGradeChanged,
    required this.institucion,
    required this.sede,
    required this.funcionalidades,
    required this.birthCountry,
    required this.birthDepartment,
    required this.birthCity,
    required this.residenceCountry,
    required this.residenceDepartment,
    required this.residenceCity,
    required this.familyRelation,
    required this.studentIds,
    required this.activeStudentId,
    required this.setRol,
    required this.setGrado,
    required this.setInstitucion,
    required this.setSede,
    required this.onFuncionalidadChanged,
    required this.onPickPhoto,
    required this.onPickDate,
    required this.esNuevo,
    required this.allPermissions,
    required this.availableStudents,
    required this.onStudentIdsChanged,
    required this.status,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Parameter>> groupedPermissions = {};
    for (var perm in allPermissions) {
      final group = perm.etiqueta.split('.').first;
      if (!groupedPermissions.containsKey(group)) {
        groupedPermissions[group] = [];
      }
      groupedPermissions[group]!.add(perm);
    }

    final String? safeDocType =
        documentTypes.any((d) => d.valor == selectedDocumentType)
            ? selectedDocumentType
            : null;

    final String? safeRole = roles.any((r) => r.valor == rol) ? rol : null;

    final String? safeGrade =
        grades.any((g) => g.valor == selectedGrade) ? selectedGrade : null;

    return Column(
      children: [
        if (!esNuevo)
          ProfilePhotoWidget(
            imageUrl: fotoUrl,
            onTap: onPickPhoto,
            enableHoverEdit: !soloLectura,
          ),
        if (!esNuevo) const SizedBox(height: 16),

        TextFormField(
          controller: nombres,
          decoration: const InputDecoration(labelText: 'Nombres'),
          readOnly: soloLectura,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: apellidos,
          decoration: const InputDecoration(labelText: 'Apellidos'),
          readOnly: soloLectura,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            return null;
          },
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
              return 'El correo personal no es válido';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: correoInstitucional,
          decoration: const InputDecoration(labelText: 'Correo Institucional'),
          readOnly: soloLectura,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            if (!Validators.isValidEmail(value)) {
              return 'El correo institucional no es válido';
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
              return 'El documento debe tener mínimo 6 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            label: const _ShrinkOneLine('Tipo de Documento'),
          ),
          value: safeDocType,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Seleccione un tipo de documento'),
            ),
            ...documentTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type.valor,
                child: Text('${type.etiqueta} - ${type.valor}'),
              );
            }).toList(),
          ],
          onChanged: soloLectura ? null : onDocumentTypeChanged,
          validator: (value) {
            if (value == null) {
              return 'El tipo de documento es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: direccion,
          decoration: const InputDecoration(labelText: 'Dirección'),
          readOnly: soloLectura,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),

        TextFormField(
          controller: telefonos,
          decoration: const InputDecoration(
            label: _ShrinkOneLine(
              'Teléfonos: si son varios se separan con ","',
            ),
          ),
          readOnly: soloLectura,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            return null;
          },
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La fecha de nacimiento es obligatoria';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: birthCountry,
          decoration: const InputDecoration(labelText: 'País de Nacimiento'),
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
          decoration: const InputDecoration(labelText: 'País de Residencia'),
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

        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Rol'),
          value: safeRole,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Seleccione un rol'),
            ),
            ...roles.map((r) {
              return DropdownMenuItem<String>(
                value: r.valor,
                child: Text(r.etiqueta),
              );
            }).toList(),
          ],
          onChanged: soloLectura ? null : onRolChanged,
          validator: (value) {
            if (value == null) {
              return 'El rol es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Estado'),
          value: status,
          items: const [
            DropdownMenuItem(value: 'activo', child: Text('Activo')),
            DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
          ],
          onChanged: soloLectura ? null : onStatusChanged,
          validator: (value) {
            if (value == null) return 'El estado es obligatorio';
            return null;
          },
        ),

        const SizedBox(height: 8),
        if (rol == 'Estudiante' || rol == 'Docente')
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Grado'),
            value: safeGrade,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Seleccione un grado'),
              ),
              ...grades.map((g) {
                return DropdownMenuItem<String>(
                  value: g.valor,
                  child: Text('${g.valor} - ${g.etiqueta}'),
                );
              }).toList(),
            ],
            onChanged: soloLectura ? null : onGradeChanged,
            validator: (value) {
              if (value == null) {
                return 'El grado es obligatorio';
              }
              return null;
            },
          ),
        const SizedBox(height: 8),

        if (rol == 'Familiar') ...[
          TextFormField(
            controller: familyRelation,
            decoration: const InputDecoration(labelText: 'Relación Familiar'),
            readOnly: soloLectura,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Este campo es obligatorio';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Autocomplete<UserModelV2>(
            displayStringForOption:
                (UserModelV2 option) =>
                    '${option.firstName} ${option.lastName} (${option.document})',
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<UserModelV2>.empty();
              }
              return availableStudents.where((UserModelV2 option) {
                final query = textEditingValue.text.toLowerCase();
                final name =
                    '${option.firstName} ${option.lastName}'.toLowerCase();
                final document = option.document.toLowerCase();
                return name.contains(query) || document.contains(query);
              });
            },
            onSelected: (UserModelV2 selection) {
              if (!studentIds.contains(selection.id)) {
                final updatedStudentIds = List<String>.from(studentIds);
                updatedStudentIds.add(selection.id);
                onStudentIdsChanged(updatedStudentIds);
              }
            },
            fieldViewBuilder: (
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
            children:
                studentIds.map((id) {
                  final student = availableStudents.firstWhere(
                    (s) => s.id == id,
                    orElse:
                        () => UserModelV2(
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
                    onDeleted:
                        soloLectura
                            ? null
                            : () {
                              final updatedStudentIds = List<String>.from(
                                studentIds,
                              );
                              updatedStudentIds.remove(id);
                              onStudentIdsChanged(updatedStudentIds);
                            },
                  );
                }).toList(),
          ),
        ],
        const SizedBox(height: 8),

        TextFormField(
          controller: institucion,
          readOnly: soloLectura || !esSuperadminActual,
          decoration: const InputDecoration(
            labelText: 'Institución',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: sede,
          readOnly: soloLectura || !esSuperadminActual,
          decoration: const InputDecoration(
            labelText: 'Sede',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        const Text(
          'Funcionalidades',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Divider(),

        ...groupedPermissions.entries.map((entry) {
          final groupName = entry.key;
          final permissionsInGroup = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _ShrinkOneLine(
                  groupName.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Column(
                children:
                    permissionsInGroup.map((perm) {
                      final isChecked = funcionalidades.contains(perm.valor);
                      return CheckboxListTile(
                        title: _ShrinkOneLine(
                          perm.valor,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        value: isChecked,
                        onChanged:
                            soloLectura
                                ? null
                                : (bool? newValue) {
                                  onFuncionalidadChanged(perm.valor, newValue);
                                },
                      );
                    }).toList(),
              ),
            ],
          );
        }).toList(),
        const SizedBox(height: 8),
      ],
    );
  }
}
