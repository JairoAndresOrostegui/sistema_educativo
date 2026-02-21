// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../config/enrollment_fields.dart';
import '../config/enrollment_sections.dart';
import '../controllers/enrollment_form_controller.dart';
import '../models/child_option.dart';
import '../models/enrollment_field.dart';
import '../models/submit_result.dart';
import '../export/enrollment_pdf_utils.dart';
import '../services/enrollment_submit_handler.dart';
import 'widgets/back_to_enrollment_button.dart';
import 'widgets/enrollment_child_selector.dart';
import 'widgets/enrollment_document_search_card.dart';
import 'widgets/enrollment_form_actions.dart';
import 'widgets/enrollment_fields_section.dart';
import 'widgets/enrollment_grade_history_section.dart';

enum EnrollmentEntryMode { admin, padreAutenticado, publico }

class EnrollmentFormScreen extends StatefulWidget {
  final bool isPublicLink;
  final EnrollmentEntryMode? modeOverride;
  final int? anioMatricula;
  final String? token;
  final String? enrollmentId;
  final Map<String, dynamic>? existingData;
  final String? initialEstado;

  const EnrollmentFormScreen({
    super.key,
    this.isPublicLink = false,
    this.modeOverride,
    this.anioMatricula,
    this.token,
    this.enrollmentId,
    this.existingData,
    this.initialEstado,
  });

  @override
  State<EnrollmentFormScreen> createState() => _EnrollmentFormScreenState();
}

class _EnrollmentFormScreenState extends State<EnrollmentFormScreen> {
  // moved to config\n
  late EnrollmentFormController _controller;
  final Map<int, List<EnrollmentField>> _stepFields = {};

  Map<String, TextEditingController> get _controllers =>
      _controller.controllers;
  TextEditingController get _documentLookupController =>
      _controller.documentLookupController;
  Map<String, dynamic> get _values => _controller.values;
  bool get _loadingOptions => _controller.loadingOptions;
  bool get _loadingPrefill => _controller.loadingPrefill;
  int get _pendingCount => _controller.pendingCount;
  String? get _documentoSeleccionado => _controller.documentoSeleccionado;
  String? get _currentEstado => _controller.currentEstado;
  bool get _readOnlyForm => _controller.readOnlyForm;
  List<ChildOption> get _childOptions => _controller.childOptions;
  String? get _selectedChildId => _controller.selectedChildId;
  int get _currentStep => _controller.currentStep;
  bool get _isStepCollapsed => _controller.isStepCollapsed;
  GlobalKey<FormState> get _formKey => _controller.formKey;

  @override
  void initState() {
    super.initState();
    _controller = EnrollmentFormController();
    _controller.initControllers();
    _controller.initDefaults(
      anioInicial: widget.anioMatricula,
      initialEstado: widget.initialEstado,
      existingData: widget.existingData,
      readOnly:
          widget.initialEstado == 'matriculado' &&
          _resolveMode() != EnrollmentEntryMode.admin,
    );
    _controller.loadAnioFromParameters();
    _controller.loadOptions();
    _controller.loadPendingCount(
      isAdmin: _resolveMode() == EnrollmentEntryMode.admin,
    );
    _controller.loadChildrenIfNeeded(context.read<UserProviderV2>());
  }

  @override
  void dispose() {
    _controller.disposeControllers();
    super.dispose();
  }

  List<String> _optionsFor(EnrollmentField field) {
    return _controller.optionsFor(field);
  }

  String _labelForValue(EnrollmentField field, String value) {
    return _controller.labelForValue(field, value);
  }

  List<String> _availableExternalGrades() {
    final aspirado = _controllers['gradoAspirado']?.text ?? '';
    return _controller.availableExternalGrades(aspirado);
  }

