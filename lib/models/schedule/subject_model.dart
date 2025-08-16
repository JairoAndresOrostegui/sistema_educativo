import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectModel {
  final String? id;
  final String subject;
  final Timestamp startTime;
  final Timestamp endTime;
  final String teacherId;
  final String teacherName;
  final String? grade;
  final String? day;
  final String? campusId;
  final String? institutionId;

  SubjectModel({
    this.id,
    required this.subject,
    required this.startTime,
    required this.endTime,
    required this.teacherId,
    required this.teacherName,
    this.grade,
    this.day,
    this.campusId,
    this.institutionId,
  });

  factory SubjectModel.fromMap(Map<String, dynamic> data, {String? id}) {
    return SubjectModel(
      id: id,
      subject: data['subject'] as String,
      startTime: data['startTime'] as Timestamp,
      endTime: data['endTime'] as Timestamp,
      teacherId: data['teacherId'] as String,
      teacherName: data['teacherName'] as String,
      grade: data['grade'] as String?,
      day: data['day'] as String?,
      campusId: data['campusId'] as String?,
      institutionId: data['institutionId'] as String?,
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
      if (grade != null) 'grade': grade,
      if (day != null) 'day': day,
      if (campusId != null) 'campusId': campusId,
      if (institutionId != null) 'institutionId': institutionId,
    };
  }

  SubjectModel copyWith({
    String? id,
    String? subject,
    Timestamp? startTime,
    Timestamp? endTime,
    String? teacherId,
    String? teacherName,
    String? grade,
    String? day,
    String? campusId,
    String? institutionId,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      grade: grade ?? this.grade,
      day: day ?? this.day,
      campusId: campusId ?? this.campusId,
      institutionId: institutionId ?? this.institutionId,
    );
  }
}
