import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../providers/user_provider_v2.dart';
import '../config/enrollment_fields.dart';
import '../config/enrollment_rules.dart';
import '../models/child_option.dart';
import '../models/enrollment_field.dart';
import '../models/enrollment_rule.dart';
import '../models/submit_result.dart';
import '../services/enrollment_rules_service.dart';
import '../services/enrollment_service.dart';
import '../../../utils/parameters_service.dart';

class EnrollmentFormController extends ChangeNotifier {
  final ParametersService _params;
  final EnrollmentService _enrollmentService;
  final FirebaseFirestore _firestore;
  EnrollmentRulesService _rules;

  EnrollmentFormController({
    ParametersService? params,
    EnrollmentService? enrollmentService,
    FirebaseFirestore? firestore,
    EnrollmentRulesService? rules,
  })  : _params = params ?? ParametersService(),
        _enrollmentService = enrollmentService ?? EnrollmentService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _rules = rules ?? EnrollmentRulesService(rules: enrollmentRules);

  final formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> controllers = {};
  final TextEditingController documentLookupController = TextEditingController();
  final Map<String, dynamic> values = {};

  bool loadingOptions = false;
  bool loadingPrefill = false;
  int pendingCount = 0;
  bool blockedByExistingEnrollment = false;
  List<Parameter> gradeParameters = [];
  final Map<String, int> gradeOrderByValue = {};
  List<Map<String, dynamic>> internalGradeHistory = [];
  List<Map<String, dynamic>> externalGradeHistory = [];

  List<String> tiposDocumento = ['RC', 'TI', 'CC', 'Pasaporte'];
  List<String> grados = [];
  List<String> sedes = [];
  List<String> eps = [];
  List<String> tiposSangre = ['A', 'B', 'AB', 'O'];
  Map<String, String> epsLabels = {};

  String? documentoSeleccionado;
  int? anioMatricula;
  String? currentEstado;
  bool readOnlyForm = false;
  List<ChildOption> childOptions = [];
  String? selectedChildId;
  int currentStep = 0;

  void setRules(List<EnrollmentRule> rules) {
    _rules = EnrollmentRulesService(rules: rules);
    notifyListeners();
  }

  void initControllers() {
    for (final f in enrollmentFieldConfig) {
      controllers[f.name] = TextEditingController();
    }
  }

  void initDefaults({int? anioInicial, String? initialEstado, Map<String, dynamic>? existingData, bool readOnly = false}) {
    final now = DateTime.now();
    anioMatricula = anioInicial ?? now.year;
    currentEstado = initialEstado;
    readOnlyForm = readOnly;
    _updateGradeHistoryValue();

    for (final f in enrollmentFieldConfig) {
      switch (f.defaultValue) {
        case 'currentYear':
          values[f.name] = now.year.toString();
          controllers[f.name]?.text = now.year.toString();
          break;
        case 'now':
          final formatted = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          values[f.name] = formatted;
          controllers[f.name]?.text = formatted;
          break;
        default:
          controllers[f.name] ??= TextEditingController();
      }
    }

    if (existingData != null) {
      applyPrefill(existingData);
      documentoSeleccionado = existingData['numeroIdentidad']?.toString() ?? existingData['document']?.toString();
    }
  }

  Future<void> loadAnioFromParameters() async {
    final anio = await _params.getEnrollmentYear();
    if (anio != null) {
      anioMatricula = anio;
      setValue('anioInscripcion', anio.toString());
      if (documentoSeleccionado != null && documentoSeleccionado!.isNotEmpty) {
        await checkExistingEnrollmentForDocument(documentoSeleccionado!);
        await loadInternalGradeHistory(documentoSeleccionado!);
      }
      notifyListeners();
    }
  }