  Future<void> _showAddGradeDialog() async {
    final availableGrades = _availableExternalGrades();
    if (availableGrades.isEmpty) {
      await DialogUtils.showError(
        context: context,
        title: 'Sin grados disponibles',
        message: 'Selecciona el grado a matricular para habilitar la lista.',
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final currentYear = _controller.anioMatricula ?? DateTime.now().year;
    final yearController = TextEditingController(text: '${currentYear - 1}');
    final institutionController = TextEditingController();
    String? selectedGrade = availableGrades.first;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Agregar grado cursado'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: yearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Año',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null) return 'Año inválido';
                        if (parsed >= currentYear) {
                          return 'Debe ser menor al año activo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: institutionController,
                      decoration: const InputDecoration(
                        labelText: 'Institución',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Grado',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: selectedGrade,
                      items:
                          availableGrades
                              .map(
                                (g) => DropdownMenuItem<String>(
                                  value: g,
                                  child: Text(g),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => selectedGrade = val),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Requerido'
                                  : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    if (selectedGrade == null) return;
                    Navigator.pop(dialogContext, {
                      'anio': int.parse(yearController.text.trim()),
                      'institucion': institutionController.text.trim(),
                      'grado': selectedGrade,
                      'interno': false,
                    });
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      _controller.addExternalGradeHistory(result);
      setState(() {});
    }
  }

  Future<Map<String, dynamic>?> _showEditGradeDialog(
    Map<String, dynamic> entry,
  ) async {
    final availableGrades = _availableExternalGrades();
    final currentYear = _controller.anioMatricula ?? DateTime.now().year;

    final formKey = GlobalKey<FormState>();
    final yearController = TextEditingController(
      text: (entry['anio']?.toString() ?? '${currentYear - 1}'),
    );
    final institutionController = TextEditingController(
      text: (entry['institucion']?.toString() ?? ''),
    );
    final grades = List<String>.from(availableGrades);
    if (entry['grado'] != null && !grades.contains(entry['grado'].toString())) {
      grades.insert(0, entry['grado'].toString());
    }
    String? selectedGrade =
        entry['grado']?.toString() ?? (grades.isNotEmpty ? grades.first : null);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Editar grado cursado'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: yearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Año',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null) return 'Año inválido';
                        if (parsed >= currentYear) {
                          return 'Debe ser menor al año activo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: institutionController,
                      decoration: const InputDecoration(
                        labelText: 'Institución',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Grado',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: selectedGrade,
                      items:
                          grades
                              .map(
                                (g) => DropdownMenuItem<String>(
                                  value: g,
                                  child: Text(g),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => selectedGrade = val),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Requerido'
                                  : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    if (selectedGrade == null) return;
                    Navigator.pop(dialogContext, {
                      'anio': int.parse(yearController.text.trim()),
                      'institucion': institutionController.text.trim(),
                      'grado': selectedGrade,
                      'interno': false,
                    });
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  EnrollmentEntryMode _resolveMode() {
    if (widget.isPublicLink) return EnrollmentEntryMode.publico;
    if (widget.modeOverride != null) return widget.modeOverride!;
    final user = context.read<UserProviderV2>().user;
    final role = (user?.role ?? '').trim().toLowerCase();
    if (role == 'administrador' ||
        role == 'admin' ||
        (user?.isSuperadmin ?? false)) {
      return EnrollmentEntryMode.admin;
    }
    return EnrollmentEntryMode.padreAutenticado;
  }

  String _roleForFilters() {
    final mode = _resolveMode();
    if (mode == EnrollmentEntryMode.admin) return 'admin';
    return 'padre';
  }

  Iterable<EnrollmentField> _visibleFields() {
    final role = _roleForFilters();
    return enrollmentFieldConfig.where((f) {
      if (role == 'admin') return true;
      return f.editableBy.contains(role) || f.editableBy.contains('system');
    });
  }

  Future<void> _pickDate(
    BuildContext context,
    EnrollmentField field, {
    bool withTime = false,
  }) async {
    final now = DateTime.now();
    final ctx = context;
    final picked = await showDatePicker(
      context: ctx,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1),
    );
    if (!mounted || picked == null) return;
    var value = DateFormat('yyyy-MM-dd').format(picked);
    if (withTime) {
      final time = await showTimePicker(
        context: ctx,
        initialTime: TimeOfDay.now(),
      );
      if (!mounted) return;
      if (time != null) {
        final dt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );
        value = DateFormat('yyyy-MM-dd HH:mm').format(dt);
      }
    }
    setState(() {
      _controllers[field.name]?.text = value;
      _values[field.name] = value;
      if (field.name == 'fechaNacimiento') {
        _recomputeAge();
      }
    });
  }

  void _recomputeAge() {
    final birthStr = _controllers['fechaNacimiento']?.text ?? '';
    if (birthStr.isEmpty) return;
    try {
      final birth = DateTime.parse(birthStr);
      final now = DateTime.now();
      var age = now.year - birth.year;
      if (DateTime(now.year, birth.month, birth.day).isAfter(now)) {
        age -= 1;
      }
      _controllers['edad']?.text = age.toString();
      _values['edad'] = age.toString();
    } catch (_) {}
  }

  Future<void> _prefillByDocument() async {
    await _controller.prefillByDocument(readOnly: _readOnlyForm);
    setState(() {});
  }

  Future<void> _onChildSelected(ChildOption? selected) async {
    await _controller.onChildSelected(selected);
    setState(() {});
  }

  List<Step> _steps(
    List<EnrollmentField> visible,
    bool isAdmin,
    bool lockForDoc,
    bool requireDocStep,
    bool isBlocked,
  ) {
    List<Step> steps = [];
    final mappedNames = <String>{};
    final sectionEntries =
        <({String title, List<EnrollmentField> fields})>[];
    Step buildStep(
      String title,
      List<EnrollmentField> fields,
      int index,
      bool isLast,
    ) {
      _stepFields[index] = fields;
      final isCollapsed = _isStepCollapsed && _currentStep == index;
      return Step(
        isActive: _currentStep == index && !_isStepCollapsed,
        state: _currentStep > index ? StepState.complete : StepState.indexed,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content:
            isCollapsed
                ? const SizedBox.shrink()
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EnrollmentFieldsSection(
                      fields: fields,
                      controllers: _controllers,
                      isReadOnly:
                          (f) =>
                              !_controller.canEditField(
                                field: f,
                                role: _roleForFilters(),
                                estado: _currentEstado ?? 'prematriculado',
                                isAdmin: isAdmin,
                                lockForDoc: lockForDoc,
                              ),
                      optionsFor: _optionsFor,
                      labelForValue: _labelForValue,
                      onPickDate:
                          (field, withTime) =>
                              _pickDate(context, field, withTime: withTime),
                      gradeHistoryBuilder:
                          (field) => EnrollmentGradeHistorySection(
                            label: field.label,
                            entries: _controller.gradeHistory,
                            readOnly: _readOnlyForm || lockForDoc,
                            onAdd: _showAddGradeDialog,
                            onRemove: _controller.removeExternalGradeHistory,
                            onEdit: (entry) async {
                              final result = await _showEditGradeDialog(entry);
                              if (result != null) {
                                _controller.updateExternalGradeHistory(
                                  entry,
                                  result,
                                );
                                setState(() {});
                              }
                            },
                          ),
                      onChanged: (fieldName, v) {
                        _values[fieldName] = v;
                        if (fieldName == 'fechaNacimiento') {
                          _recomputeAge();
                        }
                        if (fieldName == 'tieneAcudienteDiferente' &&
                            (v == null || v.toLowerCase() != 'true')) {
                          const fieldsToClear = [
                            'acudientePrincipal',
                            'nombreAcudiente',
                            'cedulaAcudiente',
                            'emailAcudiente',
                            'celularAcudiente',
                            'lugarTrabajoAcudiente',
                            'ocupacionAcudiente',
                            'cargoAcudiente',
                          ];
                          for (final name in fieldsToClear) {
                            _controllers[name]?.text = '';
                            _values[name] = '';
                          }
                        }
                        // Immediate UI update and dependent field handling
                        if (fieldName == 'servicioTransporte' &&
                            (v == null || v.toLowerCase() != 'true')) {
                          // clear transporte tipo when transport is disabled
                          _controllers['servicioTransporteTipo']?.text = '';
                          _values['servicioTransporteTipo'] = '';
                        }
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!isLast || index > 0)
                      Row(
                        children: [
                          if (!isLast)
                            ElevatedButton(
                              onPressed:
                                  requireDocStep || isBlocked
                                      ? null
                                      : () {
                                        _validateStepForIndex(
                                          index,
                                          isAdmin: isAdmin,
                                          lockForDoc: lockForDoc,
                                        ).then((ok) {
                                          if (!ok) return;
                                          _controller.incrementStep();
                                        });
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Siguiente'),
                            ),
                          if (!isLast) const SizedBox(width: 8),
                          if (index > 0)
                            TextButton(
                              onPressed: _controller.decrementStep,
                              child: const Text('Anterior'),
                            ),
                        ],
                      ),
                  ],
                ),
      );
    }

    for (final section in enrollmentSections) {
      final fields = section.fieldsFrom(visible).toList();
      if (fields.isEmpty) continue;
      mappedNames.addAll(fields.map((f) => f.name));
      sectionEntries.add((title: section.title, fields: fields));
    }

    final remaining =
        visible.where((f) => !mappedNames.contains(f.name)).toList();
    final totalSteps =
        sectionEntries.length + (remaining.isNotEmpty ? 1 : 0);

    for (var i = 0; i < sectionEntries.length; i++) {
      final entry = sectionEntries[i];
      final isLast = i == totalSteps - 1;
      steps.add(buildStep(entry.title, entry.fields, i, isLast));
    }

    if (remaining.isNotEmpty) {
      steps.add(
        buildStep('Otros', remaining, totalSteps - 1, true),
      );
    }

    return steps;
  }

  Future<void> _onSubmit({
    bool matricularAhora = false,
    bool promptPrint = false,
  }) async {
    final mode = _resolveMode();
    final isAdmin = mode == EnrollmentEntryMode.admin;
    final isBlocked = !isAdmin && _controller.blockedByExistingEnrollment;
    if (isBlocked) return;
    if (_readOnlyForm && !isAdmin) return;
    if (_documentoSeleccionado == null || _documentoSeleccionado!.isEmpty) {
      await DialogUtils.showError(
        context: context,
        title: 'Falta documento',
        message:
            'Primero busca o ingresa el documento del estudiante para continuar.',
      );
      return;
    }

    final requireDocStep =
        _documentoSeleccionado == null || _documentoSeleccionado!.isEmpty;
    final lockForDoc = (requireDocStep && !_readOnlyForm) || isBlocked;
    final okRequired = await _validateAllRequiredForPadre(
      isAdmin: isAdmin,
      lockForDoc: lockForDoc,
    );
    if (!okRequired) return;

    if (!_controller.validateForm()) {
      if (_controller.lastValidationError != null &&
          _controller.lastValidationError!.isNotEmpty) {
        await DialogUtils.showError(
          context: context,
          title: 'Error de validación',
          message: _controller.lastValidationError!,
        );
      }
      return;
    }
    final userProvider = context.read<UserProviderV2>();

    final SubmitResult result = await _controller.submit(
      isAdmin: isAdmin,
      isPublicLink: widget.isPublicLink,
      matricularAhora: matricularAhora,
      enrollmentId: widget.enrollmentId,
      token: widget.token,
      currentEstadoExt: _currentEstado,
      userProvider: userProvider,
    );

    await EnrollmentSubmitHandler.handle(
      context,
      result: result,
      isEditing: widget.enrollmentId != null,
      controller: _controller,
    );

    if (promptPrint && result.success) {
      final estado = result.estado ?? _controller.currentEstado;
      if (estado == 'matriculado') {
        final shouldPrint = await _confirmPrintEnrollment();
        if (shouldPrint) {
          try {
            await EnrollmentPdfUtils.export(
              result.payload,
              estado: estado,
              anio: _controller.anioMatricula ?? DateTime.now().year,
            );
          } catch (e) {
            if (!mounted) return;
            await DialogUtils.showError(
              context: context,
              title: 'Error al imprimir',
              message: 'No fue posible generar el recibo de matricula.\n$e',
            );
          }
        }
      }
    }
  }

  Future<bool> _validateAllRequiredForPadre({
    required bool isAdmin,
    required bool lockForDoc,
  }) async {
    final role = _roleForFilters();
    if (role != 'padre') return true;
    final estado = _currentEstado ?? 'prematriculado';
    final visible = _visibleFields().toList();
    final missingLabels = <String>[];
    for (final f in visible) {
      if (!_isFieldVisibleForValidation(f)) continue;
      if (f.name == 'nivelesCursadosInstitucion') continue;
      if (!_controller.canEditField(
        field: f,
        role: role,
        estado: estado,
        isAdmin: isAdmin,
        lockForDoc: lockForDoc,
      )) {
        continue;
      }
      final required = _controller.isRequiredField(
        field: f,
        role: role,
        estado: estado,
      );
      if (!required) continue;
      final value = _controllers[f.name]?.text.trim() ?? '';
      if (value.isEmpty) {
        missingLabels.add(f.label);
      }
    }

    if (missingLabels.isEmpty) return true;
    await DialogUtils.showError(
      context: context,
      title: 'Faltan campos',
      message:
          'Completa los campos obligatorios antes de continuar:\n'
          '${missingLabels.join(', ')}',
    );
    return false;
  }

  bool _isFieldVisibleForValidation(EnrollmentField f) {
    // Keep visibility rules in sync with EnrollmentFieldsSection.
    if (f.name == 'acudientePrincipal') {
      final tieneAcudiente =
          (_controllers['tieneAcudienteDiferente']?.text ?? '')
              .toLowerCase() ==
          'true';
      return !tieneAcudiente;
    }
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
          (_controllers['tieneAcudienteDiferente']?.text ?? '')
              .toLowerCase() ==
          'true';
      return tieneAcudiente;
    }
    if (f.name == 'servicioTransporteTipo') {
      final transporteVal =
          (_controllers['servicioTransporte']?.text ?? 'false').toLowerCase();
      return transporteVal == 'true';
    }
    if ([
      'nombrePadresReferentes',
      'telefonoReferentes',
      'celularReferentes',
      'nombreReferido',
    ].contains(f.name)) {
      final fueReferido =
          (_controllers['fueReferido']?.text ?? '').toLowerCase() == 'true';
      return fueReferido;
    }
    return true;
  }

  Future<bool> _validateStepForIndex(
    int index, {
    required bool isAdmin,
    required bool lockForDoc,
  }) async {
    final role = _roleForFilters();
    if (role != 'padre') return true;
    final fields = _stepFields[index] ?? const <EnrollmentField>[];
    final estado = _currentEstado ?? 'prematriculado';
    final missingLabels = <String>[];
    for (final f in fields) {
      if (!_isFieldVisibleForValidation(f)) continue;
      if (f.name == 'nivelesCursadosInstitucion') continue;
      if (!_controller.canEditField(
        field: f,
        role: role,
        estado: estado,
        isAdmin: isAdmin,
        lockForDoc: lockForDoc,
      )) {
        continue;
      }
      final required = _controller.isRequiredField(
        field: f,
        role: role,
        estado: estado,
      );
      if (!required) continue;
      final value = _controllers[f.name]?.text.trim() ?? '';
      if (value.isEmpty) {
        missingLabels.add(f.label);
      }
    }

    if (missingLabels.isEmpty) return true;
    await DialogUtils.showError(
      context: context,
      title: 'Faltan campos',
      message:
          'Completa los campos obligatorios antes de continuar:\n'
          '${missingLabels.join(', ')}',
    );
    return false;
  }

  Future<bool> _confirmPrintEnrollment() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Imprimir'),
          content: const Text(
            '¿Desea imprimir el formulario de matrícula?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Si'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final role = _roleForFilters();
    final mode = _resolveMode();
    final isAdmin = mode == EnrollmentEntryMode.admin;
    final isBlocked = !isAdmin && _controller.blockedByExistingEnrollment;
    final requireDocStep =
        _documentoSeleccionado == null || _documentoSeleccionado!.isEmpty;
    final lockForDoc = (requireDocStep && !_readOnlyForm) || isBlocked;
    final visible = _visibleFields().toList();

    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<EnrollmentFormController>(
        builder: (_, controller, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Formulario de matrícula'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.redAccent,
              centerTitle: true,
              leading: const BackToEnrollmentButton(),
              actions: [
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Chip(
                      label: Text('Pendientes: $_pendingCount'),
                      backgroundColor: Colors.redAccent.withValues(alpha: .08),
                      labelStyle: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            backgroundColor: Colors.white,
            body:
                _loadingOptions
                    ? const Center(child: CircularProgressIndicator())
                    : SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Rol: $role ${widget.isPublicLink ? '(link público)' : ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (isBlocked)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.redAccent.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Este estudiante ya tiene una matrícula registrada para el año activo.',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (isBlocked) const SizedBox(height: 12),
                              if (_childOptions.isNotEmpty)
                                EnrollmentChildSelector(
                                  options: _childOptions,
                                  selectedChildId: _selectedChildId,
                                  onChanged: _onChildSelected,
                                ),
                              EnrollmentDocumentSearchCard(
                                controller: _documentLookupController,
                                onSearch: _prefillByDocument,
                                loading: _loadingPrefill,
                                selectedDocument: _documentoSeleccionado,
                              ),
                              const SizedBox(height: 12),
                              if (requireDocStep)
                                const Text(
                                  'Completa el documento y presiona buscar para habilitar el formulario.',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Builder(
                                builder: (context) {
                                  final steps = _steps(
                                    visible,
                                    isAdmin,
                                    lockForDoc,
                                    requireDocStep,
                                    isBlocked,
                                  );
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: Stepper(
                                      currentStep: _currentStep,
                                      type: StepperType.vertical,
                                      physics: const ClampingScrollPhysics(),
                                      controlsBuilder: (context, details) {
                                        return const SizedBox.shrink();
                                      },
                                    onStepTapped: (index) {
                                      if (requireDocStep) {
                                        DialogUtils.showError(
                                          context: context,
                                          title: 'Documento requerido',
                                          message:
                                              'Busca el documento para habilitar el formulario',
                                        );
                                        return;
                                      }
                                      // Toggle: if already open, collapse it; otherwise open it
                                      if (_currentStep == index &&
                                          !_isStepCollapsed) {
                                        _controller.toggleStepCollapse();
                                      } else {
                                        final role = _roleForFilters();
                                        if (role == 'padre' &&
                                            index > _currentStep) {
                                          _validateStepForIndex(
                                            _currentStep,
                                            isAdmin: isAdmin,
                                            lockForDoc: lockForDoc,
                                          ).then((ok) {
                                            if (!ok) return;
                                            _controller.setCurrentStep(index);
                                          });
                                        } else {
                                          _controller.setCurrentStep(index);
                                        }
                                      }
                                    },
                                      onStepContinue: () {},
                                      onStepCancel: () {},
                                      steps: steps,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              EnrollmentFormActions(
                                isAdmin: isAdmin,
                                disabled: requireDocStep || isBlocked,
                                currentEstado: _currentEstado,
                                onGuardarRevision:
                                    () => _onSubmit(promptPrint: true),
                                onMatricular:
                                    () => _onSubmit(matricularAhora: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
          );
        },
      ),
    );
  }
}
