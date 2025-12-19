// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../config/enrollment_fields.dart';
import '../config/enrollment_sections.dart';
import '../controllers/enrollment_form_controller.dart';
import '../models/child_option.dart';
import '../models/enrollment_field.dart';
import '../models/submit_result.dart';
import '../services/enrollment_submit_handler.dart';
import 'widgets/enrollment_child_selector.dart';
import 'widgets/enrollment_document_search_card.dart';
import 'widgets/enrollment_form_actions.dart';
import 'widgets/enrollment_fields_section.dart';

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

  Map<String, TextEditingController> get _controllers => _controller.controllers;
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
      readOnly: widget.initialEstado == 'matriculada' &&
          _resolveMode() != EnrollmentEntryMode.admin,
    );
    _controller.loadAnioFromParameters();
    _controller.loadOptions();
    _controller.loadPendingCount(isAdmin: _resolveMode() == EnrollmentEntryMode.admin);
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

  EnrollmentEntryMode _resolveMode() {
    if (widget.isPublicLink) return EnrollmentEntryMode.publico;
    if (widget.modeOverride != null) return widget.modeOverride!;
    final user = context.read<UserProviderV2>().user;
    final role = (user?.role ?? '').trim().toLowerCase();
    if (role == 'administrador' || role == 'admin' || (user?.isSuperadmin ?? false)) {
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

  void _onChildSelected(ChildOption? selected) {
    _controller.onChildSelected(selected);
    setState(() {});
  }

  List<Step> _steps(
    List<EnrollmentField> visible,
    bool isAdmin,
    bool lockForDoc,
  ) {
    List<Step> steps = [];
    final mappedNames = <String>{};
    Step buildStep(String title, List<EnrollmentField> fields, int index) {
      return Step(
        isActive: _currentStep >= index,
        state: _currentStep > index ? StepState.complete : StepState.indexed,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: EnrollmentFieldsSection(
          fields: fields,
          controllers: _controllers,
          isReadOnly: (f) => !_controller.canEditField(
            field: f,
            role: _roleForFilters(),
            estado: _currentEstado ?? 'prematricula',
            isAdmin: isAdmin,
            lockForDoc: lockForDoc,
          ),
          optionsFor: _optionsFor,
          onPickDate: (field, withTime) =>
              _pickDate(context, field, withTime: withTime),
          onChanged: (fieldName, v) {
            _values[fieldName] = v;
            if (fieldName == 'fechaNacimiento') {
              _recomputeAge();
            }
          },
        ),
      );
    }

    for (final section in enrollmentSections) {
      final fields = section.fieldsFrom(visible).toList();
      if (fields.isEmpty) continue;
      mappedNames.addAll(fields.map((f) => f.name));
      steps.add(buildStep(section.title, fields, steps.length));
    }

    final remaining = visible.where((f) => !mappedNames.contains(f.name)).toList();
    if (remaining.isNotEmpty) {
      steps.add(buildStep('Otros', remaining, steps.length));
    }

    return steps;
  }

  Future<void> _onSubmit({bool matricularAhora = false}) async {
    final mode = _resolveMode();
    final isAdmin = mode == EnrollmentEntryMode.admin;
    if (_readOnlyForm && !isAdmin) return;
    if (_documentoSeleccionado == null || _documentoSeleccionado!.isEmpty) {
      await DialogUtils.showError(
        context: context,
        title: 'Falta documento',
        message: 'Primero busca o ingresa el documento del estudiante para continuar.',
      );
      return;
    }

    if (!_controller.validateForm()) return;
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
  }

  @override
  Widget build(BuildContext context) {
    final role = _roleForFilters();
    final mode = _resolveMode();
    final isAdmin = mode == EnrollmentEntryMode.admin;
    final requireDocStep = _documentoSeleccionado == null || _documentoSeleccionado!.isEmpty;
    final lockForDoc = requireDocStep && !_readOnlyForm;
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
              leading: const BackToDashboardButton(),
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
            body: _loadingOptions
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
                            Builder(builder: (context) {
                              final steps = _steps(visible, isAdmin, lockForDoc);
                              final isLast = _currentStep == steps.length - 1;
                              return Stepper(
                                currentStep: _currentStep,
                                type: StepperType.vertical,
                                physics: const ClampingScrollPhysics(),
                                controlsBuilder: (context, details) {
                                  return Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: requireDocStep
                                            ? null
                                            : () {
                                                if (isLast) {
                                                  _onSubmit();
                                                } else {
                                                  _controller.incrementStep();
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text(isLast ? 'Guardar' : 'Siguiente'),
                                      ),
                                      const SizedBox(width: 8),
                                      if (_currentStep > 0)
                                        TextButton(
                                          onPressed: _controller.decrementStep,
                                          child: const Text('Anterior'),
                                        ),
                                    ],
                                  );
                                },
                                onStepTapped: _controller.setCurrentStep,
                                onStepContinue: () {},
                                onStepCancel: () {},
                                steps: steps,
                              );
                            }),
                            const SizedBox(height: 12),
                            EnrollmentFormActions(
                              isAdmin: isAdmin,
                              disabled: requireDocStep,
                              onGuardarRevision: () => _onSubmit(),
                              onMatricular: () => _onSubmit(matricularAhora: true),
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
