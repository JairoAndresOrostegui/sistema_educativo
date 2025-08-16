import 'package:cloud_firestore/cloud_firestore.dart';

class FileModel {
  final String id;
  final String name;
  final String url;
  final String grade;
  final String uploadedBy;
  final String uploaderName;
  final Timestamp createdAt;

  FileModel({
    required this.id,
    required this.name,
    required this.url,
    required this.grade,
    required this.uploadedBy,
    required this.uploaderName,
    required this.createdAt,
  });

  factory FileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FileModel(
      id: doc.id,
      name: data['name'] ?? '',
      url: data['url'] ?? '',
      grade: data['grade'] ?? '',
      uploadedBy: data['uploadedBy'] ?? '',
      uploaderName: data['uploaderName'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'grade': grade,
      'uploadedBy': uploadedBy,
      'uploaderName': uploaderName,
      'createdAt': createdAt,
    };
  }
}
