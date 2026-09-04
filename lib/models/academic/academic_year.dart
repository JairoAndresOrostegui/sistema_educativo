class AcademicYear {
  final String id;
  final String institutionId;
  final String campusId;
  final int year;
  final String status;
  final int copiedGroups;
  final int copiedSchedules;

  const AcademicYear({
    required this.id,
    required this.institutionId,
    required this.campusId,
    required this.year,
    required this.status,
    required this.copiedGroups,
    required this.copiedSchedules,
  });

  factory AcademicYear.fromMap(Map<String, dynamic> data) => AcademicYear(
    id: (data['id'] ?? '').toString(),
    institutionId: (data['institutionId'] ?? '').toString(),
    campusId: (data['campusId'] ?? '').toString(),
    year: (data['year'] as num?)?.toInt() ?? 0,
    status: (data['status'] ?? '').toString(),
    copiedGroups: (data['copiedGroups'] as num?)?.toInt() ?? 0,
    copiedSchedules: (data['copiedSchedules'] as num?)?.toInt() ?? 0,
  );

  String get statusLabel => switch (status) {
    'active' => 'Vigente',
    'draft' => 'En preparación',
    'closed' => 'Cerrado',
    _ => status,
  };
}
