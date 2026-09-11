import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectModel {
  final String? id;
  final String subject;
  final Timestamp startTime;
  final Timestamp endTime;
  final String teacherId;
  final String teacherName;
  final String groupId;
  final String groupName;
  final String? day;
  final String? campusId;
  final String? institutionId;
  final int revision;

  SubjectModel({
    this.id,
    required this.subject,
    required this.startTime,
    required this.endTime,
    required this.teacherId,
    required this.teacherName,
    required this.groupId,
    required this.groupName,
    this.day,
    this.campusId,
    this.institutionId,
    this.revision = 1,
  });

  factory SubjectModel.fromMap(Map<String, dynamic> data, {String? id}) {
    return SubjectModel(
      id: id,
      subject: data['subject'] as String,
      startTime: data['startTime'] as Timestamp,
      endTime: data['endTime'] as Timestamp,
      teacherId: data['teacherId'] as String,
      teacherName: data['teacherName'] as String,
      groupId: data['groupId'] as String,
      groupName: data['groupName'] as String,
      day: data['day'] as String?,
      campusId: data['campusId'] as String?,
      institutionId: data['institutionId'] as String?,
      revision: (data['revision'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'subject': subject,
      'startTime': startTime,
      'endTime': endTime,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'groupId': groupId,
      'groupName': groupName,
      if (day != null) 'day': day,
      if (campusId != null) 'campusId': campusId,
      if (institutionId != null) 'institutionId': institutionId,
      'revision': revision,
    };
  }

  SubjectModel copyWith({
    String? id,
    String? subject,
    Timestamp? startTime,
    Timestamp? endTime,
    String? teacherId,
    String? teacherName,
    String? groupId,
    String? groupName,
    String? day,
    String? campusId,
    String? institutionId,
    int? revision,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      day: day ?? this.day,
      campusId: campusId ?? this.campusId,
      institutionId: institutionId ?? this.institutionId,
      revision: revision ?? this.revision,
    );
  }

  factory SubjectModel.fromCallable(Map<String, dynamic> data) {
    final startMillis = (data['startTimeMillis'] as num?)?.toInt() ?? 0;
    final endMillis = (data['endTimeMillis'] as num?)?.toInt() ?? 0;
    return SubjectModel(
      id: data['id']?.toString(),
      subject: data['subject']?.toString() ?? '',
      startTime: Timestamp.fromMillisecondsSinceEpoch(startMillis),
      endTime: Timestamp.fromMillisecondsSinceEpoch(endMillis),
      teacherId: data['teacherId']?.toString() ?? '',
      teacherName: data['teacherName']?.toString() ?? '',
      groupId: data['groupId']?.toString() ?? '',
      groupName: data['groupName']?.toString() ?? '',
      day: data['day']?.toString(),
      campusId: data['campusId']?.toString(),
      institutionId: data['institutionId']?.toString(),
      revision: (data['revision'] as num?)?.toInt() ?? 1,
    );
  }
}
