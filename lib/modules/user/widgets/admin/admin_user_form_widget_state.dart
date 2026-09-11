part of 'admin_user_form_widget.dart';

class _AdminUserFormWidgetState extends State<AdminUserFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final AdminUserFormController _controller = AdminUserFormController();
  final ScrollController _formScrollController = ScrollController();

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
  late List<String> studentIds = [];
  String? activeStudentId;
  String rol = 'Docente';
  late TextEditingController institucion;
  late TextEditingController sede;
  String? fotoUrl;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  List<String> funcionalidades = [];
  List<Parameter> _roles = [];
  List<AcademicGroup> _groups = [];
  String? _selectedGroupId;
  bool _isLoading = true;
  bool esSuperadminActual = false;
  List<Parameter> _allPermissions = [];
  List<InstitutionOption> _institutions = [];
  List<String> _campuses = [];
  List<userModelv2> _availableStudents = [];
  String _status = 'activo';
  bool _saving = false;
  final Set<String> _loadErrors = <String>{};

  String? get _selectedGroupName {
    for (final group in _groups) {
      if (group.id == _selectedGroupId) return group.name;
    }
    return null;
  }

  String _normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }

  String _capitalizeWords(String value) {
    final normalizedSpaces = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedSpaces.isEmpty) return '';
    return normalizedSpaces
        .split(' ')
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  List<Parameter> _uniqueByValor(List<Parameter> list) {
    final seen = <String>{};
    return list.where((p) => seen.add(p.valor)).toList();
  }

  Future<void> _loadAllParameters() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadErrors.clear();
      });
    }
    try {
      await _loadInstitutions();
      await Future.wait([
        _loadDocumentTypes(),
        _loadRoles(),
        _loadPermissions(),
        _loadAvailableStudents(),
      ]);
      await _loadGroups();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _recordLoadError(String section) {
    if (!mounted) return;
    setState(() => _loadErrors.add(section));
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
      text: u?.birthDate != null
          ? '${u!.birthDate!.year}-${u.birthDate!.month.toString().padLeft(2, '0')}-${u.birthDate!.day.toString().padLeft(2, '0')}'
          : '',
    );
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
      text: esSuperadminActual
          ? (u?.institution ?? '')
          : userLogged.institution,
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
      final normalized = _normalizePermissions(permissions);
      if (!normalized.any((p) => p.valor == 'sitio_web.ver')) {
        normalized.add(
          Parameter(etiqueta: 'Sitio web', valor: 'sitio_web.ver', orden: 900),
        );
      }
      if (!normalized.any((p) => p.valor == 'sitio_web.editar')) {
        normalized.add(
          Parameter(
            etiqueta: 'Sitio web',
            valor: 'sitio_web.editar',
            orden: 901,
          ),
        );
      }
      if (!normalized.any((p) => p.valor == 'parametros.ver')) {
        normalized.add(
          Parameter(
            etiqueta: 'Configuración académica',
            valor: 'parametros.ver',
            orden: 910,
          ),
        );
      }
      if (!normalized.any((p) => p.valor == 'parametros.editar')) {
        normalized.add(
          Parameter(
            etiqueta: 'Configuración académica',
            valor: 'parametros.editar',
            orden: 911,
          ),
        );
      }
      // Filtrar DESPUÉS de completar opciones: de otro modo se reintroducían
      // permisos reservados al superadmin y el guardado era rechazado.
      if (!esSuperadminActual) {
        normalized.removeWhere(
          (permission) =>
              permission.valor.startsWith('usuarios.') ||
              permission.valor == 'historial.ver' ||
              permission.valor == 'sitio_web.editar' ||
              permission.valor == 'parametros.editar',
        );
      }
      final normalizedFuncionalidades =
          _normalizeUserPermissions(
            normalized,
            widget.usuario?.permissions ?? [],
          )..removeWhere((permission) {
            final targetRole = widget.usuario?.role ?? rol;
            if (!permission.startsWith('autorizaciones.')) return false;
            if (targetRole == 'Estudiante') return true;
            return targetRole == 'Familiar' &&
                permission != 'autorizaciones.ver';
          });
      if (mounted) {
        setState(() {
          _allPermissions = normalized;
          funcionalidades = normalizedFuncionalidades;
        });
      }
    } catch (_) {
      _recordLoadError('permisos');
    }
  }

  List<Parameter> _normalizePermissions(List<Parameter> input) {
    return input.map((p) {
      final etiqueta = p.etiqueta.trim();
      final valor = p.valor.trim();
      if (valor.contains('.')) return p;
      if (etiqueta.isEmpty) return p;
      final normalizedValue =
          '${etiqueta.toLowerCase()}.${valor.toLowerCase()}';
      return Parameter(
        etiqueta: etiqueta,
        valor: normalizedValue,
        orden: p.orden,
      );
    }).toList();
  }

  List<String> _normalizeUserPermissions(
    List<Parameter> normalizedPermissions,
    List<String> userPermissions,
  ) {
    final normalizedSet = normalizedPermissions.map((p) => p.valor).toSet();
    return userPermissions.map((perm) {
      final trimmed = perm.trim();
      if (trimmed.contains('.')) return trimmed;
      final match = normalizedSet.firstWhere(
        (p) => p.endsWith('.$trimmed'),
        orElse: () => trimmed,
      );
      return match;
    }).toList();
  }

  Future<void> _loadGroups() async {
    try {
      if (institucion.text.isEmpty || sede.text.isEmpty) return;
      final groups = await AcademicGroupService().list(
        institutionId: institucion.text,
        campusId: sede.text,
      );
      if (mounted) {
        setState(() {
          _groups = groups;
          final esNuevo = widget.usuario == null;
          final currentGroupId = widget.usuario?.groupId ?? '';
          final selected = groups.any((group) => group.id == currentGroupId)
              ? currentGroupId
              : (esNuevo && groups.isNotEmpty ? groups.first.id : null);
          _selectedGroupId = selected;
        });
      }
    } catch (_) {
      _recordLoadError('grupos académicos');
    }
  }

  Future<void> _loadDocumentTypes() async {
    try {
      final types = await ParametersService().getDocumentTypes();
      final uniqueTypes = _uniqueByValor(types);
      if (mounted) {
        setState(() {
          _documentTypes = uniqueTypes;
          _selectedDocumentType = widget.usuario?.documentType;
        });
      }
    } catch (_) {
      _recordLoadError('tipos de documento');
    }
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await ParametersService().getRoles();
      final uniqueRoles = _uniqueByValor(roles)
        ..removeWhere(
          (role) => !esSuperadminActual && role.valor == 'Administrador',
        );
      if (mounted) {
        setState(() {
          _roles = uniqueRoles;
          final esNuevo = widget.usuario == null;
          final currentRole = widget.usuario?.role ?? '';
          final selected = currentRole.isNotEmpty
              ? currentRole
              : (esNuevo && uniqueRoles.isNotEmpty
                    ? uniqueRoles.first.valor
                    : 'Estudiante');
          rol = selected;
        });
      }
    } catch (_) {
      _recordLoadError('roles');
    }
  }

  Future<void> _loadAvailableStudents() async {
    try {
      final selectedInstitution = institucion.text.trim();
      final selectedCampus = sede.text.trim();
      if (selectedInstitution.isEmpty || selectedCampus.isEmpty) {
        if (mounted) {
          setState(() {
            _availableStudents = [];
            studentIds = [];
            activeStudentId = null;
          });
        }
        return;
      }
      final students = await ParametersService().getUsersByFilters(
        institution: selectedInstitution,
        campus: selectedCampus,
        role: 'Estudiante',
      );
      if (mounted) {
        final availableIds = students.map((student) => student.id).toSet();
        setState(() {
          _availableStudents = students;
          studentIds = studentIds
              .where((studentId) => availableIds.contains(studentId))
              .toList();
          if (!studentIds.contains(activeStudentId)) {
            activeStudentId = studentIds.isEmpty ? null : studentIds.first;
          }
        });
      }
    } catch (_) {
      _recordLoadError('estudiantes vinculables');
    }
  }

  Future<void> _loadInstitutions() async {
    final logged = context.read<UserProviderV2>().user!;
    try {
      var options = await ParametersService().getInstitutions();
      if (!esSuperadminActual) {
        options = options
            .where((option) => option.id == logged.institution)
            .toList();
      }
      if (options.isEmpty && logged.institution.trim().isNotEmpty) {
        options = [
          InstitutionOption(
            id: logged.institution.trim(),
            label: logged.institution.trim(),
            campuses: [logged.campus.trim()],
          ),
        ];
      }
      if (!mounted) return;
      setState(() {
        _institutions = options;
        var selectedInstitution = institucion.text.trim();
        if (!options.any((option) => option.id == selectedInstitution)) {
          selectedInstitution = options.isEmpty ? '' : options.first.id;
          institucion.text = selectedInstitution;
        }
        final selected = options.where(
          (option) => option.id == selectedInstitution,
        );
        _campuses = selected.isEmpty ? <String>[] : selected.first.campuses;
        if (!_campuses.contains(sede.text.trim())) {
          sede.text = _campuses.isEmpty ? '' : _campuses.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _institutions = [
          InstitutionOption(
            id: logged.institution,
            label: logged.institution,
            campuses: [logged.campus],
          ),
        ];
        _campuses = [logged.campus];
      });
      _recordLoadError('instituciones y sedes');
    }
  }

  Future<void> _reloadScopeData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadErrors.remove('grupos académicos');
      _loadErrors.remove('estudiantes vinculables');
    });
    await Future.wait([_loadGroups(), _loadAvailableStudents()]);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _formScrollController.dispose();
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
    institucion.dispose();
    sede.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 600;
    final esNuevo = widget.usuario == null;
    final horizontalInset = isMobile ? 8.0 : 24.0;
    final availableHeight =
        media.size.height - media.viewInsets.bottom - (horizontalInset * 2);

    return Dialog(
      backgroundColor: AppPalette.surface,
      insetPadding: EdgeInsets.fromLTRB(
        horizontalInset,
        horizontalInset,
        horizontalInset,
        horizontalInset + media.viewInsets.bottom,
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 760,
            maxHeight: availableHeight.clamp(280.0, 900.0),
          ),
          child: Stack(
            children: [
              Scrollbar(
                controller: _formScrollController,
                thumbVisibility: !isMobile,
                child: SingleChildScrollView(
                  controller: _formScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.all(isMobile ? 12 : 24),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppPalette.primary.withValues(alpha: .15),
                      ),
                      color: AppPalette.surfaceContainer,
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.onSurface.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_loadErrors.isNotEmpty)
                              Card(
                                color: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'No se pudieron cargar: '
                                          '${_loadErrors.join(', ')}. '
                                          'Reintenta antes de guardar.',
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _loadAllParameters,
                                        child: const Text('Reintentar'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
                                  if (rol == 'Estudiante') {
                                    funcionalidades.removeWhere(
                                      (item) =>
                                          item.startsWith('autorizaciones.'),
                                    );
                                  } else if (rol == 'Familiar') {
                                    funcionalidades.removeWhere(
                                      (item) =>
                                          item.startsWith('autorizaciones.') &&
                                          item != 'autorizaciones.ver',
                                    );
                                  }
                                });
                              },
                              groups: _groups,
                              selectedGroupId: _selectedGroupId,
                              onGroupChanged: (newValue) {
                                setState(() {
                                  _selectedGroupId = newValue;
                                });
                              },
                              institucion: institucion,
                              sede: sede,
                              institutions: _institutions,
                              campuses: _campuses,
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
                              setInstitucion: (val) {
                                setState(() {
                                  institucion.text = val;
                                  final selected = _institutions.where(
                                    (option) => option.id == val,
                                  );
                                  _campuses = selected.isEmpty
                                      ? <String>[]
                                      : selected.first.campuses;
                                  sede.text = _campuses.isEmpty
                                      ? ''
                                      : _campuses.first;
                                });
                                _reloadScopeData();
                              },
                              setSede: (val) {
                                setState(() => sede.text = val);
                                _reloadScopeData();
                              },
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
                                final ctx = context;
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (!mounted) return;
                                if (picked == null) return;

                                if (await picked.length() > 5 * 1024 * 1024) {
                                  if (!mounted) return;
                                  await DialogUtils.showError(
                                    // ignore: use_build_context_synchronously
                                    context: ctx,
                                    title: 'Archivo demasiado grande',
                                    message: 'La foto no puede superar 5 MB.',
                                  );
                                  return;
                                }

                                final lowerName = picked.name.toLowerCase();
                                final extensionValida =
                                    lowerName.endsWith('.jpg') ||
                                    lowerName.endsWith('.jpeg') ||
                                    lowerName.endsWith('.png');

                                if (!extensionValida) {
                                  if (!mounted) return;
                                  DialogUtils.showError(
                                    // ignore: use_build_context_synchronously
                                    context: ctx,
                                    title: 'Formato no válido',
                                    message:
                                        'Solo se permiten imágenes JPG o PNG.',
                                  );
                                  return;
                                }

                                final bytes = await picked.readAsBytes();
                                setState(() {
                                  _pickedImageBytes = bytes;
                                  _pickedImageName = picked.name;
                                  fotoUrl = null;
                                });
                              },
                              esNuevo: esNuevo,
                              availableStudents: _availableStudents,
                              onStudentIdsChanged: (newStudentIds) {
                                setState(() {
                                  studentIds = newStudentIds;
                                  if (!studentIds.contains(activeStudentId)) {
                                    activeStudentId = studentIds.isEmpty
                                        ? null
                                        : studentIds.first;
                                  }
                                });
                              },
                              status: _status,
                              onStatusChanged: (val) =>
                                  setState(() => _status = val ?? _status),
                            ),
                            if (!widget.soloLectura)
                              Semantics(
                                label: 'Boton para guardar usuario',
                                enabled: true,
                                focusable: true,
                                button: true,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        (_isLoading ||
                                            _saving ||
                                            _loadErrors.isNotEmpty)
                                        ? null
                                        : _guardarUsuario,
                                    icon: _saving
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppPalette.surface,
                                            ),
                                          )
                                        : const Icon(Icons.save),
                                    label: Text(
                                      _saving ? 'Guardando...' : 'Guardar',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isLoading || _saving) ...[
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(
                      color: AppPalette.primary.withValues(alpha: 0.08),
                    ),
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
    final personalEmailNormalizado = _normalizeEmail(correo.text);
    final institucionalEmailNormalizado = _normalizeEmail(
      correoInstitucional.text,
    );

    final excludeId = widget.usuario?.id;
    final ok = await _controller.validarCamposUnicos(
      correoPersonal: personalEmailNormalizado,
      correoInstitucional: institucionalEmailNormalizado,
      documento: documento.text,
      excluirId: excludeId,
      onResetSaving: () {
        if (mounted) setState(() => _saving = false);
      },
      onError: (title, message) async {
        if (!mounted) return;
        await DialogUtils.showError(
          context: context,
          title: title,
          message: message,
        );
      },
    );
    if (!ok) return;

    final nuevoUsuario = userModelv2(
      id: widget.usuario?.id ?? '',
      firstName: _capitalizeWords(nombres.text),
      lastName: _capitalizeWords(apellidos.text),
      personalEmail: personalEmailNormalizado,
      institutionalEmail: institucionalEmailNormalizado,
      document: documento.text.trim(),
      documentType: _selectedDocumentType ?? 'TI',
      address: _capitalizeWords(direccion.text),
      phones: telefonos.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      birthDate: fechaNacimiento.text.trim().isEmpty
          ? null
          : DateTime.tryParse(fechaNacimiento.text.trim()),
      role: rol,
      groupId: _selectedGroupId,
      groupName: _selectedGroupName,
      institution: esSuperadminActual
          ? institucion.text
          : usuarioLogueado.institution,
      campus: esSuperadminActual ? sede.text : usuarioLogueado.campus,
      permissions: funcionalidades,
      isSuperadmin: widget.usuario?.isSuperadmin ?? false,
      webPushToken: widget.usuario?.webPushToken,
      mobilePushToken: widget.usuario?.mobilePushToken,
      photoUrl: fotoUrl ?? '',
      status: _status,
      birthCountry: _capitalizeWords(birthCountry.text),
      birthDepartment: _capitalizeWords(birthDepartment.text),
      birthCity: _capitalizeWords(birthCity.text),
      residenceCountry: _capitalizeWords(residenceCountry.text),
      residenceDepartment: _capitalizeWords(residenceDepartment.text),
      residenceCity: _capitalizeWords(residenceCity.text),
      familyRelation: _capitalizeWords(familyRelation.text),
      studentIds: studentIds,
      activeStudentId: activeStudentId,
      mustChangePassword: widget.usuario?.mustChangePassword ?? false,
      revision: widget.usuario?.revision ?? 1,
    );

    try {
      String? warning;
      if (esNuevo) {
        warning = await _controller.guardarNuevo(
          usuario: nuevoUsuario,
          fotoBytes: _pickedImageBytes,
          fotoNombre: _pickedImageName,
          usuarioLogueado: usuarioLogueado,
        );
      } else {
        await _controller.guardarExistente(
          usuario: nuevoUsuario,
          fotoBytes: _pickedImageBytes,
          fotoNombre: _pickedImageName,
          usuarioLogueado: usuarioLogueado,
        );
      }
      if (warning != null && mounted) {
        await DialogUtils.showInfo(
          context: context,
          title: 'Usuario creado con una advertencia',
          message: warning,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'Error al guardar',
          message: userFacingError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
