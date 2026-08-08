import 'package:cloud_firestore/cloud_firestore.dart';

class FileModel {
  final String id;
  final String name;
  final String storagePath;
  final String groupId;
  final String groupName;
  final String uploadedBy;
  final String uploaderName;
  final Timestamp createdAt;
  final int sizeBytes;

  FileModel({
    required this.id,
    required this.name,
    required this.storagePath,
    required this.groupId,
    required this.groupName,
    required this.uploadedBy,
    required this.uploaderName,
    required this.createdAt,
    required this.sizeBytes,
  });

  factory FileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FileModel(
      id: doc.id,
      name: data['name'] ?? '',
      storagePath: data['storagePath'] ?? '',
      groupId: data['groupId'] ?? '',
      groupName: data['groupName'] ?? '',
      uploadedBy: data['uploadedBy'] ?? '',
      uploaderName: data['uploaderName'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
      sizeBytes: (data['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'storagePath': storagePath,
      'groupId': groupId,
      'groupName': groupName,
      'uploadedBy': uploadedBy,
      'uploaderName': uploaderName,
      'createdAt': createdAt,
      'sizeBytes': sizeBytes,
    };
  }
}
