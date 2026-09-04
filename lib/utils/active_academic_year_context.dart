import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveAcademicYearContext {
  final String id;
  final int year;

  const ActiveAcademicYearContext({required this.id, required this.year});
}

Future<ActiveAcademicYearContext> loadActiveAcademicYear({
  required FirebaseFirestore firestore,
  required String institutionId,
  required String campusId,
}) async {
  final settings = await firestore
      .collection('academic_year_settings')
      .where('institutionId', isEqualTo: institutionId)
      .where('campusId', isEqualTo: campusId)
      .limit(1)
      .get();
  if (settings.docs.isEmpty) {
    throw StateError('La sede no tiene un año lectivo vigente.');
  }
  final data = settings.docs.first.data();
  final id = (data['activeYearId'] ?? '').toString();
  final year = (data['activeYear'] as num?)?.toInt();
  if (id.isEmpty || year == null) {
    throw StateError('La configuración del año lectivo es inválida.');
  }
  return ActiveAcademicYearContext(id: id, year: year);
}

Future<List<String>> loadAllActiveAcademicYearIds({
  required FirebaseFirestore firestore,
}) async {
  final snapshot = await firestore.collection('academic_year_settings').get();
  return snapshot.docs
      .map((item) => (item.data()['activeYearId'] ?? '').toString())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}