  Future<void> loadOptions() async {
    loadingOptions = true;
    notifyListeners();
    try {
      final grades = await _params.getGrades();
      gradeParameters = grades;
      grados = grades.map((g) => g.valor).toList();
      gradeOrderByValue
        ..clear()
        ..addEntries(grades.map((g) => MapEntry(g.valor, g.orden)));

      final docTypes = await _params.getDocumentTypes();
      if (docTypes.isNotEmpty) {
        tiposDocumento = docTypes.map((d) => d.valor.trim()).toList();
      }

      // sedes: tomar campus distintos desde users; fallback a lista fija
      final campusesSnap = await _firestore
          .collection('users')
          .where('campus', isNotEqualTo: null)
          .limit(400)
          .get();
      final campusesSet = <String>{};
      for (final d in campusesSnap.docs) {
        final c = d.data()['campus'];
        if (c is String && c.trim().isNotEmpty) {
          campusesSet.add(c.trim());
        }
      }
      campusesSet.addAll(['Piedecuesta', 'Barrancabermeja']);
      if (campusesSet.isNotEmpty) {
        sedes = campusesSet.toList()..sort();
      }

      final epsParams = await _params.getEps();
      if (epsParams.isNotEmpty) {
        eps = epsParams.map((e) => e.valor.trim()).toList();
        epsLabels = {
          for (final e in epsParams) e.valor.trim(): (e.etiqueta).toString(),
        };
      }
    } catch (_) {
      grados = [];
    }
    if (tiposDocumento.isEmpty) {
      tiposDocumento = ['RC', 'TI', 'CC', 'Pasaporte'];
    }
    if (sedes.isEmpty) {
      sedes = ['Piedecuesta', 'Barrancabermeja'];
    }
    if (eps.isEmpty) {
      eps = ['Sura', 'Sanitas', 'Coomeva'];
    }
    if (epsLabels.isEmpty) {
      epsLabels = {
        for (final e in eps) e: e,
      };
    }
    tiposSangre = ['A', 'B', 'AB', 'O'];
    loadingOptions = false;
    notifyListeners();
  }

  Future<void> loadPendingCount({required bool isAdmin}) async {
    if (!isAdmin) return;
    try {
      pendingCount = await _enrollmentService.countByEstados(['prematriculado', 'pendiente_revision']);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadChildrenIfNeeded(UserProviderV2 userProvider) async {
    final user = userProvider.user;
    if (user == null) return;
    final role = (user.role).trim().toLowerCase();
    if (role != 'familiar' && role != 'padre' && role != 'acudiente') return;
    final ids = user.studentIds ?? [];
    if (ids.isEmpty) return;

    try {
      final snap = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: ids.length > 10 ? ids.sublist(0, 10) : ids)
          .get();
      final options = snap.docs
          .map(
            (d) => ChildOption(
              id: d.id,
              nombre: '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim(),
              document: d['document']?.toString(),
              data: d.data(),
            ),
          )
          .toList();
      childOptions = options;
      notifyListeners();
    } catch (_) {}
  }

  List<String> optionsFor(EnrollmentField field) {
    if (field.options != null) return field.options!;
    switch (field.optionsSource) {
      case 'tiposDocumento':
        return tiposDocumento;
      case 'tiposSangre':
        return tiposSangre;
      case 'grados':
        return grados;
      case 'sedes':
        return sedes;
      case 'eps':
        return eps;
      default:
        return const [];
    }
  }

  String labelForValue(EnrollmentField field, String value) {
    if (field.name == 'epsEstudiante' && epsLabels.isNotEmpty) {
      return epsLabels[value] ?? value;
    }
    return value;
  }

  void setValue(String field, String? value) {
    if (!controllers.containsKey(field) || value == null) return;
    controllers[field]?.text = value;
    values[field] = value;
  }

  void applyPrefill(Map<String, dynamic> data) {
    // Prefill directo de los campos guardados en la matrícula.
    for (final f in enrollmentFieldConfig) {
      if (data.containsKey(f.name) && data[f.name] != null) {
        setValue(f.name, data[f.name].toString());
      }
    }

    final nombres = (data['firstName'] ?? data['nombresAlumno'] ?? '').toString().trim();
    final apellidos = (data['lastName'] ?? data['apellidosAlumno'] ?? '').toString().trim();
    setValue('nombresAlumno', nombres);
    setValue('apellidosAlumno', apellidos);
    setValue('nombresApellidosAlumno', '$nombres $apellidos'.trim());
    setValue(
      'numeroIdentidad',
      data['document']?.toString() ?? data['numeroIdentidad']?.toString(),
    );
    setValue(
      'tipoIdentidad',
      data['documentType']?.toString() ?? data['tipoIdentidad']?.toString(),
    );
    setValue('tipoSangre', data['tipoSangre']?.toString());
    setValue('rh', data['rh']?.toString());
    setValue(
      'lugarNacimiento',
      data['lugarNacimiento']?.toString() ?? data['birthCity']?.toString(),
    );
    setValue(
      'direccionAlumno',
      data['address']?.toString() ?? data['direccionAlumno']?.toString(),
    );
    setValue('gradoAspirado', data['grade']?.toString() ?? data['gradoAspirado']?.toString());
    setValue(
      'telefonoAlumno',
      data['phones'] is List && (data['phones'] as List).isNotEmpty
          ? data['phones'][0].toString()
          : data['telefonoAlumno']?.toString(),
    );
    setValue('emailPadre', data['emailPadre']?.toString());
    setValue('emailMadre', data['emailMadre']?.toString());
    setValue('celularPadre', data['celularPadre']?.toString());
    setValue('celularMadre', data['celularMadre']?.toString());
    setValue('epsEstudiante', data['epsEstudiante']?.toString());
    setValue(
      'sedeAspirada',
      data['campus']?.toString() ??
          data['sede']?.toString() ??
          data['sedeAspirada']?.toString(),
    );

    final history = data['nivelesCursadosInstitucion'];
    if (history is List) {
      externalGradeHistory = history
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['interno'] != true)
          .toList();
      _updateGradeHistoryValue();
    }

    if (data['anioInscripcion'] != null) {
      final anio = int.tryParse(data['anioInscripcion'].toString());
      if (anio != null) {
        anioMatricula = anio;
        setValue('anioInscripcion', anio.toString());
      }
    }

    if (data['birthDate'] is Timestamp) {
      setValue(
        'fechaNacimiento',
        (data['birthDate'] as Timestamp).toDate().toIso8601String().split('T').first,
      );
    } else if (data['fechaNacimiento'] != null) {
      setValue('fechaNacimiento', data['fechaNacimiento'].toString());
    }
  }

