import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/user/controllers/admin_user_form_controller.dart';
import 'package:sistema_educativo/utils/parameters_service.dart';
import 'package:sistema_educativo/utils/validators.dart';
import 'package:sistema_educativo/utils/academic_group_service.dart';

typedef TeacherDocumentTypeLoader = Future<Map<String, String>> Function();
typedef TeacherUniquenessCheck =
    Future<String?> Function({
      required String personalEmail,
      required String institutionalEmail,
      required String document,
    });
typedef TeacherCreateCallback = Future<void> Function(userModelv2 user);

class TeacherBulkImportFailure {
  final int rowNumber;
  final String displayName;
  final String reason;

  const TeacherBulkImportFailure({
    required this.rowNumber,
    required this.displayName,
    required this.reason,
  });
}

class TeacherBulkImportResult {
  final int totalRows;
  final int createdCount;
  final List<TeacherBulkImportFailure> failures;

  const TeacherBulkImportResult({
    required this.totalRows,
    required this.createdCount,
    required this.failures,
  });

  int get failedCount => failures.length;
}

class TeacherBulkImportService {
  factory TeacherBulkImportService({
    AdminUserFormController? formController,
    TeacherDocumentTypeLoader? documentTypeLoader,
    TeacherUniquenessCheck? uniquenessCheck,
    TeacherCreateCallback? createTeacher,
  }) => TeacherBulkImportService._(
    formController,
    documentTypeLoader,
    uniquenessCheck,
    createTeacher,
  );

  TeacherBulkImportService._(
    this._formController,
    this._documentTypeLoader,
    this._uniquenessCheck,
    this._createTeacher,
  );

  AdminUserFormController? _formController;
  final TeacherDocumentTypeLoader? _documentTypeLoader;
  final TeacherUniquenessCheck? _uniquenessCheck;
  final TeacherCreateCallback? _createTeacher;

  AdminUserFormController get _controller =>
      _formController ??= AdminUserFormController();

  static const List<String> requiredColumns = <String>[
    'nombres',
    'apellidos',
    'documento',
    'correo',
    'grupo',
  ];

  static const List<String> optionalColumns = <String>[
    'tipo_documento',
    'correo_institucional',
    'estado',
  ];

  static const Map<String, List<String>> _headerAliases =
      <String, List<String>>{
        'firstName': <String>['nombres', 'nombre', 'first_name', 'firstname'],
        'lastName': <String>['apellidos', 'apellido', 'last_name', 'lastname'],
        'fullName': <String>[
          'nombrecompleto',
          'nombre_completo',
          'fullname',
          'full_name',
          'docente',
        ],
        'document': <String>[
          'documento',
          'numerodedocumento',
          'numero_documento',
          'nrodocumento',
          'cedula',
          'identificacion',
        ],
        'documentType': <String>[
          'tipodedocumento',
          'tipo_documento',
          'documenttype',
          'document_type',
        ],
        'personalEmail': <String>[
          'correo',
          'correopersonal',
          'correo_personal',
          'email',
          'personalemail',
          'correoelectronico',
        ],
        'institutionalEmail': <String>[
          'correoinstitucional',
          'correo_institucional',
          'institutionalemail',
          'institutional_email',
          'emailinstitucional',
        ],
        'group': <String>['grupo', 'curso'],
        'status': <String>['estado', 'status'],
        'role': <String>['rol', 'role'],
      };

