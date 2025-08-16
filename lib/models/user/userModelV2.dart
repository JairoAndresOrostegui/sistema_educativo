import 'package:cloud_firestore/cloud_firestore.dart';

class UserModelV2 {
  final String id;
  final String firstName;
  final String lastName;
  final String document;
  final String documentType;
  final String personalEmail;
  final String institutionalEmail;
  final String? photoUrl;
  final DateTime? birthDate;
  final String? birthCountry;
  final String? birthDepartment;
  final String? birthCity;
  final String? address;
  final String? residenceCountry;
  final String? residenceDepartment;
  final String? residenceCity;
  final String role;
  final String? grade;
  final String institution;
  final String campus;
  final bool isSuperadmin;
  final String status;
  final List<String> phones;
  final List<String> permissions;
  final String? fcmToken;
  final String? familyRelation;
  final List<String>? studentIds;
  final String? activeStudentId;

  UserModelV2({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.document,
    required this.documentType,
    required this.personalEmail,
    required this.institutionalEmail,
    this.photoUrl,
    this.birthDate,
    this.birthCountry,
    this.birthDepartment,
    this.birthCity,
    this.address,
    this.residenceCountry,
    this.residenceDepartment,
    this.residenceCity,
    required this.role,
    this.grade,
    required this.institution,
    required this.campus,
    required this.isSuperadmin,
    required this.status,
    required this.phones,
    required this.permissions,
    this.fcmToken,
    this.familyRelation,
    this.studentIds,
    this.activeStudentId,
  });

  factory UserModelV2.fromFirestore(Map<String, dynamic> map, String id) {
    return UserModelV2(
      id: id,
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      document: map['document'] ?? '',
      documentType: map['documentType'] ?? '',
      personalEmail: map['personalEmail'] ?? '',
      institutionalEmail: map['institutionalEmail'] ?? '',
      photoUrl: map['photoUrl'],
      birthDate: map['birthDate'] is Timestamp
          ? (map['birthDate'] as Timestamp).toDate()
          : null,
      birthCountry: map['birthCountry'],
      birthDepartment: map['birthDepartment'],
      birthCity: map['birthCity'],
      address: map['address'],
      residenceCountry: map['residenceCountry'],
      residenceDepartment: map['residenceDepartment'],
      residenceCity: map['residenceCity'],
      role: map['role'] ?? '',
      grade: map['grade'],
      institution: map['institution'] ?? '',
      campus: map['campus'] ?? '',
      isSuperadmin: map['isSuperadmin'] ?? false,
      status: map['status'] ?? 'activo',
      phones: List<String>.from(map['phones'] ?? []),
      permissions: List<String>.from(map['permissions'] ?? []),
      fcmToken: map['fcmToken'],
      familyRelation: map['familyRelation'],
      studentIds: map['studentIds'] != null ? List<String>.from(map['studentIds']) : null,
      activeStudentId: map['activeStudentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'document': document,
      'documentType': documentType,
      'personalEmail': personalEmail,
      'institutionalEmail': institutionalEmail,
      'photoUrl': photoUrl,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'birthCountry': birthCountry,
      'birthDepartment': birthDepartment,
      'birthCity': birthCity,
      'address': address,
      'residenceCountry': residenceCountry,
      'residenceDepartment': residenceDepartment,
      'residenceCity': residenceCity,
      'role': role,
      'grade': grade,
      'institution': institution,
      'campus': campus,
      'isSuperadmin': isSuperadmin,
      'status': status,
      'phones': phones,
      'permissions': permissions,
      'fcmToken': fcmToken,
      'familyRelation': familyRelation,
      'studentIds': studentIds,
      'activeStudentId': activeStudentId,
    };
  }

  UserModelV2 copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? document,
    String? documentType,
    String? personalEmail,
    String? institutionalEmail,
    String? photoUrl,
    DateTime? birthDate,
    String? birthCountry,
    String? birthDepartment,
    String? birthCity,
    String? address,
    String? residenceCountry,
    String? residenceDepartment,
    String? residenceCity,
    String? role,
    String? grade,
    String? institution,
    String? campus,
    bool? isSuperadmin,
    String? status,
    List<String>? phones,
    List<String>? permissions,
    String? fcmToken,
    String? familyRelation,
    List<String>? studentIds,
    String? activeStudentId,
  }) {
    return UserModelV2(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      document: document ?? this.document,
      documentType: documentType ?? this.documentType,
      personalEmail: personalEmail ?? this.personalEmail,
      institutionalEmail: institutionalEmail ?? this.institutionalEmail,
      photoUrl: photoUrl ?? this.photoUrl,
      birthDate: birthDate ?? this.birthDate,
      birthCountry: birthCountry ?? this.birthCountry,
      birthDepartment: birthDepartment ?? this.birthDepartment,
      birthCity: birthCity ?? this.birthCity,
      address: address ?? this.address,
      residenceCountry: residenceCountry ?? this.residenceCountry,
      residenceDepartment: residenceDepartment ?? this.residenceDepartment,
      residenceCity: residenceCity ?? this.residenceCity,
      role: role ?? this.role,
      grade: grade ?? this.grade,
      institution: institution ?? this.institution,
      campus: campus ?? this.campus,
      isSuperadmin: isSuperadmin ?? this.isSuperadmin,
      status: status ?? this.status,
      phones: phones ?? this.phones,
      permissions: permissions ?? this.permissions,
      fcmToken: fcmToken ?? this.fcmToken,
      familyRelation: familyRelation ?? this.familyRelation,
      studentIds: studentIds ?? this.studentIds,
      activeStudentId: activeStudentId ?? this.activeStudentId,
    );
  }
}