  List<Map<String, dynamic>> get gradeHistory {
    final combined = [
      ...internalGradeHistory,
      ...externalGradeHistory,
    ];
    combined.sort(
      (a, b) => (a['anio'] as int? ?? 0).compareTo(b['anio'] as int? ?? 0),
    );
    return combined;
  }

  void recomputeAge() {
    final birthStr = controllers['fechaNacimiento']?.text ?? '';
    if (birthStr.isEmpty) return;
    try {
      final birth = DateTime.parse(birthStr);
      final now = DateTime.now();
      var age = now.year - birth.year;
      if (DateTime(now.year, birth.month, birth.day).isAfter(now)) {
        age -= 1;
      }
      controllers['edad']?.text = age.toString();
      values['edad'] = age.toString();
    } catch (_) {}
  }

  Future<void> checkExistingEnrollmentForDocument(String document) async {
    if (document.trim().isEmpty) return;
    final anio = anioMatricula ?? DateTime.now().year;
    try {
      blockedByExistingEnrollment = await _enrollmentService.existsByDocumentAndYear(
        document: document.trim(),
        anioMatricula: anio,
      );
    } catch (_) {
      blockedByExistingEnrollment = false;
    }
    notifyListeners();
  }

  Future<void> prefillByDocument({bool readOnly = false}) async {
    final doc = documentLookupController.text.trim();
    if (doc.isEmpty || readOnly) return;

    loadingPrefill = true;
    notifyListeners();
    Map<String, dynamic>? found;
    try {
      final usersSnap = await _firestore
          .collection('users')
          .where('document', isEqualTo: doc)
          .limit(1)
          .get();
      if (usersSnap.docs.isNotEmpty) {
        found = usersSnap.docs.first.data();
        documentoSeleccionado = doc;
      }

      if (found == null) {
        final enrollment = await _enrollmentService.getByDocument(doc);
        if (enrollment != null) {
          found = enrollment.data;
          documentoSeleccionado = doc;
        }
      }

      if (found != null) {
        applyPrefill(found);
        recomputeAge();
        documentoSeleccionado = doc;
      } else {
        documentoSeleccionado = doc;
      }
      await checkExistingEnrollmentForDocument(doc);
      await loadInternalGradeHistory(doc);
    } catch (_) {
      // ignore errors
    } finally {
      loadingPrefill = false;
      notifyListeners();
    }
  }

