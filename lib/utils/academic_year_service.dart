import 'package:cloud_functions/cloud_functions.dart';

import '../models/academic/academic_year.dart';

class AcademicYearService {
  final FirebaseFunctions _functions;

  AcademicYearService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  Future<List<AcademicYear>> list({
    required String institutionId,
    required String campusId,
  }) async {
    final result = await _functions.httpsCallable('listarAniosLectivos').call({
      'institutionId': institutionId,
      'campusId': campusId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['years'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => AcademicYear.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> prepare({
    required String institutionId,
    required String campusId,
    required int year,
    required bool cloneGroups,
    required bool cloneSchedules,
  }) async {
    final result = await _functions.httpsCallable('prepararAnioLectivo').call({
      'institutionId': institutionId,
      'campusId': campusId,
      'year': year,
      'cloneGroups': cloneGroups,
      'cloneSchedules': cloneSchedules,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> activate(AcademicYear year) async {
    await _functions.httpsCallable('activarAnioLectivo').call({
      'academicYearId': year.id,
      'confirmation': 'ACTIVAR ${year.year}',
    });
  }
}
