import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../models/academic/academic_group.dart';
import '../config/enrollment_fields.dart';
import '../config/enrollment_rules.dart';
import '../models/child_option.dart';
import '../models/enrollment_field.dart';
import '../models/enrollment_rule.dart';
import '../models/submit_result.dart';
import '../services/enrollment_rules_service.dart';
import '../services/enrollment_service.dart';
import '../../../utils/parameters_service.dart';
import '../../../utils/user_facing_error.dart';
import '../../../utils/active_academic_year_context.dart';
import '../../user/services/active_student_service.dart';

class EnrollmentFormController extends ChangeNotifier {
  final ParametersService _params;
  final EnrollmentService _enrollmentService;
  final FirebaseFirestore _firestore;
  final Future<Map<String, dynamic>> Function()? publicOptionsLoader;
  EnrollmentRulesService _rules;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }

  EnrollmentFormController({
    ParametersService? params,
    EnrollmentService? enrollmentService,
    FirebaseFirestore? firestore,
    EnrollmentRulesService? rules,
    this.publicOptionsLoader,
  }) : _params = params ?? ParametersService(),
       _enrollmentService = enrollmentService ?? EnrollmentService(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _rules = rules ?? EnrollmentRulesService(rules: enrollmentRules);

  final formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> controllers = {};
  final TextEditingController documentLookupController =
      TextEditingController();
  final Map<String, dynamic> values = {};

  bool loadingOptions = false;
  String? optionsError;
  final Map<String, int> _scopeYears = {};
  bool loadingPrefill = false;
  int pendingCount = 0;
  bool blockedByExistingEnrollment = false;
  final Map<String, int> gradeOrderByValue = {};
  List<Map<String, dynamic>> internalGradeHistory = [];
  List<Map<String, dynamic>> externalGradeHistory = [];

  List<String> tiposDocumento = [];
  List<String> grados = [];
  List<AcademicGroup> academicGroups = [];
  List<String> sedes = [];
  List<String> eps = [];
  List<String> tiposSangre = ['A', 'B', 'AB', 'O'];
  List<InstitutionOption> institutionOptions = [];
  String? selectedInstitutionId;
  String? selectedCampusId;
  Map<String, String> epsLabels = {};

  String? documentoSeleccionado;
  String? activeEnrollmentId;
  String? activeEnrollmentStatus;
  int? activeEnrollmentRevision;
  int? anioMatricula;
  String? currentEstado;
  bool readOnlyForm = false;
  List<ChildOption> childOptions = [];
  String? selectedChildId;
  int currentStep = 0;
  bool isStepCollapsed = true;
  String? lastValidationError;

  void setRules(List<EnrollmentRule> rules) {
    _rules = EnrollmentRulesService(rules: rules);
    notifyListeners();
  }

  void initControllers() {
    for (final f in enrollmentFieldConfig) {
      controllers[f.name] = TextEditingController();
    }
  }

  void initDefaults({
    int? anioInicial,
    String? initialEstado,
    String? initialLinkedStudentId,
    Map<String, dynamic>? existingData,
    int? initialRevision,
    bool readOnly = false,
  }) {
    final now = DateTime.now();
    anioMatricula = anioInicial;
    currentEstado = initialEstado;
    activeEnrollmentRevision = initialRevision;
    selectedChildId = initialLinkedStudentId;
    readOnlyForm = readOnly;
    _updateGradeHistoryValue();

    for (final f in enrollmentFieldConfig) {
      switch (f.defaultValue) {
        case 'currentYear':
          values[f.name] = anioInicial?.toString() ?? '';
          controllers[f.name]?.text = anioInicial?.toString() ?? '';
          break;
        case 'now':
          final formatted =
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          values[f.name] = formatted;
          controllers[f.name]?.text = formatted;
          break;
        default:
          controllers[f.name] ??= TextEditingController();
      }
    }

    if (existingData != null) {
      applyPrefill(existingData);
      documentoSeleccionado =
          existingData['numeroIdentidad']?.toString() ??
          existingData['document']?.toString();
    }
  }

  Future<void> loadOptions({
    UserProviderV2? userProvider,
    bool publicMode = false,
  }) async {
    if (_disposed) return;
    loadingOptions = true;
    optionsError = null;
    notifyListeners();
    try {
      final user = userProvider?.user;
      if (publicMode || user == null) {
        await _loadPublicOptions();
      } else {
        Query<Map<String, dynamic>> groupQuery = _firestore
            .collection('academic_groups')
            .where('active', isEqualTo: true);
        var shouldLoadGroups = true;
        if (!user.isSuperadmin) {
          final activeYear = await loadActiveAcademicYear(
            firestore: _firestore,
            institutionId: user.institution,
            campusId: user.campus,
          );
          if (_disposed) return;
          groupQuery = groupQuery
              .where('institutionId', isEqualTo: user.institution)
              .where('campusId', isEqualTo: user.campus)
              .where('academicYearId', isEqualTo: activeYear.id);
        } else {
          final activeYearIds = await loadAllActiveAcademicYearIds(
            firestore: _firestore,
          );
          if (_disposed) return;
          if (activeYearIds.isEmpty) {
            academicGroups = [];
            grados = [];
            shouldLoadGroups = false;
          } else if (activeYearIds.length > 30) {
            throw StateError('Hay demasiadas sedes para cargar sus grupos.');
          } else {
            groupQuery = groupQuery.where(
              'academicYearId',
              whereIn: activeYearIds,
            );
          }
        }
        if (shouldLoadGroups) {
          final groupSnapshot = await groupQuery.get();
          if (_disposed) return;
          academicGroups = groupSnapshot.docs
              .map(AcademicGroup.fromDocument)
              .toList();
          _rememberScopeYears(groupSnapshot.docs.map((doc) => doc.data()));
        }
        academicGroups.sort((a, b) => a.order.compareTo(b.order));
        grados = academicGroups.map((g) => g.level).toSet().toList();
        gradeOrderByValue
          ..clear()
          ..addEntries(academicGroups.map((g) => MapEntry(g.level, g.order)));

        final docTypes = await _params.getDocumentTypes();
        if (_disposed) return;
        if (docTypes.isNotEmpty) {
          tiposDocumento = docTypes.map((d) => d.valor.trim()).toList();
        }

        institutionOptions = await _params.getInstitutions();
        if (_disposed) return;
        if (!user.isSuperadmin) {
          institutionOptions = institutionOptions
              .where((item) => item.id == user.institution)
              .toList();
          selectedInstitutionId = user.institution;
          selectedCampusId = user.campus;
        } else {
          selectedInstitutionId ??= institutionOptions.isEmpty
              ? null
              : institutionOptions.first.id;
          final selectedInstitution = institutionOptions.where(
            (item) => item.id == selectedInstitutionId,
          );
          final availableCampuses = selectedInstitution.isEmpty
              ? const <String>[]
              : selectedInstitution.first.campuses;
          selectedCampusId ??= availableCampuses.isEmpty
              ? null
              : availableCampuses.first;
        }
        _refreshCampuses();
        if ((selectedCampusId ?? '').isNotEmpty) {
          setValue('sedeAspirada', selectedCampusId);
        }

        final epsParams = await _params.getEps();
        if (_disposed) return;
        if (epsParams.isNotEmpty) {
          eps = epsParams.map((e) => e.valor.trim()).toList();
          epsLabels = {
            for (final e in epsParams) e.valor.trim(): (e.etiqueta).toString(),
          };
        }
      }
      if (_disposed) return;
      if (academicGroups.isEmpty || institutionOptions.isEmpty) {
        throw StateError(
          'La institución no tiene grupos vigentes disponibles para matrícula.',
        );
      }
      if (tiposDocumento.isEmpty || eps.isEmpty) {
        throw StateError(
          'Falta configurar los tipos de documento o las EPS. Comunícate con administración.',
        );
      }
      _applyScopeYear();
    } catch (error) {
      if (_disposed) return;
      optionsError = userFacingError(
        error,
        fallback: 'No se pudo cargar la configuración de matrícula.',
      );
    }
    tiposSangre = ['A', 'B', 'AB', 'O'];
    loadingOptions = false;
    notifyListeners();
  }

  Future<void> _loadPublicOptions() async {
    final loader = publicOptionsLoader;
    final data = loader != null
        ? await loader()
        : Map<String, dynamic>.from(
            (await FirebaseFunctions.instance
                        .httpsCallable('obtenerOpcionesMatriculaPublica')
                        .call())
                    .data
                as Map,
          );
    if (_disposed) return;
    List<Map<String, dynamic>> entries(String key) =>
        (data[key] as List? ?? const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
    final rawGroups = entries('groups');
    academicGroups = rawGroups.map(AcademicGroup.fromMap).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    _rememberScopeYears(rawGroups);
    grados = academicGroups.map((group) => group.level).toSet().toList();
    gradeOrderByValue
      ..clear()
      ..addEntries(
        academicGroups.map((group) => MapEntry(group.level, group.order)),
      );
    institutionOptions = entries('institutions')
        .map(
          (entry) => InstitutionOption(
            id: (entry['id'] ?? '').toString(),
            label: (entry['label'] ?? '').toString(),
            campuses: (entry['campuses'] as List? ?? const [])
                .map((value) => value.toString())
                .toList(),
          ),
        )
        .toList();
    if (!institutionOptions.any((item) => item.id == selectedInstitutionId)) {
      selectedInstitutionId = institutionOptions.firstOrNull?.id;
    }
    _refreshCampuses();
    setValue('sedeAspirada', selectedCampusId ?? '');
    tiposDocumento = entries('documentTypes')
        .map((entry) => (entry['valor'] ?? '').toString())
        .where((value) => value.isNotEmpty)
        .toList();
    final epsEntries = entries('eps');
    eps = epsEntries
        .map((entry) => (entry['valor'] ?? '').toString())
        .where((value) => value.isNotEmpty)
        .toList();
    epsLabels = {
      for (final entry in epsEntries)
        (entry['valor'] ?? '').toString():
            (entry['etiqueta'] ?? entry['valor'] ?? '').toString(),
    };
  }

  void _rememberScopeYears(Iterable<Map<String, dynamic>> groups) {
    _scopeYears.clear();
    for (final group in groups) {
      final year = (group['academicYear'] as num?)?.toInt();
      if (year != null) {
        _scopeYears['${group['institutionId']}:${group['campusId']}'] = year;
      }
    }
  }

  void _applyScopeYear() {
    if (currentEstado != null || activeEnrollmentId != null || readOnlyForm) {
      return;
    }
    anioMatricula = _scopeYears['$selectedInstitutionId:$selectedCampusId'];
    setValue('anioInscripcion', anioMatricula?.toString() ?? '');
  }

  void _refreshCampuses() {
    final selected = institutionOptions.where(
      (item) => item.id == selectedInstitutionId,
    );
    sedes = selected.isEmpty ? <String>[] : [...selected.first.campuses];
    sedes.sort();
    if (!sedes.contains(selectedCampusId)) {
      selectedCampusId = sedes.isEmpty ? null : sedes.first;
    }
  }

  void selectInstitution(String institutionId) {
    if (selectedInstitutionId == institutionId) return;
    selectedInstitutionId = institutionId;
    selectedCampusId = null;
    _refreshCampuses();
    _applyScopeYear();
    setValue('sedeAspirada', selectedCampusId ?? '');
    setValue('groupId', '');
    notifyListeners();
  }

  void selectCampus(String campusId) {
    if (!sedes.contains(campusId)) return;
    selectedCampusId = campusId;
    _applyScopeYear();
    setValue('sedeAspirada', campusId);
    final currentGroupId = controllers['groupId']?.text ?? '';
    final groupIsValid = academicGroups.any(
      (group) =>
          group.id == currentGroupId &&
          group.institutionId == selectedInstitutionId &&
          group.campusId == campusId,
    );
    if (!groupIsValid) setValue('groupId', '');
    notifyListeners();
  }

  Future<void> loadPendingCount({
    required bool isAdmin,
    UserProviderV2? userProvider,
  }) async {
    if (!isAdmin) return;
    final user = userProvider?.user;
    try {
      pendingCount = await _enrollmentService.countByEstados(
        ['prematriculado', 'pendiente_revision', 'correccion_solicitada'],
        institution: user?.isSuperadmin == true ? null : user?.institution,
        campus: user?.isSuperadmin == true ? null : user?.campus,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadChildrenIfNeeded(UserProviderV2 userProvider) async {
    if (_disposed) return;
    final user = userProvider.user;
    if (user == null) return;
    final role = (user.role).trim().toLowerCase();
    if (role != 'familiar' && role != 'padre' && role != 'acudiente') return;
    final ids = user.studentIds ?? [];
    if (ids.isEmpty) return;

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('obtenerHijosVinculados')
          .call();
      if (_disposed) return;
      final raw = Map<String, dynamic>.from(result.data as Map);
      final children = (raw['children'] as List? ?? const []);
      final options = children.map((item) {
        final d = Map<String, dynamic>.from(item as Map);
        return ChildOption(
          id: (d['id'] ?? '').toString(),
          nombre: '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim(),
          document: d['document']?.toString(),
          data: d,
        );
      }).toList();
      childOptions = options;
      if (options.isNotEmpty) {
        final activeId = (user.activeStudentId ?? '').trim();
        final selected = options.firstWhere(
          (child) => child.id == activeId,
          orElse: () => options.first,
        );
        await ActiveStudentService().select(
          userProvider: userProvider,
          studentId: selected.id,
        );
        if (_disposed) return;
        await onChildSelected(selected, userProvider: userProvider);
      }
      notifyListeners();
    } catch (_) {}
  }

  List<String> optionsFor(EnrollmentField field) {
    if (field.options != null) {
      var opts = field.options!;
      // For facturaElectronica, hide 'acudiente' option if tieneAcudienteDiferente is not enabled
      if (field.name == 'facturaElectronica') {
        final tieneAcudiente =
            (controllers['tieneAcudienteDiferente']?.text ?? '')
                .toLowerCase() ==
            'true';
        if (!tieneAcudiente) {
          opts = opts.where((o) => o != 'acudiente').toList();
        }
      }
      return opts;
    }
    switch (field.optionsSource) {
      case 'tiposDocumento':
        return tiposDocumento;
      case 'tiposSangre':
        return tiposSangre;
      case 'academicGroups':
        final campus =
            selectedCampusId ??
            (controllers['sedeAspirada']?.text.trim() ?? '');
        final institution = selectedInstitutionId ?? '';
        return academicGroups
            .where(
              (group) =>
                  (campus.isEmpty || group.campusId == campus) &&
                  (institution.isEmpty || group.institutionId == institution),
            )
            .map((group) => group.id)
            .toList();
      case 'sedes':
        return sedes;
      case 'eps':
        return eps;
      default:
        return const [];
    }
  }

  String labelForValue(EnrollmentField field, String value) {
    if (field.name == 'groupId') {
      for (final group in academicGroups) {
        if (group.id == value) return group.name;
      }
    }
    if (field.name == 'epsEstudiante' && epsLabels.isNotEmpty) {
      return epsLabels[value] ?? value;
    }
    if (field.name == 'servicioTransporteTipo') {
      switch (value) {
        case 'medio_tiempo':
          return 'Medio tiempo';
        case 'tiempo_completo':
          return 'Tiempo completo';
        default:
          return value;
      }
    }
    if (field.name == 'acudientePrincipal') {
      switch (value) {
        case 'padre':
          return 'Padre';
        case 'madre':
          return 'Madre';
        default:
          return value;
      }
    }
    if (field.name == 'facturaElectronica') {
      switch (value) {
        case 'padre':
          return 'Padre';
        case 'madre':
          return 'Madre';
        case 'acudiente':
          return 'Acudiente';
        case 'ninguno':
          return 'Ninguno';
        default:
          return value;
      }
    }
    return value;
  }

  void setValue(String field, String? value) {
    if (_disposed || !controllers.containsKey(field) || value == null) return;
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

    final nombres = (data['firstName'] ?? data['nombresAlumno'] ?? '')
        .toString()
        .trim();
    final apellidos = (data['lastName'] ?? data['apellidosAlumno'] ?? '')
        .toString()
        .trim();
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
    setValue('groupId', data['groupId']?.toString());
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
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
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
        (data['birthDate'] as Timestamp)
            .toDate()
            .toIso8601String()
            .split('T')
            .first,
      );
    } else if (data['fechaNacimiento'] != null) {
      setValue('fechaNacimiento', data['fechaNacimiento'].toString());
    }
  }

  List<Map<String, dynamic>> get gradeHistory {
    final combined = [...internalGradeHistory, ...externalGradeHistory];
    combined.sort(
      (a, b) => (a['anio'] as int? ?? 0).compareTo(b['anio'] as int? ?? 0),
    );
    return combined;
  }

  void recomputeAge() {
    if (_disposed) return;
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

  Future<void> loadSecureEnrollmentContext({
    required UserProviderV2 userProvider,
    String? document,
  }) async {
    if (_disposed) return;
    final user = userProvider.user;
    if (user == null) return;
    final role = user.role.trim().toLowerCase();
    if (role != 'familiar' && role != 'administrador') return;
    final year = anioMatricula;
    if (year == null) {
      throw StateError('Selecciona una sede con año lectivo vigente.');
    }
    final input = <String, dynamic>{'anioMatricula': year};
    if (role == 'familiar') {
      if ((selectedChildId ?? '').isEmpty) return;
      input['studentId'] = selectedChildId;
    } else {
      final cleanDocument = (document ?? documentoSeleccionado ?? '').trim();
      if (cleanDocument.isEmpty) return;
      input.addAll({
        'document': cleanDocument,
        'institution': user.isSuperadmin
            ? selectedInstitutionId
            : user.institution,
        'campus': user.isSuperadmin ? selectedCampusId : user.campus,
      });
    }
    final result = await FirebaseFunctions.instance
        .httpsCallable('consultarMatriculaEstudiante')
        .call(input);
    if (_disposed) return;
    final response = Map<String, dynamic>.from(result.data as Map);
    final rawStudent = response['student'];
    if (rawStudent is Map) {
      final student = Map<String, dynamic>.from(rawStudent);
      applyPrefill(student);
      final id = student['id']?.toString();
      if (id != null && id.isNotEmpty) selectedChildId = id;
      recomputeAge();
    }
    final previous = (response['previous'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['anioMatricula'] is int)
        .map(
          (item) => <String, dynamic>{
            'anio': item['anioMatricula'],
            'institucion': item['institution']?.toString() ?? '',
            'groupName': item['groupName']?.toString() ?? '',
            'interno': true,
          },
        )
        .toList();
    internalGradeHistory = previous;
    final rawEnrollment = response['enrollment'];
    if (response['exists'] == true && rawEnrollment is Map) {
      final enrollment = Map<String, dynamic>.from(rawEnrollment);
      activeEnrollmentId = enrollment['id']?.toString();
      activeEnrollmentStatus = enrollment['estado']?.toString();
      activeEnrollmentRevision = (enrollment['revision'] as num?)?.toInt() ?? 1;
      currentEstado = activeEnrollmentStatus;
      final storedData = enrollment['data'];
      if (storedData is Map) {
        applyPrefill(Map<String, dynamic>.from(storedData));
      }
      blockedByExistingEnrollment =
          activeEnrollmentStatus != 'correccion_solicitada';
    } else {
      activeEnrollmentId = null;
      activeEnrollmentStatus = null;
      activeEnrollmentRevision = null;
      currentEstado = null;
      blockedByExistingEnrollment = false;
    }
    _updateGradeHistoryValue();
    notifyListeners();
  }

  Future<void> prefillByDocument({
    bool readOnly = false,
    UserProviderV2? userProvider,
  }) async {
    if (_disposed) return;
    final doc = documentLookupController.text.trim();
    if (doc.isEmpty || readOnly) return;

    loadingPrefill = true;
    notifyListeners();
    Map<String, dynamic>? found;
    try {
      final linked = childOptions.where((child) => child.document == doc);
      if (linked.isNotEmpty) {
        found = linked.first.data;
        documentoSeleccionado = doc;
      } else {
        documentoSeleccionado = doc;
      }

      if (found != null) {
        applyPrefill(found);
        recomputeAge();
        documentoSeleccionado = doc;
      } else {
        documentoSeleccionado = doc;
      }
      final caller = userProvider?.user;
      if (caller != null &&
          [
            'familiar',
            'administrador',
          ].contains(caller.role.trim().toLowerCase())) {
        await loadSecureEnrollmentContext(
          userProvider: userProvider!,
          document: doc,
        );
      }
    } catch (_) {
      // ignore errors
    } finally {
      loadingPrefill = false;
      notifyListeners();
    }
  }

  Future<void> onChildSelected(
    ChildOption? selected, {
    UserProviderV2? userProvider,
  }) async {
    if (_disposed) return;
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
      if (userProvider != null) {
        await loadSecureEnrollmentContext(userProvider: userProvider);
      }
    }
    notifyListeners();
  }

  void _updateGradeHistoryValue() {
    values['nivelesCursadosInstitucion'] = gradeHistory;
  }

  void addExternalGradeHistory(Map<String, dynamic> entry) {
    externalGradeHistory = [...externalGradeHistory, entry]
      ..sort(
        (a, b) => (a['anio'] as int? ?? 0).compareTo((b['anio'] as int? ?? 0)),
      );
    _updateGradeHistoryValue();
    notifyListeners();
  }

  void removeExternalGradeHistory(Map<String, dynamic> entry) {
    externalGradeHistory = externalGradeHistory
        .where(
          (e) =>
              !(e['anio'] == entry['anio'] &&
                  e['institucion'] == entry['institucion'] &&
                  e['groupName'] == entry['groupName'] &&
                  e['interno'] == entry['interno']),
        )
        .toList();
    _updateGradeHistoryValue();
    notifyListeners();
  }

  void updateExternalGradeHistory(
    Map<String, dynamic> oldEntry,
    Map<String, dynamic> newEntry,
  ) {
    // Remove the old matching entry and add the new one
    externalGradeHistory = externalGradeHistory
        .where(
          (e) =>
              !(e['anio'] == oldEntry['anio'] &&
                  e['institucion'] == oldEntry['institucion'] &&
                  e['groupName'] == oldEntry['groupName'] &&
                  e['interno'] == oldEntry['interno']),
        )
        .toList();
    externalGradeHistory = [...externalGradeHistory, newEntry]
      ..sort(
        (a, b) => (a['anio'] as int? ?? 0).compareTo((b['anio'] as int? ?? 0)),
      );
    _updateGradeHistoryValue();
    notifyListeners();
  }

  List<String> availableExternalGrades(String? currentGroupId) {
    if (currentGroupId == null || currentGroupId.isEmpty) return [];
    AcademicGroup? group;
    for (final item in academicGroups) {
      if (item.id == currentGroupId) {
        group = item;
        break;
      }
    }
    final aspiradoOrder = group?.order;
    if (aspiradoOrder == null) return [];
    final internos = internalGradeHistory
        .map((e) => e['groupName']?.toString())
        .whereType<String>()
        .toSet();
    return grados
        .where((g) => (gradeOrderByValue[g] ?? 9999) < aspiradoOrder)
        .where((g) => !internos.contains(g))
        .toList();
  }

  void disposeControllers() {
    if (_disposed) return;
    _disposed = true;
    for (final c in controllers.values) {
      c.dispose();
    }
    documentLookupController.dispose();
  }

  bool validateForm() {
    lastValidationError = null;
    if (!(formKey.currentState?.validate() ?? false)) return false;

    // Validar que si tieneAcudienteDiferente está marcado,
    // el documento del acudiente sea diferente al de los padres
    final tieneAcudiente =
        (controllers['tieneAcudienteDiferente']?.text ?? '').toLowerCase() ==
        'true';
    if (tieneAcudiente) {
      final cedulaAcudiente = (controllers['cedulaAcudiente']?.text ?? '')
          .trim();
      final cedulaPadre = (controllers['cedulaPadre']?.text ?? '').trim();
      final cedulaMadre = (controllers['cedulaMadre']?.text ?? '').trim();

      if (cedulaAcudiente.isNotEmpty &&
          (cedulaAcudiente == cedulaPadre || cedulaAcudiente == cedulaMadre)) {
        lastValidationError =
            'El número de documento del acudiente tiene que ser distinto al del padre o madre ';
        return false;
      }
      for (final field in const [
        'nombreAcudiente',
        'cedulaAcudiente',
        'emailAcudiente',
        'celularAcudiente',
      ]) {
        if ((controllers[field]?.text.trim() ?? '').isEmpty) {
          lastValidationError =
              'Completa los datos obligatorios del acudiente diferente.';
          return false;
        }
      }
    } else if (!const [
      'padre',
      'madre',
    ].contains(controllers['acudientePrincipal']?.text.trim())) {
      lastValidationError = 'Selecciona quién es el acudiente principal.';
      return false;
    }

    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    final emailFields = [
      'emailPadre',
      'emailMadre',
      if (tieneAcudiente) 'emailAcudiente',
    ];
    if (emailFields.any(
      (field) => !emailPattern.hasMatch(controllers[field]?.text.trim() ?? ''),
    )) {
      lastValidationError = 'Revisa los correos del formulario.';
      return false;
    }

    final transporte =
        (controllers['servicioTransporte']?.text ?? '').toLowerCase() == 'true';
    if (transporte &&
        (controllers['servicioTransporteTipo']?.text.trim() ?? '').isEmpty) {
      lastValidationError = 'Selecciona el tipo de transporte.';
      return false;
    }
    if ((selectedInstitutionId ?? '').isEmpty ||
        (selectedCampusId ?? '').isEmpty) {
      lastValidationError = 'Selecciona la institución y la sede.';
      return false;
    }

    return true;
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
      estado = isEditing
          ? (currentEstadoExt ?? 'prematriculado')
          : 'prematriculado';
    }
    final anio = anioMatricula;
    if (optionsError != null || anio == null) {
      return SubmitResult(
        success: false,
        payload: payload,
        error: optionsError ?? 'Selecciona una sede con año lectivo vigente.',
      );
    }
    anioMatricula = anio;
    if ((payload['institucion'] == null ||
            payload['institucion'].toString().isEmpty) &&
        (user?.institution ?? '').isNotEmpty) {
      payload['institucion'] = user?.institution;
    }
    final useCallerScope = user != null && !user.isSuperadmin;
    final institution = useCallerScope
        ? user.institution.trim()
        : (selectedInstitutionId ?? '').trim();
    final campus = useCallerScope
        ? user.campus.trim()
        : (selectedCampusId ?? payload['sedeAspirada'] ?? '').toString().trim();

    try {
      if (isEditing) {
        if (isAdmin) {
          if (currentEstadoExt == 'matriculado' && !matricularAhora) {
            await _enrollmentService.transitionEnrollment(
              id: enrollmentId,
              action: 'update_enrolled',
              data: payload,
              linkedStudentId: selectedChildId,
              expectedRevision: activeEnrollmentRevision,
            );
          } else {
            await _enrollmentService.updateEnrollment(
              id: enrollmentId,
              data: payload,
              estado: estado,
              revisadoPor: user?.id,
              anioMatricula: anio,
              vinculaUsuarioId: selectedChildId,
              institution: institution,
              campus: campus,
              expectedRevision: activeEnrollmentRevision,
            );
          }
        } else {
          await _enrollmentService.transitionEnrollment(
            id: enrollmentId,
            action: 'resubmit',
            data: payload,
            expectedRevision: activeEnrollmentRevision,
          );
          estado = 'pendiente_revision';
        }
      } else {
        activeEnrollmentId = await _enrollmentService.createEnrollment(
          data: payload,
          estado: estado,
          institution: institution,
          campus: campus,
          token: token,
          vinculaUsuarioId: selectedChildId,
          anioMatricula: anio,
        );
      }

      currentEstado = estado;
      if (isEditing) {
        activeEnrollmentRevision = (activeEnrollmentRevision ?? 1) + 1;
      }
      activeEnrollmentStatus = estado;
      if (!isAdmin) {
        blockedByExistingEnrollment = estado != 'correccion_solicitada';
      }
      notifyListeners();
      return SubmitResult(success: true, estado: estado, payload: payload);
    } catch (e) {
      return SubmitResult(
        success: false,
        estado: null,
        payload: payload,
        error: userFacingError(
          e,
          fallback: 'No fue posible guardar la matrícula. Intenta nuevamente.',
        ),
      );
    }
  }

  void setCurrentStep(int step) {
    currentStep = step;
    isStepCollapsed = false;
    notifyListeners();
  }

  void toggleStepCollapse() {
    isStepCollapsed = !isStepCollapsed;
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
