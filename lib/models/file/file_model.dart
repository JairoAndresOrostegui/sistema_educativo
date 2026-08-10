import 'package:cloud_firestore/cloud_firestore.dart';

enum FileAudienceType { all, groups, students }

extension FileAudienceTypeValue on FileAudienceType {
  String get value => switch (this) {
    FileAudienceType.all => 'all',
    FileAudienceType.groups => 'groups',
    FileAudienceType.students => 'students',
  };

  String get label => switch (this) {
    FileAudienceType.all => 'Todos los estudiantes',
    FileAudienceType.groups => 'Uno o más grupos',
    FileAudienceType.students => 'Uno o más estudiantes',
  };
}

class FileAudienceGroup {
  final String id;
  final String name;

  const FileAudienceGroup({required this.id, required this.name});

  factory FileAudienceGroup.fromMap(Map<String, dynamic> data) =>
      FileAudienceGroup(id: data['id'] ?? '', name: data['name'] ?? '');
}

class FileAudienceStudent {
  final String id;
  final String name;
  final String groupId;
  final String groupName;

  const FileAudienceStudent({
    required this.id,
    required this.name,
    required this.groupId,
    required this.groupName,
  });

  factory FileAudienceStudent.fromMap(Map<String, dynamic> data) =>
      FileAudienceStudent(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        groupId: data['groupId'] ?? '',
        groupName: data['groupName'] ?? '',
      );
}

class FileAudienceOptions {
  final List<FileAudienceGroup> groups;
  final List<FileAudienceStudent> students;

  const FileAudienceOptions({required this.groups, required this.students});
}

class FileModel {
  final String id;
  final String name;
  final String storagePath;
  final FileAudienceType audienceType;
  final List<String> targetGroupIds;
  final List<String> targetGroupNames;
  final List<String> targetStudentIds;
  final String message;
  final String uploadedBy;
  final String uploaderName;
  final Timestamp sentAt;
  final int sizeBytes;

  FileModel({
    required this.id,
    required this.name,
    required this.storagePath,
    required this.audienceType,
    required this.targetGroupIds,
    required this.targetGroupNames,
    required this.targetStudentIds,
    required this.message,
    required this.uploadedBy,
    required this.uploaderName,
    required this.sentAt,
    required this.sizeBytes,
  });

  factory FileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FileModel.fromMap(data, id: doc.id);
  }

  factory FileModel.fromMap(Map<String, dynamic> data, {required String id}) {
    final audience = FileAudienceType.values.firstWhere(
      (item) => item.value == data['audienceType'],
      orElse: () => FileAudienceType.groups,
    );
    return FileModel(
      id: id,
      name: data['name'] ?? '',
      storagePath: data['storagePath'] ?? '',
      audienceType: audience,
      targetGroupIds: List<String>.from(data['targetGroupIds'] ?? const []),
      targetGroupNames: List<String>.from(data['targetGroupNames'] ?? const []),
      targetStudentIds: List<String>.from(data['targetStudentIds'] ?? const []),
      message: data['message'] ?? '',
      uploadedBy: data['uploadedBy'] ?? '',
      uploaderName: data['uploaderName'] ?? '',
      sentAt: data['sentAt'] is Timestamp
          ? data['sentAt'] as Timestamp
          : data['sentAtMillis'] is num
          ? Timestamp.fromMillisecondsSinceEpoch(
              (data['sentAtMillis'] as num).toInt(),
            )
          : data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
      sizeBytes: (data['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  String get audienceLabel => switch (audienceType) {
    FileAudienceType.all => 'Todos los estudiantes',
    FileAudienceType.groups => targetGroupNames.join(', '),
    FileAudienceType.students =>
      '${targetStudentIds.length} estudiante${targetStudentIds.length == 1 ? '' : 's'}',
  };
}