  Future<void> onChildSelected(ChildOption? selected) async {
    selectedChildId = selected?.id;
    if (selected == null) {
      notifyListeners();
      return;
    }
    documentoSeleccionado = selected.document;
    if (selected.document != null) {
      documentLookupController.text = selected.document!;
    }
    applyPrefill(selected.data);
    recomputeAge();
    if (selected.document != null && selected.document!.isNotEmpty) {
      await checkExistingEnrollmentForDocument(selected.document!);
      await loadInternalGradeHistory(selected.document!);
    }
    notifyListeners();
  }

  Future<void> loadInternalGradeHistory(String document) async {
    if (document.trim().isEmpty) return;
    final anio = anioMatricula ?? DateTime.now().year;
    try {
      final items = await _enrollmentService.listFinalizedByDocumentBeforeYear(
        document: document.trim(),
        anioMatricula: anio,
      );
      internalGradeHistory = items
          .where((e) => e.anioMatricula != null)
          .map((e) {
            return {
              'anio': e.anioMatricula,
              'institucion':
                  (e.data['institucion'] ?? e.data['institution'] ?? '').toString(),
              'grado':
                  (e.data['gradoAspirado'] ?? e.data['grado'] ?? '').toString(),
              'interno': true,
            };
          })
          .toList()
        ..sort(
          (a, b) =>
              (a['anio'] as int? ?? 0).compareTo((b['anio'] as int? ?? 0)),
        );
    } catch (_) {
      internalGradeHistory = [];
    }
    _updateGradeHistoryValue();
    notifyListeners();
  }

  void _updateGradeHistoryValue() {
    values['nivelesCursadosInstitucion'] = gradeHistory;
  }

  void addExternalGradeHistory(Map<String, dynamic> entry) {
    externalGradeHistory = [...externalGradeHistory, entry]
      ..sort(
        (a, b) =>
            (a['anio'] as int? ?? 0).compareTo((b['anio'] as int? ?? 0)),
      );
    _updateGradeHistoryValue();
    notifyListeners();
  }

  void removeExternalGradeHistory(Map<String, dynamic> entry) {
    externalGradeHistory = externalGradeHistory
        .where(
          (e) => !(e['anio'] == entry['anio'] &&
              e['institucion'] == entry['institucion'] &&
              e['grado'] == entry['grado'] &&
              e['interno'] == entry['interno']),
        )
        .toList();
    _updateGradeHistoryValue();
    notifyListeners();
  }

  List<String> availableExternalGrades(String? gradoAspirado) {
    if (gradoAspirado == null || gradoAspirado.isEmpty) return [];
    final aspiradoOrder = gradeOrderByValue[gradoAspirado];
    if (aspiradoOrder == null) return [];
    final internos = internalGradeHistory
        .map((e) => e['grado']?.toString())
        .whereType<String>()
        .toSet();
    return grados
        .where((g) => (gradeOrderByValue[g] ?? 9999) < aspiradoOrder)
        .where((g) => !internos.contains(g))
        .toList();
  }

  void disposeControllers() {
    for (final c in controllers.values) {
      c.dispose();
    }
    documentLookupController.dispose();
  }

  bool validateForm() {
    return formKey.currentState?.validate() ?? false;
  }

