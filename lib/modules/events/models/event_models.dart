enum SchoolEventStatus { draft, published, closed, cancelled, archived }

extension SchoolEventStatusLabel on SchoolEventStatus {
  String get wire => name;
  String get label => switch (this) {
    SchoolEventStatus.draft => 'Borrador',
    SchoolEventStatus.published => 'Publicado',
    SchoolEventStatus.closed => 'Finalizado',
    SchoolEventStatus.cancelled => 'Cancelado',
    SchoolEventStatus.archived => 'Archivado',
  };

  static SchoolEventStatus fromWire(Object? value) =>
      SchoolEventStatus.values.firstWhere(
        (item) => item.wire == value,
        orElse: () => SchoolEventStatus.draft,
      );
}

class EventGroup {
  const EventGroup({required this.id, required this.name});
  final String id;
  final String name;
}

class EventResponsible {
  const EventResponsible({
    required this.id,
    required this.name,
    required this.role,
  });
  final String id;
  final String name;
  final String role;
}

class EventStudent {
  const EventStudent({
    required this.id,
    required this.name,
    required this.groupId,
    required this.groupName,
  });
  final String id;
  final String name;
  final String groupId;
  final String groupName;
}

class EventContext {
  const EventContext({
    required this.academicYear,
    required this.groups,
    required this.responsibleUsers,
    this.students = const [],
  });
  final int academicYear;
  final List<EventGroup> groups;
  final List<EventResponsible> responsibleUsers;
  final List<EventStudent> students;

  factory EventContext.fromMap(Map<String, dynamic> map) => EventContext(
    academicYear: (map['academicYear'] as num?)?.toInt() ?? 0,
    groups: ((map['groups'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => EventGroup(
            id: (item['id'] ?? '').toString(),
            name: (item['name'] ?? 'Grupo').toString(),
          ),
        )
        .toList(),
    responsibleUsers: ((map['responsibleUsers'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => EventResponsible(
            id: (item['id'] ?? '').toString(),
            name: (item['name'] ?? '').toString(),
            role: (item['role'] ?? '').toString(),
          ),
        )
        .toList(),
    students: ((map['students'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => EventStudent(
            id: (item['id'] ?? '').toString(),
            name: (item['name'] ?? '').toString(),
            groupId: (item['groupId'] ?? '').toString(),
            groupName: (item['groupName'] ?? 'Grupo').toString(),
          ),
        )
        .toList(),
  );
}

class SchoolEvent {
  const SchoolEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.audienceType,
    required this.targetGroupIds,
    this.targetStudentIds = const [],
    required this.responsibleNames,
    required this.registrationRequired,
    required this.requiresFamilyAuthorization,
    required this.confirmedCount,
    required this.revision,
    required this.attendanceRevision,
    required this.links,
    this.capacity,
    this.myResponse,
    this.myAttendance,
  });

  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final SchoolEventStatus status;
  final String audienceType;
  final List<String> targetGroupIds;
  final List<String> targetStudentIds;
  final Map<String, String> responsibleNames;
  final bool registrationRequired;
  final bool requiresFamilyAuthorization;
  final int? capacity;
  final int confirmedCount;
  final int revision;
  final int attendanceRevision;
  final List<EventLink> links;
  final String? myResponse;
  final String? myAttendance;

  factory SchoolEvent.fromMap(Map<String, dynamic> map) => SchoolEvent(
    id: (map['id'] ?? '').toString(),
    title: (map['title'] ?? '').toString(),
    description: (map['description'] ?? '').toString(),
    location: (map['location'] ?? '').toString(),
    startAt: DateTime.fromMillisecondsSinceEpoch(
      (map['startAtMillis'] as num?)?.toInt() ?? 0,
    ),
    endAt: DateTime.fromMillisecondsSinceEpoch(
      (map['endAtMillis'] as num?)?.toInt() ?? 0,
    ),
    status: SchoolEventStatusLabel.fromWire(map['status']),
    audienceType: (map['audienceType'] ?? 'groups').toString(),
    targetGroupIds: List<String>.from(map['targetGroupIds'] ?? const []),
    targetStudentIds: List<String>.from(map['targetStudentIds'] ?? const []),
    responsibleNames: Map<String, String>.from(
      (map['responsibleNames'] as Map?) ?? const {},
    ),
    registrationRequired: map['registrationRequired'] == true,
    requiresFamilyAuthorization: map['requiresFamilyAuthorization'] == true,
    capacity: (map['capacity'] as num?)?.toInt(),
    confirmedCount: (map['confirmedCount'] as num?)?.toInt() ?? 0,
    revision: (map['revision'] as num?)?.toInt() ?? 1,
    attendanceRevision: (map['attendanceRevision'] as num?)?.toInt() ?? 1,
    links: ((map['links'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => EventLink(
            label: (item['label'] ?? '').toString(),
            url: (item['url'] ?? '').toString(),
          ),
        )
        .toList(),
    myResponse: map['myResponse']?.toString(),
    myAttendance: map['myAttendance']?.toString(),
  );
}

class EventLink {
  const EventLink({required this.label, required this.url});
  final String label;
  final String url;
}

class EventAttendanceEntry {
  const EventAttendanceEntry({
    required this.studentId,
    required this.studentName,
    this.response,
    this.state,
  });
  final String studentId;
  final String studentName;
  final String? response;
  final String? state;

  EventAttendanceEntry copyWith({String? state}) => EventAttendanceEntry(
    studentId: studentId,
    studentName: studentName,
    response: response,
    state: state ?? this.state,
  );

  factory EventAttendanceEntry.fromMap(Map<String, dynamic> map) =>
      EventAttendanceEntry(
        studentId: (map['studentId'] ?? '').toString(),
        studentName: (map['studentName'] ?? '').toString(),
        response: map['response']?.toString(),
        state: map['state']?.toString(),
      );
}

class EventReportRow {
  const EventReportRow({
    required this.id,
    required this.title,
    required this.location,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.targetCount,
    required this.confirmedCount,
  });

  final String id;
  final String title;
  final String location;
  final SchoolEventStatus status;
  final DateTime startAt;
  final DateTime endAt;
  final int targetCount;
  final int confirmedCount;

  factory EventReportRow.fromMap(Map<String, dynamic> map) => EventReportRow(
    id: (map['id'] ?? '').toString(),
    title: (map['title'] ?? '').toString(),
    location: (map['location'] ?? '').toString(),
    status: SchoolEventStatusLabel.fromWire(map['status']),
    startAt: DateTime.fromMillisecondsSinceEpoch(
      (map['startAtMillis'] as num?)?.toInt() ?? 0,
    ),
    endAt: DateTime.fromMillisecondsSinceEpoch(
      (map['endAtMillis'] as num?)?.toInt() ?? 0,
    ),
    targetCount: (map['targetCount'] as num?)?.toInt() ?? 0,
    confirmedCount: (map['confirmedCount'] as num?)?.toInt() ?? 0,
  );
}
