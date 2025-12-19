import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DocumentPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  DocumentPage({
    required this.items,
    required this.hasNext,
    required this.lastDoc,
  });
}

class DocumentHistoryService {
  final _db = FirebaseFirestore.instance;

  static const filesCollection = 'files';
  static const archivosCollection = 'archivos';

  /// Página de documentos con filtros (institución/campus + grade + rango) y paginación por cursor.
  Future<DocumentPage> obtenerHistorialDocumentos({
    required String institutionId,
    required String campusId,
    String? grade,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    // Primero intentamos en 'files' (esquema nuevo).
    var page = await _queryFiles(
      col: filesCollection,
      institutionId: institutionId,
      campusId: campusId,
      grade: grade,
      rango: rango,
      limite: limite,
      startAfter: startAfter,
      isEnglish: true,
    );

    // Si no hay datos, probamos 'archivos' (esquema viejo) con los mismos filtros.
    if (page.items.isEmpty) {
      final fallback = await _queryFiles(
        col: archivosCollection,
        institutionId: institutionId,
        campusId: campusId,
        grade: grade,
        rango: rango,
        limite: limite,
        startAfter: startAfter,
        isEnglish: false,
      );
      page = fallback;
    }

    return page;
  }

  Future<DocumentPage> _queryFiles({
    required String col,
    required String institutionId,
    required String campusId,
    required String? grade,
    required DateTimeRange? rango,
    required int limite,
    required DocumentSnapshot<Map<String, dynamic>>? startAfter,
    required bool isEnglish,
  }) async {
    // Campos por esquema
    final createdField = isEnglish ? 'createdAt' : 'fechaSubida';
    final gradeField = isEnglish ? 'grade' : 'grado';
    // Para ambos esquemas exigimos los mismos nombres de filtros de tenant:
    // (Si el esquema viejo no tiene estos campos, no devolverá resultados —requisito del nuevo modelo multi-tenant).
    const instField = 'institutionId';
    const campusField = 'campusId';

    Query<Map<String, dynamic>> q = _db
        .collection(col)
        .where(instField, isEqualTo: institutionId)
        .where(campusField, isEqualTo: campusId)
        .orderBy(createdField, descending: true)
        .limit(limite);

    if (grade != null && grade.trim().isNotEmpty) {
      q = q.where(gradeField, isEqualTo: grade.trim());
    }
    if (rango != null) {
      q = q
          .where(
            createdField,
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where(
            createdField,
            isLessThanOrEqualTo: Timestamp.fromDate(rango.end),
          );
    }
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final docs = snap.docs;

    final items = <Map<String, dynamic>>[];
    for (final d in docs) {
      final data = d.data();

      if (isEnglish) {
        // Mapear a español para exportes/listas
        items.add({
          'id': data['id'] ?? d.id,
          'nombre': data['name'] ?? '',
          'grado': data['grade'] ?? '',
          'subidoPor': data['uploaderName'] ?? data['uploadedBy'] ?? '',
          'fechaSubida': (data['createdAt'] as Timestamp?)?.toDate(),
          'url': data['url'],
          'storagePath': data['storagePath'],
        });
      } else {
        items.add({
          'id': data['id'] ?? d.id,
          'nombre': data['nombre'] ?? '',
          'grado': data['grado'] ?? '',
          'subidoPor': data['subidoPor'] ?? '',
          'fechaSubida': (data['fechaSubida'] as Timestamp?)?.toDate(),
          'url': data['url'],
          'storagePath': data['rutaStorage'] ?? data['storagePath'],
        });
      }
    }

    final hasNext = docs.length == limite;
    final lastDoc = docs.isNotEmpty ? docs.last : null;

    return DocumentPage(items: items, hasNext: hasNext, lastDoc: lastDoc);
  }

  /// Devuelve grados únicos filtrados por institución/campus (prueba EN y luego ES).
  Future<List<String>> obtenerGrados({
    required String institutionId,
    required String campusId,
  }) async {
    final set = <String>{};

    // EN
    final enSnap =
        await _db
            .collection(filesCollection)
            .where('institutionId', isEqualTo: institutionId)
            .where('campusId', isEqualTo: campusId)
            .limit(500)
            .get();
    for (final d in enSnap.docs) {
      final g = (d.data()['grade'] ?? '').toString().trim();
      if (g.isNotEmpty) set.add(g);
    }

    // ES (fallback) — también filtrado por tenant
    if (set.isEmpty) {
      final esSnap =
          await _db
              .collection(archivosCollection)
              .where('institutionId', isEqualTo: institutionId)
              .where('campusId', isEqualTo: campusId)
              .limit(500)
              .get();
      for (final d in esSnap.docs) {
        final g = (d.data()['grado'] ?? '').toString().trim();
        if (g.isNotEmpty) set.add(g);
      }
    }

    final list = set.toList()..sort();
    return list;
  }

  /// Conteo total con filtros (tenant + grade + rango).
  Future<int> contarTotalDocumentos({
    required String institutionId,
    required String campusId,
    String? grade,
    DateTimeRange? rango,
  }) async {
    // Intento EN
    final enCount = await _countIn(
      col: filesCollection,
      createdField: 'createdAt',
      gradeField: 'grade',
      institutionId: institutionId,
      campusId: campusId,
      grade: grade,
      rango: rango,
    );
    if (enCount != null) return enCount;

    // Fallback ES
    final esCount = await _countIn(
      col: archivosCollection,
      createdField: 'fechaSubida',
      gradeField: 'grado',
      institutionId: institutionId,
      campusId: campusId,
      grade: grade,
      rango: rango,
    );
    return esCount ?? 0;
  }

  Future<int?> _countIn({
    required String col,
    required String createdField,
    required String gradeField,
    required String institutionId,
    required String campusId,
    required String? grade,
    required DateTimeRange? rango,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _db
          .collection(col)
          .where('institutionId', isEqualTo: institutionId)
          .where('campusId', isEqualTo: campusId);

      if (grade != null && grade.trim().isNotEmpty) {
        q = q.where(gradeField, isEqualTo: grade.trim());
      }
      if (rango != null) {
        q = q
            .where(
              createdField,
              isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
            )
            .where(
              createdField,
              isLessThanOrEqualTo: Timestamp.fromDate(rango.end),
            );
      }

      final snap = await q.get();
      return snap.docs.length;
    } catch (_) {
      return null;
    }
  }
}