  Map<String, dynamic> collectPayload() {
    final payload = <String, dynamic>{};
    for (final entry in controllers.entries) {
      payload[entry.key] = entry.value.text;
    }
    // Nombre completo derivado para compatibilidad con vistas existentes/PDF.
    final nombres = controllers['nombresAlumno']?.text.trim() ?? '';
    final apellidos = controllers['apellidosAlumno']?.text.trim() ?? '';
    final nombreCompleto = '$nombres $apellidos'.trim();
    payload['nombresApellidosAlumno'] = nombreCompleto;
    payload.addAll(values);
    if (documentoSeleccionado != null) {
      payload['numeroIdentidad'] = documentoSeleccionado!;
    }
    if (anioMatricula != null) {
      payload['anioInscripcion'] = anioMatricula.toString();
    }
    return payload;
  }

  List<EnrollmentField> visibleFields({
    required String role,
    required String estado,
  }) {
    return enrollmentFieldConfig
        .where((f) => _rules.isVisible(field: f, role: role, estado: estado))
        .toList();
  }

  bool canEditField({
    required EnrollmentField field,
    required String role,
    required String estado,
    required bool isAdmin,
    required bool lockForDoc,
  }) {
    if (readOnlyForm || lockForDoc || blockedByExistingEnrollment) return false;
    return _rules.isEditable(
      field: field,
      role: role,
      estado: estado,
      isAdmin: isAdmin,
    );
  }

  bool isRequiredField({
    required EnrollmentField field,
    required String role,
    required String estado,
  }) {
    return _rules.isRequired(field: field, role: role, estado: estado);
  }

  Future<SubmitResult> submit({
    required bool isAdmin,
    required bool isPublicLink,
    required bool matricularAhora,
    required String? enrollmentId,
    required String? token,
    required String? currentEstadoExt,
    required UserProviderV2 userProvider,
  }) async {
    final payload = collectPayload();
    final user = userProvider.user;

    final createdByRole = isPublicLink
        ? 'publico'
        : isAdmin
            ? 'admin'
            : 'padre';
    final createdByUserId = isPublicLink ? null : user?.id;
    final isEditing = enrollmentId != null;
    final adminEstado = matricularAhora ? 'matriculado' : 'pendiente_revision';
    String estado;
    if (isAdmin) {
      if (isEditing && currentEstadoExt == 'matriculado' && !matricularAhora) {
        estado = 'matriculado'; // no bajar a pendiente si ya estaba matriculado
      } else {
        estado = adminEstado;
      }
    } else {
      estado = isEditing ? (currentEstadoExt ?? 'prematriculado') : 'prematriculado';
    }
    final fuente = isPublicLink
        ? 'qr_publico'
        : isAdmin
            ? 'admin'
            : 'app_padre';
    final anio = anioMatricula ?? DateTime.now().year;
    anioMatricula = anio;
    if ((payload['institucion'] == null || payload['institucion'].toString().isEmpty) &&
        (user?.institution ?? '').isNotEmpty) {
      payload['institucion'] = user?.institution;
    }

    try {
      if (isEditing) {
        await _enrollmentService.updateEnrollment(
          id: enrollmentId,
          data: payload,
          estado: estado,
          revisadoPor: isAdmin ? user?.id : null,
          anioMatricula: anio,
          vinculaUsuarioId: user?.id,
        );
      } else {
        await _enrollmentService.createEnrollment(
          data: payload,
          estado: estado,
          createdByRole: createdByRole,
          createdByUserId: createdByUserId,
          token: token,
          fuente: fuente,
          vinculaUsuarioId: user?.id,
          anioMatricula: anio,
        );
      }

      currentEstado = estado;
      notifyListeners();
      return SubmitResult(success: true, estado: estado, payload: payload);
    } catch (e) {
      return SubmitResult(
        success: false,
        estado: null,
        payload: payload,
        error: e.toString(),
      );
    }
  }

  void setCurrentStep(int step) {
    currentStep = step;
    notifyListeners();
  }

  void incrementStep() => setCurrentStep(currentStep + 1);

  void decrementStep() {
    if (currentStep > 0) setCurrentStep(currentStep - 1);
  }

  void setEstado(String? estado) {
    currentEstado = estado;
    notifyListeners();
  }

  void setReadOnly(bool value) {
    readOnlyForm = value;
    notifyListeners();
  }
}