  Future<TeacherBulkImportResult> importTeachersFromBytes({
    required Uint8List bytes,
    required userModelv2 usuarioLogueado,
  }) async {
    final groups = _createTeacher == null
        ? await AcademicGroupService().list(
            institutionId: usuarioLogueado.institution,
            campusId: usuarioLogueado.campus,
          )
        : const [];
    final documentTypes =
        await (_documentTypeLoader?.call() ?? _loadDocumentTypeMap());
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('El archivo no contiene hojas para importar.');
    }

    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw Exception('El archivo no contiene filas para importar.');
    }

    final rows = sheet.rows;
    final headerRow = rows.first;
    final headerMap = _buildHeaderMap(headerRow);

    final hasSplitName =
        headerMap.containsKey('firstName') && headerMap.containsKey('lastName');
    final hasFullName = headerMap.containsKey('fullName');
    if (!hasSplitName && !hasFullName) {
      throw Exception(
        'Faltan columnas de nombre. Usa "nombres" y "apellidos", o "nombre_completo".',
      );
    }

    final missing = <String>[];
    for (final key in <String>['document', 'personalEmail', 'group']) {
      if (!headerMap.containsKey(key)) {
        missing.add(_requiredLabelForKey(key));
      }
    }
    if (missing.isNotEmpty) {
      throw Exception('Faltan columnas obligatorias: ${missing.join(', ')}.');
    }

    final failures = <TeacherBulkImportFailure>[];
    final seenDocuments = <String>{};
    final seenPersonalEmails = <String>{};
    final seenInstitutionalEmails = <String>{};
    var createdCount = 0;
    var totalRows = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isEmptyRow(row)) {
        continue;
      }

      totalRows++;
      final rowNumber = i + 1;

      try {
        final candidate = _buildCandidate(row, headerMap, documentTypes);

        final normalizedDocument = candidate.document.trim();
        final normalizedPersonalEmail = candidate.personalEmail
            .trim()
            .toLowerCase();
        final normalizedInstitutionalEmail = candidate.institutionalEmail
            .trim()
            .toLowerCase();

        if (candidate.firstName.isEmpty || candidate.lastName.isEmpty) {
          throw Exception('Debes indicar nombres y apellidos.');
        }
        if (normalizedDocument.length < 6) {
          throw Exception('El documento debe tener minimo 6 caracteres.');
        }
        if (!Validators.isValidEmail(normalizedPersonalEmail)) {
          throw Exception('El correo no es valido.');
        }
        if (!Validators.isValidEmail(normalizedInstitutionalEmail)) {
          throw Exception('El correo institucional no es valido.');
        }
        if (candidate.groupName.isEmpty) {
          throw Exception('El grupo es obligatorio.');
        }
        final matchingGroups = groups
            .where(
              (group) =>
                  group.name.trim().toLowerCase() ==
                  candidate.groupName.trim().toLowerCase(),
            )
            .toList();
        if (_createTeacher == null && matchingGroups.length != 1) {
          throw Exception('El grupo no existe en la sede seleccionada.');
        }
        final groupId = matchingGroups.isEmpty
            ? candidate.groupName
            : matchingGroups.single.id;
        final groupName = matchingGroups.isEmpty
            ? candidate.groupName
            : matchingGroups.single.name;
        if (candidate.role != 'Docente') {
          throw Exception(
            'Este importador solo crea usuarios con rol Docente.',
          );
        }

        if (!seenDocuments.add(normalizedDocument)) {
          throw Exception('Documento duplicado dentro del archivo.');
        }
        if (!seenPersonalEmails.add(normalizedPersonalEmail)) {
          throw Exception('Correo duplicado dentro del archivo.');
        }
        if (!seenInstitutionalEmails.add(normalizedInstitutionalEmail)) {
          throw Exception('Correo institucional duplicado dentro del archivo.');
        }

        final uniquenessCheck = _uniquenessCheck;
        if (uniquenessCheck != null) {
          final reason = await uniquenessCheck(
            personalEmail: normalizedPersonalEmail,
            institutionalEmail: normalizedInstitutionalEmail,
            document: normalizedDocument,
          );
          if (reason != null) throw Exception(reason);
        } else {
          final uniqueOk = await _controller.validarCamposUnicos(
            correoPersonal: normalizedPersonalEmail,
            correoInstitucional: normalizedInstitutionalEmail,
            documento: normalizedDocument,
            excluirId: null,
            onResetSaving: () {},
            onError: (title, message) async {
              throw Exception(message);
            },
          );
          if (!uniqueOk) {
            throw Exception('No fue posible validar la fila.');
          }
        }

        final usuario = userModelv2(
          id: '',
          firstName: candidate.firstName,
          lastName: candidate.lastName,
          document: normalizedDocument,
          documentType: candidate.documentType,
          personalEmail: normalizedPersonalEmail,
          institutionalEmail: normalizedInstitutionalEmail,
          role: 'Docente',
          groupId: groupId,
          groupName: groupName,
          institution: usuarioLogueado.institution,
          campus: usuarioLogueado.campus,
          isSuperadmin: false,
          status: candidate.status,
          phones: const <String>[],
          permissions: const <String>[],
          webPushToken: null,
          mobilePushToken: null,
          address: '',
          photoUrl: '',
          birthCountry: '',
          birthDepartment: '',
          birthCity: '',
          residenceCountry: '',
          residenceDepartment: '',
          residenceCity: '',
          familyRelation: '',
        );

        final createTeacher = _createTeacher;
        if (createTeacher != null) {
          await createTeacher(usuario);
        } else {
          await _controller.guardarNuevo(
            usuario: usuario,
            fotoBytes: null,
            fotoNombre: null,
            usuarioLogueado: usuarioLogueado,
          );
        }
        createdCount++;
      } catch (e) {
        failures.add(
          TeacherBulkImportFailure(
            rowNumber: rowNumber,
            displayName: _displayNameForFailure(row, headerMap),
            reason: _cleanError(e),
          ),
        );
      }
    }

    return TeacherBulkImportResult(
      totalRows: totalRows,
      createdCount: createdCount,
      failures: failures,
    );
  }

  Map<String, int> _buildHeaderMap(List<Data?> headerRow) {
    final map = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final raw = _cellToString(headerRow[i]);
      final normalized = _normalizeHeader(raw);
      if (normalized.isEmpty) {
        continue;
      }

      for (final entry in _headerAliases.entries) {
        if (entry.value.contains(normalized)) {
          map.putIfAbsent(entry.key, () => i);
        }
      }
    }
    return map;
  }

  _TeacherImportCandidate _buildCandidate(
    List<Data?> row,
    Map<String, int> headerMap,
    Map<String, String> documentTypes,
  ) {
    String firstName = _valueFromRow(row, headerMap, 'firstName');
    String lastName = _valueFromRow(row, headerMap, 'lastName');

    if ((firstName.isEmpty || lastName.isEmpty) &&
        headerMap.containsKey('fullName')) {
      final parsed = _splitFullName(_valueFromRow(row, headerMap, 'fullName'));
      firstName = firstName.isEmpty ? parsed.$1 : firstName;
      lastName = lastName.isEmpty ? parsed.$2 : lastName;
    }

    final personalEmail = _valueFromRow(row, headerMap, 'personalEmail');
    final institutionalEmail =
        _valueFromRow(row, headerMap, 'institutionalEmail').trim().isEmpty
        ? personalEmail
        : _valueFromRow(row, headerMap, 'institutionalEmail');
    final roleValue = _valueFromRow(row, headerMap, 'role');
    final statusValue = _valueFromRow(row, headerMap, 'status');

    return _TeacherImportCandidate(
      firstName: _capitalizeWords(firstName),
      lastName: _capitalizeWords(lastName),
      document: _valueFromRow(row, headerMap, 'document'),
      documentType: _normalizeDocumentType(
        _valueFromRow(row, headerMap, 'documentType'),
        documentTypes,
      ),
      personalEmail: personalEmail,
      institutionalEmail: institutionalEmail,
      groupName: _valueFromRow(row, headerMap, 'group').trim(),
      role: roleValue.trim().isEmpty ? 'Docente' : _capitalizeWords(roleValue),
      status: _normalizeStatus(statusValue),
    );
  }

  String _displayNameForFailure(List<Data?> row, Map<String, int> headerMap) {
    final firstName = _valueFromRow(row, headerMap, 'firstName');
    final lastName = _valueFromRow(row, headerMap, 'lastName');
    final fullName = _valueFromRow(row, headerMap, 'fullName');
    final candidate = '$firstName $lastName'.trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }
    if (fullName.isNotEmpty) {
      return fullName;
    }
    final document = _valueFromRow(row, headerMap, 'document');
    return document.isEmpty ? 'Sin identificar' : 'Documento $document';
  }

  String _valueFromRow(
    List<Data?> row,
    Map<String, int> headerMap,
    String key,
  ) {
    final index = headerMap[key];
    if (index == null || index >= row.length) {
      return '';
    }
    return _cellToString(row[index]).trim();
  }

  String _cellToString(Data? data) {
    final value = data?.value;
    return value?.toString().trim() ?? '';
  }

  bool _isEmptyRow(List<Data?> row) {
    for (final cell in row) {
      if (_cellToString(cell).isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  String _normalizeHeader(String value) {
    return _stripDiacritics(
      value,
    ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String _stripDiacritics(String value) {
    const replacements = <String, String>{
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'ñ': 'n',
      'Ñ': 'N',
    };

    var normalized = value;
    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });
    return normalized;
  }

  (String, String) _splitFullName(String fullName) {
    final tokens = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.length < 2) {
      return (fullName.trim(), '');
    }
    if (tokens.length >= 4) {
      return (
        tokens.sublist(0, tokens.length - 2).join(' '),
        tokens.sublist(tokens.length - 2).join(' '),
      );
    }
    return (tokens.sublist(0, tokens.length - 1).join(' '), tokens.last);
  }

  String _capitalizeWords(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return '';
    }
    return normalized
        .split(' ')
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  Future<Map<String, String>> _loadDocumentTypeMap() async {
    try {
      final params = await ParametersService().getDocumentTypes();
      final map = <String, String>{};
      for (final item in params) {
        final valor = item.valor.trim();
        if (valor.isEmpty) {
          continue;
        }
        map[_normalizeLookupKey(valor)] = valor;
        if (item.etiqueta.trim().isNotEmpty) {
          map[_normalizeLookupKey(item.etiqueta)] = valor;
        }
      }
      return map;
    } catch (_) {
      return <String, String>{};
    }
  }

  String _normalizeDocumentType(
    String value,
    Map<String, String> documentTypes,
  ) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return documentTypes[_normalizeLookupKey('CC')] ?? 'CC';
    }

    final normalizedKey = _normalizeLookupKey(trimmed);
    return documentTypes[normalizedKey] ?? trimmed;
  }

  String _normalizeLookupKey(String value) {
    return _stripDiacritics(
      value,
    ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String _normalizeStatus(String value) {
    final normalized = _stripDiacritics(value.trim()).toLowerCase();
    if (normalized == 'inactivo') {
      return 'inactivo';
    }
    return 'activo';
  }

  String _requiredLabelForKey(String key) {
    switch (key) {
      case 'document':
        return 'documento';
      case 'personalEmail':
        return 'correo';
      case 'group':
        return 'grupo';
      default:
        return key;
    }
  }

  String _cleanError(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length).trim();
    }
    return message;
  }
}

class _TeacherImportCandidate {
  final String firstName;
  final String lastName;
  final String document;
  final String documentType;
  final String personalEmail;
  final String institutionalEmail;
  final String groupName;
  final String role;
  final String status;

  const _TeacherImportCandidate({
    required this.firstName,
    required this.lastName,
    required this.document,
    required this.documentType,
    required this.personalEmail,
    required this.institutionalEmail,
    required this.groupName,
    required this.role,
    required this.status,
  });
}
