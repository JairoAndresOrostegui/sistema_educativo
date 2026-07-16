import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/website_content.dart';

class WebsitePublishResult {
  final int deletedAssets;
  final List<String> cleanupWarnings;

  const WebsitePublishResult({
    required this.deletedAssets,
    required this.cleanupWarnings,
  });
}

class WebsiteSubmission {
  final String id;
  final String pageId;
  final String name;
  final String email;
  final String phone;
  final String message;
  final String status;
  final DateTime? createdAt;

  const WebsiteSubmission({
    required this.id,
    required this.pageId,
    required this.name,
    required this.email,
    required this.phone,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory WebsiteSubmission.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return WebsiteSubmission(
      id: document.id,
      pageId: (data['pageId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      status: (data['status'] ?? 'new').toString(),
      createdAt:
          data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
    );
  }
}

class WebsiteService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  WebsiteService({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _db = db ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  DocumentReference<Map<String, dynamic>> get _configDocument =>
      _db.collection('website').doc('config');

  DocumentReference<Map<String, dynamic>> get _legacyDocument =>
      _db.collection('website').doc('main');

  CollectionReference<Map<String, dynamic>> get _pages =>
      _db.collection('website_pages');

  Future<WebsiteBundle> getBundle() async {
    final results = await Future.wait([
      _configDocument.get(),
      _pages.orderBy('sortOrder').get(),
    ]);
    final configSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final pageSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
    if (configSnapshot.exists && configSnapshot.data() != null) {
      final config = WebsiteSiteConfig.fromMap(configSnapshot.data()!);
      final pages =
          pageSnapshot.docs
              .map((doc) => WebsitePage.fromMap(doc.id, doc.data()))
              .toList();
      return WebsiteBundle(
        config: config,
        pages: pages.isEmpty ? WebsiteBundle.defaults.pages : pages,
      );
    }

    final legacySnapshot = await _legacyDocument.get();
    if (!legacySnapshot.exists || legacySnapshot.data() == null) {
      return WebsiteBundle.defaults;
    }
    final legacy = WebsiteContent.fromMap(legacySnapshot.data()!);
    return legacy.toBundle(legacy.sectionsByPage);
  }

  Future<({WebsiteSiteConfig config, WebsitePage page})?> getPublicPage(
    String slug,
  ) async {
    final normalized = slug == '/' || slug.isEmpty ? 'home' : slug;
    final results = await Future.wait([
      _configDocument.get(),
      _pages.where('slug', isEqualTo: normalized).limit(1).get(),
    ]);
    final configSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final pageSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
    if (configSnapshot.exists &&
        configSnapshot.data() != null &&
        pageSnapshot.docs.isNotEmpty) {
      final doc = pageSnapshot.docs.first;
      final page = WebsitePage.fromMap(doc.id, doc.data());
      if (!page.enabled) return null;
      return (
        config: WebsiteSiteConfig.fromMap(configSnapshot.data()!),
        page: page,
      );
    }

    final bundle = await getBundle();
    for (final page in bundle.pages) {
      if (page.slug == normalized && page.enabled) {
        return (config: bundle.config, page: page);
      }
    }
    return null;
  }

  Future<WebsitePublishResult> publishBundle(
    WebsiteBundle bundle, {
    WebsiteBundle? previous,
  }) async {
    final oldBundle = previous ?? await getBundle();
    final existingPages = await _pages.get();
    final batch = _db.batch();
    batch.set(_configDocument, {
      ...bundle.config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final newIds = bundle.pages.map((page) => page.id).toSet();
    for (final page in bundle.pages) {
      batch.set(_pages.doc(page.id), {
        ...page.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    for (final existing in existingPages.docs) {
      if (!newIds.contains(existing.id)) batch.delete(existing.reference);
    }
    await batch.commit();

    final obsolete = oldBundle.managedAssetPaths.difference(
      bundle.managedAssetPaths,
    );
    var deleted = 0;
    final warnings = <String>[];
    for (final path in obsolete) {
      try {
        await _storage.ref(path).delete();
        deleted++;
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') {
          warnings.add('$path: ${error.code}');
        }
      }
    }
    return WebsitePublishResult(
      deletedAssets: deleted,
      cleanupWarnings: warnings,
    );
  }

  Future<WebsiteAsset> uploadImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      throw Exception('La imagen supera el máximo permitido de 10 MB.');
    }
    final lower = fileName.toLowerCase();
    final extension = lower.endsWith('.png') ? 'png' : 'jpg';
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'website/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final reference = _storage.ref(path);
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {'scope': 'website-cms-v3'},
      ),
    );
    return WebsiteAsset(
      url: await reference.getDownloadURL(),
      storagePath: path,
    );
  }

  Future<void> deleteAsset(WebsiteAsset asset) async {
    if (!asset.isManaged) return;
    try {
      await _storage.ref(asset.storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  Future<void> submitContactForm({
    required String pageId,
    required String blockId,
    required String name,
    required String email,
    required String phone,
    required String message,
    String website = '',
  }) async {
    await _functions.httpsCallable('submitWebsiteForm').call({
      'pageId': pageId,
      'blockId': blockId,
      'name': name,
      'email': email,
      'phone': phone,
      'message': message,
      'website': website,
    });
  }

  Stream<List<WebsiteSubmission>> watchSubmissions() => _db
      .collection('website_submissions')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(WebsiteSubmission.fromDocument).toList(),
      );

  Future<void> markSubmissionRead(String id) =>
      _db.collection('website_submissions').doc(id).update({'status': 'read'});

  Future<void> deleteSubmission(String id) =>
      _db.collection('website_submissions').doc(id).delete();
}
