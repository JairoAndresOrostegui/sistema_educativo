import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScheduleHistoryPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  ScheduleHistoryPage({
    required this.items,
    required this.hasNext,
    required this.lastDoc,
  });
}

class AdminScheduleHistoryService {
  final _db = FirebaseFirestore.instance;

  // Colecciones (nuevo / legado)
  static const scheduleHistoryCollection = 'schedule_history'; // vigente (EN)
  static const historialHorariosCollection = 'historial_horarios'; // legado (ES)

  /// Página de historial de horarios con filtros y paginación por cursor.
  /// Normaliza SIEMPRE a claves en español:
  /// grado, materia, dia, accion, usuarioNombre, fecha, mensaje
  Future<ScheduleHistoryPage> obtenerHistorialHorarios({
    String? gradeContains,
    String? subjectContains,
    String? day, // lunes..domingo
    String? action, // create_subject|update_subject|delete_subject
    DateTimeRange? rango, // timestamp/fecha
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    // 1) Intento en EN
    var page = await _queryEn(
      gradeContains: gradeContains,
      subjectContains: subjectContains,
      day: day,
      action: action,
      rango: rango,
      limite: limite,
      startAfter: startAfter,
    );

    // 2) Fallback ES si vacío
    if (page.items.isEmpty) {
      page = await _queryEs(
        gradeContains: gradeContains,
        subjectContains: subjectContains,
        day: day,
        action: action,
        rango: rango,
        limite: limite,
        startAfter: startAfter,
      );
    }

    return page;
  }

  // ===== EN =====
  Future<ScheduleHistoryPage> _queryEn({
    String? gradeContains,
    String? subjectContains,
    String? day,
    String? action,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection(scheduleHistoryCollection)
        .orderBy('timestamp', descending: true)
        .limit(limite);

    if (action != null && action.trim().isNotEmpty) {
      q = q.where('action', isEqualTo: action.trim());
    }
    if (day != null && day.trim().isNotEmpty) {
      q = q.where('subjectData.day', isEqualTo: day.trim());
    }
    if (rango != null) {
      q = q
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where(
            'timestamp',
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
      final sd = (data['subjectData'] as Map<String, dynamic>?) ?? {};

      final grado = (sd['grade'] ?? '').toString();
      final materia = (sd['subject'] ?? '').toString();

      // Filtros "contains" en memoria
      if (gradeContains != null && gradeContains.trim().isNotEmpty) {
        if (!grado.toLowerCase().contains(gradeContains.toLowerCase())) {
          continue;
        }
      }
      if (subjectContains != null && subjectContains.trim().isNotEmpty) {
        if (!materia.toLowerCase().contains(subjectContains.toLowerCase())) {
          continue;
        }
      }

      items.add({
        'id': d.id,
        'grado': grado,
        'materia': materia,
        'dia': (sd['day'] ?? '').toString(),
        'accion': (data['action'] ?? '').toString(),
        'usuarioNombre': (data['userName'] ?? '').toString(),
        'fecha': (data['timestamp'] as Timestamp?)?.toDate(),
        'mensaje': (data['message'] ?? '').toString(),
      });
    }

    final hasNext = docs.length == limite;
    final lastDoc = docs.isNotEmpty ? docs.last : null;
    return ScheduleHistoryPage(
      items: items,
      hasNext: hasNext,
      lastDoc: lastDoc,
    );
  }

  // ===== ES (legado) =====
  Future<ScheduleHistoryPage> _queryEs({
    String? gradeContains,
    String? subjectContains,
    String? day,
    String? action,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection(historialHorariosCollection)
        .orderBy('fecha', descending: true)
        .limit(limite);

    if (action != null && action.trim().isNotEmpty) {
      q = q.where('accion', isEqualTo: action.trim()); // puede o no coincidir
    }
    if (day != null && day.trim().isNotEmpty) {
      q = q.where('dia', isEqualTo: day.trim());
    }
    if (rango != null) {
      q = q
          .where(
            'fecha',
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(rango.end));
    }
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final docs = snap.docs;

    final items = <Map<String, dynamic>>[];
    for (final d in docs) {
      final data = d.data();

      final grado = (data['grado'] ?? '').toString();
      final materia = (data['materia'] ?? '').toString();

      if (gradeContains != null && gradeContains.trim().isNotEmpty) {
        if (!grado.toLowerCase().contains(gradeContains.toLowerCase())) {
          continue;
        }
      }
      if (subjectContains != null && subjectContains.trim().isNotEmpty) {
        if (!materia.toLowerCase().contains(subjectContains.toLowerCase())) {
          continue;
        }
      }

      items.add({
        'id': d.id,
        'grado': grado,
        'materia': materia,
        'dia': (data['dia'] ?? '').toString(),
        'accion': (data['accion'] ?? '').toString(),
        'usuarioNombre':
            (data['usuarioNombre'] ?? data['userName'] ?? '').toString(),
        'fecha': (data['fecha'] as Timestamp?)?.toDate(),
        'mensaje': (data['mensaje'] ?? data['message'] ?? '').toString(),
      });
    }

    final hasNext = docs.length == limite;
    final lastDoc = docs.isNotEmpty ? docs.last : null;
    return ScheduleHistoryPage(
      items: items,
      hasNext: hasNext,
      lastDoc: lastDoc,
    );
  }

  /// Conteo total (aprox.) con filtros por acción, día y rango.
  /// *Los filtros "contains" (grado/materia) se aplican en UI; si quisieras
  /// conteo exacto con 'contains' requeriría escaneo completo.*
  Future<int> contarTotal({
    String? action,
    String? day,
    DateTimeRange? rango,
    String? gradeContains,
    String? subjectContains,
  }) async {
    int total =
        await _countIn(
      col: scheduleHistoryCollection,
          dateField: 'timestamp',
          actionField: 'action',
          dayField: 'subjectData.day',
          action: action,
          day: day,
          rango: rango,
        ) ??
        0;

    if (total == 0) {
      total =
          await _countIn(
            col: historialHorariosCollection,
            dateField: 'fecha',
            actionField: 'accion',
            dayField: 'dia',
            action: action,
            day: day,
            rango: rango,
          ) ??
          0;
    }

    // No ajustamos por 'contains' aquí (ver nota arriba).
    return total;
  }

  Future<int?> _countIn({
    required String col,
    required String dateField,
    required String actionField,
    required String dayField,
    String? action,
    String? day,
    DateTimeRange? rango,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _db.collection(col);
      if (action != null && action.trim().isNotEmpty) {
        q = q.where(actionField, isEqualTo: action.trim());
      }
      if (day != null && day.trim().isNotEmpty) {
        q = q.where(dayField, isEqualTo: day.trim());
      }
      if (rango != null) {
        q = q
            .where(
              dateField,
              isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
            )
            .where(
              dateField,
              isLessThanOrEqualTo: Timestamp.fromDate(rango.end),
            );
      }

      // Si tu SDK soporta agregaciones:
      // final agg = await q.count().get();
      // return agg.count;

      final snap = await q.get();
      return snap.docs.length;
    } catch (_) {
      return null;
    }
  }
}
