import 'package:flutter/material.dart';

import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/models/academic/academic_group.dart';
import 'package:sistema_educativo/utils/parameters_service.dart';
import 'admin_user_form_section_contact.dart';
import 'admin_user_form_section_family.dart';
import 'admin_user_form_section_institution.dart';
import 'admin_user_form_section_permissions.dart';
import 'admin_user_form_section_personal.dart';
import 'admin_user_form_section_photo.dart';
import 'admin_user_form_section_role.dart';

class AdminUserFormBody extends StatelessWidget {
  final userModelv2? usuario;
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
  final List<AcademicGroup> groups;
  final String? selectedGroupId;
  final void Function(String?) onGroupChanged;
  final TextEditingController institucion;
  final TextEditingController sede;
  final List<InstitutionOption> institutions;
  final List<String> campuses;
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
  final void Function(String) setInstitucion;
  final void Function(String) setSede;
  final void Function(String permiso, bool? isChecked) onFuncionalidadChanged;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickDate;
  final bool esNuevo;
  final List<Parameter> allPermissions;
  final List<userModelv2> availableStudents;
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
    required this.groups,
    required this.selectedGroupId,
    required this.onGroupChanged,
    required this.institucion,
    required this.sede,
    required this.institutions,
    required this.campuses,
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
    final visiblePermissions = allPermissions.where((permission) {
      if (!permission.valor.startsWith('autorizaciones.')) return true;
      if (rol == 'Estudiante') return false;
      if (rol == 'Familiar') {
        return permission.valor == 'autorizaciones.ver';
      }
      return true;
    });
    final Map<String, List<Parameter>> groupedPermissions = {};
    for (var perm in visiblePermissions) {
      final source = perm.etiqueta.isNotEmpty ? perm.etiqueta : perm.valor;
      final group = source.split('.').first;
      groupedPermissions.putIfAbsent(group, () => []).add(perm);
    }

    final String? safeDocType =
        documentTypes.any((d) => d.valor == selectedDocumentType)
        ? selectedDocumentType
        : null;
    final String? safeRole = roles.any((r) => r.valor == rol) ? rol : null;
    final String? safeGroupId = groups.any((g) => g.id == selectedGroupId)
        ? selectedGroupId
        : null;

    return Column(
      children: [
        if (!esNuevo)
          PhotoSection(
            fotoUrl: fotoUrl,
            onPickPhoto: onPickPhoto,
            soloLectura: soloLectura,
          ),
        PersonalSection(
          nombres: nombres,
          apellidos: apellidos,
          correo: correo,
          correoInstitucional: correoInstitucional,
          documento: documento,
          safeDocType: safeDocType,
          documentTypes: documentTypes,
          onDocumentTypeChanged: onDocumentTypeChanged,
          soloLectura: soloLectura,
          esNuevo: esNuevo,
        ),
        ContactSection(
          direccion: direccion,
          telefonos: telefonos,
          fechaNacimiento: fechaNacimiento,
          onPickDate: onPickDate,
          birthCountry: birthCountry,
          birthDepartment: birthDepartment,
          birthCity: birthCity,
          residenceCountry: residenceCountry,
          residenceDepartment: residenceDepartment,
          residenceCity: residenceCity,
          soloLectura: soloLectura,
        ),
        RoleSection(
          safeRole: safeRole,
          roles: roles,
          onRolChanged: onRolChanged,
          status: status,
          onStatusChanged: onStatusChanged,
          rol: rol,
          safeGroupId: safeGroupId,
          groups: groups,
          onGroupChanged: onGroupChanged,
          soloLectura: soloLectura,
        ),
        if (rol == 'Familiar')
          FamilySection(
            familyRelation: familyRelation,
            availableStudents: availableStudents,
            studentIds: studentIds,
            onStudentIdsChanged: onStudentIdsChanged,
            soloLectura: soloLectura,
          ),
        InstitutionSection(
          institucion: institucion,
          sede: sede,
          institutions: institutions,
          campuses: campuses,
          onInstitutionChanged: setInstitucion,
          onCampusChanged: setSede,
          soloLectura: soloLectura,
          esSuperadminActual: esSuperadminActual,
        ),
        PermissionsSection(
          groupedPermissions: groupedPermissions,
          funcionalidades: funcionalidades,
          onFuncionalidadChanged: onFuncionalidadChanged,
          soloLectura: soloLectura,
        ),
      ],
    );
  }
}
