import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicGroup {
  final String id;
  final String institutionId;
  final String campusId;
  final String name;
  final String level;
  final String section;
  final int order;
  final bool active;

  const AcademicGroup({
    required this.id,
    required this.institutionId,
    required this.campusId,
    required this.name,
    required this.level,
    required this.section,
    required this.order,
    required this.active,
  });

  factory AcademicGroup.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return AcademicGroup(
      id: document.id,
      institutionId: (data['institutionId'] ?? '').toString(),
      campusId: (data['campusId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      level: (data['level'] ?? '').toString(),
      section: (data['section'] ?? '').toString(),
      order: (data['order'] as num?)?.toInt() ?? 0,
      active: data['active'] == true,
    );
  }
}
