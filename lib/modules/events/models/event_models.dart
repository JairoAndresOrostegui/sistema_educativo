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
    this.eventType = 'student_presentation',
    this.subtitle = '',
    this.foodEnabled = false,
    this.publicityText = '',
    this.publicityUrl = '',
    this.requirements = const [],
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
  final String eventType;
  final String subtitle;
  final bool foodEnabled;
  final String publicityText;
  final String publicityUrl;
  final List<EventRequirement> requirements;

  bool get isPresentation => eventType == 'student_presentation';
  String get typeLabel =>
      isPresentation ? 'Presentación estudiantil' : 'Reunión de padres';

  Map<String, dynamic> toDraftMap() => {
    'schemaVersion': 2,
    'eventType': eventType,
    'subtitle': subtitle,
    'foodEnabled': foodEnabled,
    'title': title,
    'description': description,
    'location': location,
    'startAtMillis': startAt.millisecondsSinceEpoch,
    'endAtMillis': endAt.millisecondsSinceEpoch,
    'audienceType': audienceType,
    'targetGroupIds': targetGroupIds,
    'targetStudentIds': targetStudentIds,
    'responsibleUserIds': responsibleNames.keys.toList(),
    'registrationRequired': registrationRequired,
    'requiresFamilyAuthorization': requiresFamilyAuthorization,
    'capacity': capacity,
    'links': links.map((e) => {'label': e.label, 'url': e.url}).toList(),
    'publicity': {'text': publicityText, 'url': publicityUrl},
    'requirements': requirements.map((e) => e.toMap()).toList(),
  };

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
    eventType: (map['eventType'] ?? 'student_presentation').toString(),
    subtitle: (map['subtitle'] ?? '').toString(),
    foodEnabled: map['foodEnabled'] == true,
    publicityText: ((map['publicity'] as Map?)?['text'] ?? '').toString(),
    publicityUrl: ((map['publicity'] as Map?)?['url'] ?? '').toString(),
    requirements: eventMaps(
      map['requirements'],
    ).map(EventRequirement.fromMap).toList(),
  );
}

List<Map<String, dynamic>> eventMaps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

class EventRequirement {
  const EventRequirement({
    required this.id,
    required this.label,
    this.instructions = '',
    this.targetType = 'student',
    this.completionType = 'manual',
    this.required = true,
    this.amountCop,
  });
  final String id, label, instructions, targetType, completionType;
  final bool required;
  final int? amountCop;
  String get targetLabel =>
      targetType == 'family' ? 'Cada familiar' : 'Estudiante';
  String get completionLabel => switch (completionType) {
    'attendance' => 'Asistencia',
    'payment' => 'Pago manual',
    _ => 'Verificación manual',
  };
  factory EventRequirement.fromMap(Map<String, dynamic> m) => EventRequirement(
    id: '${m['id'] ?? ''}',
    label: '${m['label'] ?? ''}',
    instructions: '${m['instructions'] ?? ''}',
    targetType: '${m['targetType'] ?? 'student'}',
    completionType: '${m['completionType'] ?? 'manual'}',
    required: m['required'] == true,
    amountCop: (m['amountCop'] as num?)?.toInt(),
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'instructions': instructions,
    'targetType': targetType,
    'completionType': completionType,
    'required': required,
    'amountCop': amountCop,
  };
}

class EventFoodItem {
  const EventFoodItem({
    required this.id,
    required this.name,
    required this.priceCop,
    this.description = '',
    this.active = true,
    this.revision = 1,
  });
  final String id, name, description;
  final int priceCop, revision;
  final bool active;
  factory EventFoodItem.fromMap(Map<String, dynamic> m) => EventFoodItem(
    id: '${m['id'] ?? ''}',
    name: '${m['name'] ?? ''}',
    description: '${m['description'] ?? ''}',
    priceCop: (m['priceCop'] as num?)?.toInt() ?? 0,
    active: m['active'] == true,
    revision: (m['revision'] as num?)?.toInt() ?? 1,
  );
}

