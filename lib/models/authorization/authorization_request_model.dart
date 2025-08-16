import 'package:cloud_firestore/cloud_firestore.dart';

enum AuthorizationStatus { pending, approved, rejected, finished }

String authorizationStatusToString(AuthorizationStatus s) {
  switch (s) {
    case AuthorizationStatus.pending:
      return 'pending';
    case AuthorizationStatus.approved:
      return 'approved';
    case AuthorizationStatus.rejected:
      return 'rejected';
    case AuthorizationStatus.finished:
      return 'finished';
  }
}

AuthorizationStatus authorizationStatusFromString(String v) {
  switch (v) {
    case 'approved':
      return AuthorizationStatus.approved;
    case 'rejected':
      return AuthorizationStatus.rejected;
    case 'finished':
      return AuthorizationStatus.finished;
    default:
      return AuthorizationStatus.pending;
  }
}

class AuthorizationRequest {
  final String id;
  final String institutionId;
  final String campusId;
  final String studentId;
  final String studentFullName;
  final String grade;
  final String requesterId;
  final String requesterFullName;
  final bool allDay;
  final bool multiDay;
  final DateTime dateFrom;
  final DateTime? dateTo;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? reason;
  final AuthorizationStatus status;
  final String? adminNote;
  final String? evidence;
  final String? resubmissionOfRequestId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AuthorizationRequest({
    required this.id,
    required this.institutionId,
    required this.campusId,
    required this.studentId,
    required this.studentFullName,
    required this.grade,
    required this.requesterId,
    required this.requesterFullName,
    required this.allDay,
    required this.multiDay,
    required this.dateFrom,
    this.dateTo,
    this.startTime,
    this.endTime,
    this.reason,
    required this.status,
    this.adminNote,
    this.evidence,
    this.resubmissionOfRequestId,
    this.createdAt,
    this.updatedAt,
  });

  static DateTime? _toDt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  factory AuthorizationRequest.fromMap(Map<String, dynamic> m, String id) {
    return AuthorizationRequest(
      id: id,
      institutionId: (m['institutionId'] ?? '').toString(),
      campusId: (m['campusId'] ?? '').toString(),
      studentId: (m['studentId'] ?? '').toString(),
      studentFullName: (m['studentFullName'] ?? '').toString(),
      grade: (m['grade'] ?? '').toString(),
      requesterId: (m['requesterId'] ?? '').toString(),
      requesterFullName: (m['requesterFullName'] ?? '').toString(),
      allDay: m['allDay'] == true,
      multiDay: m['multiDay'] == true,
      dateFrom: _toDt(m['dateFrom']) ?? DateTime.now(),
      dateTo: _toDt(m['dateTo']),
      startTime: _toDt(m['startTime']),
      endTime: _toDt(m['endTime']),
      reason:
          (m['reason'] ?? '').toString().isEmpty
              ? null
              : m['reason'].toString(),
      status: authorizationStatusFromString(
        (m['status'] ?? 'pending').toString(),
      ),
      adminNote:
          (m['adminNote'] ?? '').toString().isEmpty
              ? null
              : m['adminNote'].toString(),
      evidence:
          (m['evidence'] ?? '').toString().isEmpty
              ? null
              : m['evidence'].toString(),
      resubmissionOfRequestId:
          (m['resubmissionOfRequestId'] ?? '').toString().isEmpty
              ? null
              : m['resubmissionOfRequestId'].toString(),
      createdAt: _toDt(m['createdAt']),
      updatedAt: _toDt(m['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'institutionId': institutionId,
      'campusId': campusId,
      'studentId': studentId,
      'studentFullName': studentFullName,
      'grade': grade,
      'requesterId': requesterId,
      'requesterFullName': requesterFullName,
      'allDay': allDay,
      'multiDay': multiDay,
      'dateFrom': dateFrom,
      'dateTo': dateTo,
      'startTime': startTime,
      'endTime': endTime,
      'reason': reason,
      'status': authorizationStatusToString(status),
      'adminNote': adminNote,
      'evidence': evidence,
      'resubmissionOfRequestId': resubmissionOfRequestId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  AuthorizationRequest copyWith({
    String? id,
    String? institutionId,
    String? campusId,
    String? studentId,
    String? studentFullName,
    String? grade,
    String? requesterId,
    String? requesterFullName,
    bool? allDay,
    bool? multiDay,
    DateTime? dateFrom,
    DateTime? dateTo,
    DateTime? startTime,
    DateTime? endTime,
    String? reason,
    AuthorizationStatus? status,
    String? adminNote,
    String? evidence,
    String? resubmissionOfRequestId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuthorizationRequest(
      id: id ?? this.id,
      institutionId: institutionId ?? this.institutionId,
      campusId: campusId ?? this.campusId,
      studentId: studentId ?? this.studentId,
      studentFullName: studentFullName ?? this.studentFullName,
      grade: grade ?? this.grade,
      requesterId: requesterId ?? this.requesterId,
      requesterFullName: requesterFullName ?? this.requesterFullName,
      allDay: allDay ?? this.allDay,
      multiDay: multiDay ?? this.multiDay,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      adminNote: adminNote ?? this.adminNote,
      evidence: evidence ?? this.evidence,
      resubmissionOfRequestId:
          resubmissionOfRequestId ?? this.resubmissionOfRequestId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
