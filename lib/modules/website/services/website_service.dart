import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/website_content.dart';

class WebsiteService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  WebsiteService({FirebaseFirestore? db, FirebaseStorage? storage})
    : _db = db ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _document =>
      _db.collection('website').doc('main');

  Stream<WebsiteContent> watch() => _document.snapshots().map(
    (snapshot) =>
        snapshot.exists && snapshot.data() != null
            ? WebsiteContent.fromMap(snapshot.data()!)
            : WebsiteContent.defaults,
  );

  Future<WebsiteContent> get() async {
    final snapshot = await _document.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return WebsiteContent.defaults;
    }
    return WebsiteContent.fromMap(snapshot.data()!);
  }

  Future<void> save(WebsiteContent content) => _document.set({
    ...content.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
    'version': 2,
  });

  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      throw Exception('La imagen supera el máximo permitido de 10 MB.');
    }
    final extension = fileName.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final reference = _storage.ref(
      'website/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }
}
