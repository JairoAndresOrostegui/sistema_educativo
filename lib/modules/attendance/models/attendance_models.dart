enum AttendanceState { present, absent, late, excused }

extension AttendanceStateLabel on AttendanceState {
  String get wire => name;

  String get label => switch (this) {
    AttendanceState.present => 'Presente',
    AttendanceState.absent => 'Ausente',
    AttendanceState.late => 'Tarde',
    AttendanceState.excused => 'Excusado',
  };

  static AttendanceState? fromWire(Object? value) {
    for (final state in AttendanceState.values) {
      if (state.wire == value) return state;
    }
    return null;
  }
}

class AttendanceContext {
  const AttendanceContext({
    required this.groups,
    required this.subjects,
    required this.academicYearId,
    required this.academicYear,
  });

  final List<AttendanceGroup> groups;
  final List<AttendanceSubject> subjects;
  final String academicYearId;
  final int academicYear;

  factory AttendanceContext.fromMap(Map<String, dynamic> map) {
    return AttendanceContext(
      groups: ((map['groups'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => AttendanceGroup.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      subjects: ((map['subjects'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AttendanceSubject.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      academicYearId: (map['academicYearId'] ?? '').toString(),
      academicYear: (map['academicYear'] as num?)?.toInt() ?? 0,
    );
  }
}

class AttendanceGroup {
  const AttendanceGroup({required this.id, required this.name});
  final String id;
  final String name;

  factory AttendanceGroup.fromMap(Map<String, dynamic> map) => AttendanceGroup(
    id: (map['id'] ?? '').toString(),
    name: (map['name'] ?? 'Grupo').toString(),
  );
}

class AttendanceSubject {
  const AttendanceSubject({
    required this.id,
    required this.name,
    required this.groupId,
  });
  final String id;
  final String name;
  final String groupId;

  factory AttendanceSubject.fromMap(Map<String, dynamic> map) =>
      AttendanceSubject(
        id: (map['id'] ?? '').toString(),
        name: (map['name'] ?? 'Asignatura').toString(),
        groupId: (map['groupId'] ?? '').toString(),
      );
}

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.groupName,
    required this.date,
    required this.status,
    required this.revision,
    required this.studentCount,
    required this.markedCount,
    required this.responsibleTeacherName,
    this.subjectName,
  });

  final String id;
  final String groupName;
  final String date;
  final String status;
  final int revision;
  final int studentCount;
  final int markedCount;
  final String responsibleTeacherName;
  final String? subjectName;

  bool get isOpen => status == 'open';

  factory AttendanceSession.fromMap(Map<String, dynamic> map) =>
      AttendanceSession(
        id: (map['id'] ?? '').toString(),
        groupName: (map['groupName'] ?? 'Grupo').toString(),
        date: (map['date'] ?? '').toString(),
        status: (map['status'] ?? '').toString(),
        revision: (map['revision'] as num?)?.toInt() ?? 1,
        studentCount: (map['studentCount'] as num?)?.toInt() ?? 0,
        markedCount: (map['markedCount'] as num?)?.toInt() ?? 0,
        responsibleTeacherName: (map['responsibleTeacherName'] ?? '')
            .toString(),
        subjectName: map['subjectName']?.toString(),
      );
}

class AttendanceEntry {
  const AttendanceEntry({
    required this.studentId,
    required this.studentName,
    this.state,
    this.observation = '',
  });

  final String studentId;
  final String studentName;
  final AttendanceState? state;
  final String observation;

  AttendanceEntry copyWith({AttendanceState? state, String? observation}) =>
      AttendanceEntry(
        studentId: studentId,
        studentName: studentName,
        state: state ?? this.state,
        observation: observation ?? this.observation,
      );

  factory AttendanceEntry.fromMap(Map<String, dynamic> map) => AttendanceEntry(
    studentId: (map['id'] ?? map['studentId'] ?? '').toString(),
    studentName: (map['name'] ?? map['studentName'] ?? 'Estudiante').toString(),
    state: AttendanceStateLabel.fromWire(map['state']),
    observation: (map['observation'] ?? '').toString(),
  );
}

class AttendanceOwnRecord {
  const AttendanceOwnRecord({
    required this.date,
    required this.groupName,
    required this.state,
    required this.observation,
  });
  final String date;
  final String groupName;
  final AttendanceState state;
  final String observation;

  factory AttendanceOwnRecord.fromMap(Map<String, dynamic> map) =>
      AttendanceOwnRecord(
        date: (map['date'] ?? '').toString(),
        groupName: (map['groupName'] ?? 'Grupo').toString(),
        state:
            AttendanceStateLabel.fromWire(map['state']) ??
            AttendanceState.present,
        observation: (map['observation'] ?? '').toString(),
      );
}

class AttendanceReport {
  const AttendanceReport({
    required this.dateFrom,
    required this.dateTo,
    required this.sessionCount,
    required this.rows,
    required this.summary,
  });

  final String dateFrom;
  final String dateTo;
  final int sessionCount;
  final List<AttendanceReportRow> rows;
  final Map<AttendanceState, int> summary;

  factory AttendanceReport.fromMap(Map<String, dynamic> map) {
    final rawSummary = map['summary'] is Map
        ? Map<String, dynamic>.from(map['summary'] as Map)
        : <String, dynamic>{};
    return AttendanceReport(
      dateFrom: (map['dateFrom'] ?? '').toString(),
      dateTo: (map['dateTo'] ?? '').toString(),
      sessionCount: (map['sessionCount'] as num?)?.toInt() ?? 0,
      rows: ((map['rows'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AttendanceReportRow.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
      summary: {
        for (final state in AttendanceState.values)
          state: (rawSummary[state.wire] as num?)?.toInt() ?? 0,
      },
    );
  }
}

class AttendanceReportRow {
  const AttendanceReportRow({
    required this.date,
    required this.groupName,
    required this.subjectName,
    required this.studentName,
    required this.state,
    required this.observation,
    required this.responsibleTeacherName,
  });

  final String date;
  final String groupName;
  final String subjectName;
  final String studentName;
  final AttendanceState state;
  final String observation;
  final String responsibleTeacherName;

  factory AttendanceReportRow.fromMap(
    Map<String, dynamic> map,
  ) => AttendanceReportRow(
    date: (map['date'] ?? '').toString(),
    groupName: (map['groupName'] ?? '').toString(),
    subjectName: (map['subjectName'] ?? '').toString(),
    studentName: (map['studentName'] ?? '').toString(),
    state:
        AttendanceStateLabel.fromWire(map['state']) ?? AttendanceState.present,
    observation: (map['observation'] ?? '').toString(),
    responsibleTeacherName: (map['responsibleTeacherName'] ?? '').toString(),
  );
}
