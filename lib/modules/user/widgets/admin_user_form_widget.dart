import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

import '../../../models/user/userModelV2.dart';
import '../../../providers/user_provider_V2.dart';
import '../../../utils/parameters_service.dart';
import '../../profile/services/profile_service.dart';
import '../services/user_service_V2.dart';
import 'admin_user_form_body.dart';

class AdminUserFormWidget extends StatefulWidget {
  final UserModelV2? usuario;
  final bool soloLectura;
  final void Function() onSuccess;

  const AdminUserFormWidget({
    super.key,
    this.usuario,
    this.soloLectura = false,
    required this.onSuccess,
  });

  @override
  State<AdminUserFormWidget> createState() => _AdminUserFormWidgetState();
}

class _AdminUserFormWidgetState extends State<AdminUserFormWidget> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nombres;
  late TextEditingController apellidos;
  late TextEditingController correo;
  late TextEditingController correoInstitucional;
  late TextEditingController documento;
  late TextEditingController tipoDocumento;
  List<Parameter> _documentTypes = [];
  String? _selectedDocumentType;
  late TextEditingController direccion;
  late TextEditingController telefonos;
  late TextEditingController fechaNacimiento;
  late TextEditingController birthCountry;
  late TextEditingController birthDepartment;
  late TextEditingController birthCity;
  late TextEditingController residenceCountry;
  late TextEditingController residenceDepartment;
  late TextEditingController residenceCity;
  late TextEditingController familyRelation;
  late TextEditingController grado;
  late List<String> studentIds = [];
  String? activeStudentId;
  String rol = 'Docente';
  late TextEditingController institucion;
  late TextEditingController sede;
  String? fotoUrl;
  Uint8List? _pickedImageBytes;
  List<String> funcionalidades = [];
  List<Parameter> _roles = [];
  List<Parameter> _grades = [];
  String? _selectedGrade;
  bool _isLoading = true; // carga de parámetros
  bool esSuperadminActual = false;
  List<Parameter> _allPermissions = [];
  List<UserModelV2> _availableStudents = [];

  // NUEVO: estado del usuario
  String _status = 'activo'; // activo | inactivo

  // NUEVO: spinner guardando
  bool _saving = false;

  // === Helper para evitar duplicados por valor ===
  List<Parameter> _uniqueByValor(List<Parameter> list) {
    final seen = <String>{};
    return list.where((p) => seen.add(p.valor)).toList();
  }

  Future<void> _loadAllParameters() async {
    try {
      await Future.wait([
        _loadDocumentTypes(),
        _loadRoles(),
        _loadGrades(),
        _loadPermissions(),
        _loadAvailableStudents(),
      ]);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    final userLogged = context.read<UserProviderV2>().user!;

    nombres = TextEditingController(text: u?.firstName ?? '');
    apellidos = TextEditingController(text: u?.lastName ?? '');
    correo = TextEditingController(text: u?.personalEmail ?? '');
    correoInstitucional = TextEditingController(
      text: u?.institutionalEmail ?? '',
    );
    documento = TextEditingController(text: u?.document ?? '');
    tipoDocumento = TextEditingController(text: u?.documentType ?? 'CC');
    direccion = TextEditingController(text: u?.address ?? '');
    telefonos = TextEditingController(text: u?.phones.join(', ') ?? '');
    fechaNacimiento = TextEditingController(
      text:
          u?.birthDate != null
              ? '${u!.birthDate!.year}-${u.birthDate!.month.toString().padLeft(2, '0')}-${u.birthDate!.day.toString().padLeft(2, '0')}'
              : '',
    );
    grado = TextEditingController(text: u?.grade ?? '');
    fotoUrl = u?.photoUrl;
    funcionalidades = List<String>.from(u?.permissions ?? []);
    birthCountry = TextEditingController(text: u?.birthCountry ?? '');
    birthDepartment = TextEditingController(text: u?.birthDepartment ?? '');
    birthCity = TextEditingController(text: u?.birthCity ?? '');
    residenceCountry = TextEditingController(text: u?.residenceCountry ?? '');
    residenceDepartment = TextEditingController(
      text: u?.residenceDepartment ?? '',
    );
    residenceCity = TextEditingController(text: u?.residenceCity ?? '');
    familyRelation = TextEditingController(text: u?.familyRelation ?? '');
    studentIds = List<String>.from(u?.studentIds ?? []);
    activeStudentId = u?.activeStudentId;

    _status = u?.status ?? 'activo';

    esSuperadminActual = userLogged.isSuperadmin;
    institucion = TextEditingController(
      text:
          esSuperadminActual ? (u?.institution ?? '') : userLogged.institution,
    );
    sede = TextEditingController(
      text: esSuperadminActual ? (u?.campus ?? '') : userLogged.campus,
    );

    _loadAllParameters();
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        final formattedDate =
            '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
        fechaNacimiento.text = formattedDate;
      });
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final permissions = await ParametersService().getPermissions();
      if (mounted) {
        setState(() {
          _allPermissions = permissions;
          funcionalidades = List<String>.from(
            widget.usuario?.permissions ?? [],
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGrades() async {
    try {
      final grades = await ParametersService().getGrades();
      final uniqueGrades = _uniqueByValor(grades);
      if (mounted) {
        setState(() {
          _grades = uniqueGrades;
          _selectedGrade =
              widget.usuario?.grade ??
              (uniqueGrades.isNotEmpty ? uniqueGrades.first.valor : null);
          grado.text = _selectedGrade ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDocumentTypes() async {
    try {
      final types = await ParametersService().getDocumentTypes();
      final uniqueTypes = _uniqueByValor(types);
      if (mounted) {
        setState(() {
          _documentTypes = uniqueTypes;
          _selectedDocumentType = widget.usuario?.documentType ?? null;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await ParametersService().getRoles();
      final uniqueRoles = _uniqueByValor(roles);
      if (mounted) {
        setState(() {
          _roles = uniqueRoles;
          rol =
              widget.usuario?.role ??
              (uniqueRoles.isNotEmpty ? uniqueRoles.first.valor : 'Estudiante');
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAvailableStudents() async {
    try {
      final userLogged = context.read<UserProviderV2>().user!;
      final students = await ParametersService().getUsersByFilters(
        institution: userLogged.institution,
        campus: userLogged.campus,
        role: 'Estudiante',
      );
      if (mounted) {
        setState(() {
          _availableStudents = students;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    nombres.dispose();
    apellidos.dispose();
    correo.dispose();
    correoInstitucional.dispose();
    documento.dispose();
    tipoDocumento.dispose();
    direccion.dispose();
    telefonos.dispose();
    fechaNacimiento.dispose();
    birthCountry.dispose();
    birthDepartment.dispose();
    birthCity.dispose();
    residenceCountry.dispose();
    residenceDepartment.dispose();
    residenceCity.dispose();
    familyRelation.dispose();
    grado.dispose();
    institucion.dispose();
    sede.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final esNuevo = widget.usuario == null;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                isMobile
                    ? double.infinity
                    : MediaQuery.of(context).size.width * 0.55,
          ),
          // ⬇️ Stack para poder mostrar el overlay de carga por encima
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(.15)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.red.withOpacity(.06), Colors.white],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AdminUserFormBody(
                            usuario: widget.usuario,
                            soloLectura: widget.soloLectura,
                            esSuperadminActual: esSuperadminActual,
                            fotoUrl: fotoUrl,
                            nombres: nombres,
                            apellidos: apellidos,
                            correo: correo,
                            correoInstitucional: correoInstitucional,
                            documento: documento,
                            tipoDocumento: tipoDocumento,
                            documentTypes: _documentTypes,
                            selectedDocumentType: _selectedDocumentType,
                            onDocumentTypeChanged: (newValue) {
                              setState(() {
                                _selectedDocumentType = newValue;
                                tipoDocumento.text = newValue ?? '';
                              });
                            },
                            direccion: direccion,
                            telefonos: telefonos,
                            fechaNacimiento: fechaNacimiento,
                            onPickDate: _selectDate,
                            rol: rol,
                            roles: _roles,
                            onRolChanged: (newValue) {
                              setState(() {
                                rol = newValue ?? 'Estudiante';
                              });
                            },
                            grado: grado.text,
                            grades: _grades,
                            selectedGrade: _selectedGrade,
                            onGradeChanged: (newValue) {
                              setState(() {
                                _selectedGrade = newValue;
                                grado.text = newValue ?? '';
                              });
                            },
                            institucion: institucion,
                            sede: sede,
                            funcionalidades: funcionalidades,
                            allPermissions: _allPermissions,
                            birthCountry: birthCountry,
                            birthDepartment: birthDepartment,
                            birthCity: birthCity,
                            residenceCountry: residenceCountry,
                            residenceDepartment: residenceDepartment,
                            residenceCity: residenceCity,
                            familyRelation: familyRelation,
                            studentIds: studentIds,
                            activeStudentId: activeStudentId,
                            setRol: (val) => setState(() => rol = val ?? rol),
                            setGrado:
                                (val) => setState(() => grado.text = val ?? ''),
                            setInstitucion:
                                (val) => setState(() => institucion.text = val),
                            setSede: (val) => setState(() => sede.text = val),
                            onFuncionalidadChanged: (permiso, isChecked) {
                              setState(() {
                                if (isChecked == true) {
                                  if (!funcionalidades.contains(permiso)) {
                                    funcionalidades.add(permiso);
                                  }
                                } else {
                                  funcionalidades.remove(permiso);
                                }
                              });
                            },
                            onPickPhoto: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null) {
                                final bytes = await picked.readAsBytes();
                                setState(() {
                                  _pickedImageBytes = bytes;
                                  fotoUrl = null;
                                });
                              }
                            },
                            esNuevo: esNuevo,
                            availableStudents: _availableStudents,
                            onStudentIdsChanged: (newStudentIds) {
                              setState(() {
                                studentIds = newStudentIds;
                              });
                            },
                            status: _status,
                            onStatusChanged:
                                (val) =>
                                    setState(() => _status = val ?? _status),
                          ),
                          if (!widget.soloLectura)
                            Semantics(
                              label: 'Botón para guardar usuario',
                              enabled: true,
                              focusable: true,
                              button: true,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (_isLoading || _saving)
                                          ? null
                                          : _guardarUsuario,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Guardar'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ⬇️ Overlay: se muestra mientras se cargan parámetros o se guarda
              if (_isLoading || _saving) ...[
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(color: Colors.redAccent.withOpacity(0.08)),
                  ),
                ),
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() => _saving = true);

    final userProvider = context.read<UserProviderV2>();
    final usuarioLogueado = userProvider.user!;
    final esNuevo = widget.usuario == null;

    // Validación mínima del documento
    if (documento.text.trim().length < 6) {
      if (mounted) setState(() => _saving = false);
      _showError('El documento debe tener al menos 6 caracteres.');
      return;
    }

    // Validaciones de unicidad (Firestore)
    final service = UserServiceV2();
    final excludeId = widget.usuario?.id;

    // Correo personal
    if (await service.existeCorreoPersonal(
      correo.text.trim(),
      excluirId: excludeId,
    )) {
      if (mounted) setState(() => _saving = false);
      _showError('El correo personal ya está registrado.');
      return;
    }
    // Correo institucional
    if (await service.existeCorreoInstitucional(
      correoInstitucional.text.trim(),
      excluirId: excludeId,
    )) {
      if (mounted) setState(() => _saving = false);
      _showError('El correo institucional ya está registrado.');
      return;
    }
    // Documento
    if (await service.existeDocumento(
      documento.text.trim(),
      excluirId: excludeId,
    )) {
      if (mounted) setState(() => _saving = false);
      _showError('El documento ya está registrado.');
      return;
    }

    String? nuevaFotoUrl;

    final nuevoUsuario = UserModelV2(
      id: widget.usuario?.id ?? '',
      firstName: nombres.text.trim(),
      lastName: apellidos.text.trim(),
      personalEmail: correo.text.trim(),
      institutionalEmail: correoInstitucional.text.trim(),
      document: documento.text.trim(),
      documentType: _selectedDocumentType ?? 'TI',
      address: direccion.text.trim(),
      phones:
          telefonos.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
      birthDate:
          fechaNacimiento.text.trim().isEmpty
              ? null
              : DateTime.tryParse(fechaNacimiento.text.trim()),
      role: rol,
      grade: _selectedGrade ?? '',
      institution:
          esSuperadminActual ? institucion.text : usuarioLogueado.institution,
      campus: esSuperadminActual ? sede.text : usuarioLogueado.campus,
      permissions: funcionalidades,
      isSuperadmin: widget.usuario?.isSuperadmin ?? false,
      fcmToken: widget.usuario?.fcmToken ?? '',
      photoUrl: fotoUrl ?? '',
      status: _status,
      birthCountry: birthCountry.text.trim(),
      birthDepartment: birthDepartment.text.trim(),
      birthCity: birthCity.text.trim(),
      residenceCountry: residenceCountry.text.trim(),
      residenceDepartment: residenceDepartment.text.trim(),
      residenceCity: residenceCity.text.trim(),
      familyRelation: familyRelation.text.trim(),
      studentIds: studentIds,
      activeStudentId: activeStudentId,
    );

    try {
      if (esNuevo) {
        final uid = await service.crearUsuarioDesdeAdmin(
          email: nuevoUsuario.institutionalEmail,
          password: nuevoUsuario.document,
          nombres: nuevoUsuario.firstName,
          apellidos: nuevoUsuario.lastName,
          rol: nuevoUsuario.role,
          documento: nuevoUsuario.document,
        );

        if (_pickedImageBytes != null) {
          nuevaFotoUrl = await ProfileService().subirFotoPerfil(
            bytes: _pickedImageBytes!,
            uid: uid,
          );
        }

        final usuarioConUid = nuevoUsuario.copyWith(
          id: uid,
          photoUrl: nuevaFotoUrl,
        );
        await service.guardarUsuario(usuarioConUid);
        await service.registrarHistorial(
          usuario: usuarioConUid,
          accion: 'creado',
          realizadoPor:
              '${usuarioLogueado.firstName} ${usuarioLogueado.lastName}',
        );
      } else {
        if (_pickedImageBytes != null) {
          nuevaFotoUrl = await ProfileService().subirFotoPerfil(
            bytes: _pickedImageBytes!,
            uid: nuevoUsuario.id,
          );
        }
        final usuarioEditado = nuevoUsuario.copyWith(
          photoUrl: nuevaFotoUrl ?? nuevoUsuario.photoUrl,
        );
        await service.guardarUsuario(usuarioEditado);
        await service.registrarHistorial(
          usuario: usuarioEditado,
          accion: 'editado',
          realizadoPor:
              '${usuarioLogueado.firstName} ${usuarioLogueado.lastName}',
        );
      }

      if (mounted) {
        // No hace falta setState(false) porque cerramos el diálogo
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        // Cerramos con error (si prefieres mantener abierto, elimina este pop y haz setState(false))
        Navigator.of(context).pop(false);
      }
    } finally {
      // Si el diálogo siguiera abierto (por cambios futuros), apagamos el spinner
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Validación'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );
  }
}