class EventFoodOrder {
  const EventFoodOrder({
    required this.id,
    required this.familyId,
    required this.studentId,
    this.familyName = '',
    this.studentName = '',
    this.lines = const [],
    this.totalCop = 0,
    this.paymentState = 'pending',
    this.deliveryState = 'pending',
    this.state = 'reserved',
    this.revision = 1,
  });
  final String id,
      familyId,
      familyName,
      studentId,
      studentName,
      paymentState,
      deliveryState,
      state;
  final List<Map<String, dynamic>> lines;
  final int totalCop, revision;
  bool get locked => paymentState == 'paid' || deliveryState == 'delivered';
  factory EventFoodOrder.fromMap(Map<String, dynamic> m) => EventFoodOrder(
    id: '${m['id'] ?? ''}',
    familyId: '${m['familyId'] ?? ''}',
    familyName: '${m['familyName'] ?? ''}',
    studentId: '${m['studentId'] ?? ''}',
    studentName: '${m['studentName'] ?? ''}',
    lines: eventMaps(m['lines']),
    totalCop: (m['totalCop'] as num?)?.toInt() ?? 0,
    paymentState: '${m['paymentState'] ?? 'pending'}',
    deliveryState: '${m['deliveryState'] ?? 'pending'}',
    state: '${m['state'] ?? 'reserved'}',
    revision: (m['revision'] as num?)?.toInt() ?? 1,
  );
}

class EventMaterial {
  const EventMaterial({
    required this.id,
    required this.name,
    this.kind = 'material',
    this.instructions = '',
    this.amountCop,
    this.address = '',
    this.url = '',
    this.groupIds = const [],
    this.active = true,
    this.revision = 1,
  });
  final String id, name, kind, instructions, address, url;
  final int? amountCop;
  final List<String> groupIds;
  final bool active;
  final int revision;
  factory EventMaterial.fromMap(Map<String, dynamic> m) => EventMaterial(
    id: '${m['id'] ?? ''}',
    name: '${m['name'] ?? ''}',
    kind: '${m['kind'] ?? 'material'}',
    instructions: '${m['instructions'] ?? ''}',
    amountCop: (m['amountCop'] as num?)?.toInt(),
    address: '${m['address'] ?? ''}',
    url: '${m['url'] ?? ''}',
    groupIds: (m['groupIds'] as List? ?? const []).whereType<String>().toList(),
    active: m['active'] == true,
    revision: (m['revision'] as num?)?.toInt() ?? 1,
  );
}

class EventCompletion {
  const EventCompletion({
    required this.id,
    required this.requirementId,
    required this.targetType,
    required this.targetId,
    this.completed = false,
    this.revision = 1,
    this.markedAt,
    this.markedBy = '',
    this.studentContextIds = const [],
  });
  final String id, requirementId, targetType, targetId, markedBy;
  final bool completed;
  final int revision;
  final DateTime? markedAt;
  final List<String> studentContextIds;
  factory EventCompletion.fromMap(Map<String, dynamic> m) => EventCompletion(
    id: '${m['id'] ?? ''}',
    requirementId: '${m['requirementId'] ?? ''}',
    targetType: '${m['targetType'] ?? ''}',
    targetId: '${m['targetId'] ?? ''}',
    completed: m['completed'] == true,
    revision: (m['revision'] as num?)?.toInt() ?? 1,
    markedBy: '${m['performedByName'] ?? ''}',
    markedAt: m['completedAtMillis'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (m['completedAtMillis'] as num).toInt(),
          )
        : null,
    studentContextIds: (m['studentContextIds'] as List? ?? const [])
        .whereType<String>()
        .toList(),
  );
}

class EventDetail {
  const EventDetail({
    required this.event,
    this.foodItems = const [],
    this.orders = const [],
    this.materials = const [],
    this.completions = const [],
    this.participants = const [],
    this.capabilities = const {},
  });
  final SchoolEvent event;
  final List<EventFoodItem> foodItems;
  final List<EventFoodOrder> orders;
  final List<EventMaterial> materials;
  final List<EventCompletion> completions;
  final List<Map<String, dynamic>> participants;
  final Map<String, dynamic> capabilities;
  bool can(String action) => capabilities[action] == true;
  factory EventDetail.fromMap(Map<String, dynamic> m) => EventDetail(
    event: SchoolEvent.fromMap(Map<String, dynamic>.from(m['event'] as Map)),
    foodItems: eventMaps(m['foodItems']).map(EventFoodItem.fromMap).toList(),
    orders: eventMaps(m['orders']).map(EventFoodOrder.fromMap).toList(),
    materials: eventMaps(m['materials']).map(EventMaterial.fromMap).toList(),
    completions: eventMaps(
      m['completions'],
    ).map(EventCompletion.fromMap).toList(),
    participants: eventMaps(m['participants']),
    capabilities: Map<String, dynamic>.from(
      m['capabilities'] as Map? ?? const {},
    ),
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
