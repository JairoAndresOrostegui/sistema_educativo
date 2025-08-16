import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserHistoryPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  UserHistoryPage({required this.items, required this.hasNext, required this.lastDoc});
}

class AdminUserHistoryService {
  final _db = FirebaseFirestore.instance;

  // Colecciones (nuevo / legado)
  static const _COL_EN = 'user_history';         // vigente
  static const _COL_ES = 'historial_usuarios';   // legado

  /// Devuelve página normalizada a claves en español:
  /// accion, nombres, apellidos, rol, realizadoPor, fecha, campus, institution, usuarioId
  Future<UserHistoryPage> obtenerHistorial({
    String? nameContains,
    String? role,
    String? action,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    // 1) Intento en 'user_history'
    var page = await _query(
      col: _COL_EN,
      dateField: 'fecha', // en tus datos nuevos 'fecha' existe; intentamos primero
      fallbacksDate: const ['date', 'timestamp'],
      roleField: 'rol',
      actionField: 'accion',
      performedByNameField: 'realizadoPor',
      nameFields: const ['nombres', 'apellidos'], // ya vienen en ES
      extraCampusField: 'campus',
      extraInstitutionField: 'institution',
      userIdField: 'usuarioId',
      nameContains: nameContains,
      role: role,
      action: action,
      rango: rango,
      limite: limite,
      startAfter: startAfter,
    );

    // 2) Fallback legado si vacío
    if (page.items.isEmpty) {
      page = await _query(
        col: _COL_ES,
        dateField: 'fecha',
        fallbacksDate: const [],
        roleField: 'rol',
        actionField: 'accion',
        performedByNameField: 'realizadoPor',
        nameFields: const ['nombres', 'apellidos'],
        extraCampusField: 'campus',
        extraInstitutionField: 'institution',
        userIdField: 'usuarioId',
        nameContains: nameContains,
        role: role,
        action: action,
        rango: rango,
        limite: limite,
        startAfter: startAfter,
      );
    }

    return page;
  }

  Future<UserHistoryPage> _query({
    required String col,
    required String dateField,
    required List<String> fallbacksDate,
    required String roleField,
    required String actionField,
    required String performedByNameField,
    required List<String> nameFields,
    required String extraCampusField,
    required String extraInstitutionField,
    required String userIdField,
    String? nameContains,
    String? role,
    String? action,
    DateTimeRange? rango,
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    // Construye query base
    Query<Map<String, dynamic>> q = _db.collection(col).orderBy(dateField, descending: true).limit(limite);

    // Igualdades que pueden requerir índices combinados
    if (role != null && role.trim().isNotEmpty) {
      q = q.where(roleField, isEqualTo: role.trim());
    }
    if (action != null && action.trim().isNotEmpty) {
      q = q.where(actionField, isEqualTo: action.trim());
    }

    // Rango de fechas
    if (rango != null) {
      q = q
          .where(dateField, isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start))
          .where(dateField, isLessThanOrEqualTo: Timestamp.fromDate(rango.end));
    }

    // Cursor
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    // Ejecuta
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await q.get();
    } catch (_) {
      // Si falló por ordenar en un field distinto (p. ej. el doc usa 'date' en vez de 'fecha'),
      // intenta con los alternos
      for (final alt in fallbacksDate) {
        try {
          Query<Map<String, dynamic>> q2 = _db.collection(col).orderBy(alt, descending: true).limit(limite);
          if (role != null && role.trim().isNotEmpty) {
            q2 = q2.where(roleField, isEqualTo: role.trim());
          }
          if (action != null && action.trim().isNotEmpty) {
            q2 = q2.where(actionField, isEqualTo: action.trim());
          }
          if (rango != null) {
            q2 = q2
                .where(alt, isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start))
                .where(alt, isLessThanOrEqualTo: Timestamp.fromDate(rango.end));
          }
          if (startAfter != null) {
            q2 = q2.startAfterDocument(startAfter);
          }
          snap = await q2.get();
          // Si funcionó con 'alt', forzamos usar ese campo como 'dateField' efectivo
          return _normalizePage(
            docs: snap.docs,
            dateFieldTried: alt,
            roleField: roleField,
            actionField: actionField,
            performedByNameField: performedByNameField,
            nameFields: nameFields,
            extraCampusField: extraCampusField,
            extraInstitutionField: extraInstitutionField,
            userIdField: userIdField,
            limite: limite,
          );
        } catch (_) {
          continue;
        }
      }
      // Si todos fallaron, devuelve vacío
      return UserHistoryPage(items: const [], hasNext: false, lastDoc: null);
    }

    // Normaliza con el campo original
    return _normalizePage(
      docs: snap.docs,
      dateFieldTried: dateField,
      roleField: roleField,
      actionField: actionField,
      performedByNameField: performedByNameField,
      nameFields: nameFields,
      extraCampusField: extraCampusField,
      extraInstitutionField: extraInstitutionField,
      userIdField: userIdField,
      limite: limite,
    );
  }

  UserHistoryPage _normalizePage({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String dateFieldTried,
    required String roleField,
    required String actionField,
    required String performedByNameField,
    required List<String> nameFields,
    required String extraCampusField,
    required String extraInstitutionField,
    required String userIdField,
    required int limite,
  }) {
    final items = <Map<String, dynamic>>[];

    for (final d in docs) {
      final data = d.data();

      // Normalización a español (con posibles alias en EN)
      final nombres = (data['nombres'] ?? data['firstName'] ?? '').toString();
      final apellidos = (data['apellidos'] ?? data['lastName'] ?? '').toString();
      final rol = (data[roleField] ?? data['role'] ?? '').toString();
      final accion = (data[actionField] ?? data['action'] ?? '').toString();
      final realizadoPor =
          (data[performedByNameField] ??
                  data['performedByName'] ??
                  data['performedBy'] ??
                  data['userName'] ??
                  '')
              .toString();

      // Fecha puede venir en 'fecha', 'date' o 'timestamp'
      Timestamp? ts = data[dateFieldTried] as Timestamp?;
      ts ??= data['fecha'] as Timestamp?;
      ts ??= data['date'] as Timestamp?;
      ts ??= data['timestamp'] as Timestamp?;
      final fecha = ts?.toDate();

      items.add({
        'id': d.id,
        'accion': accion,
        'nombres': nombres,
        'apellidos': apellidos,
        'rol': rol,
        'realizadoPor': realizadoPor,
        'fecha': fecha,
        'campus': (data[extraCampusField] ?? data['campus'] ?? '').toString(),
        'institution': (data[extraInstitutionField] ?? data['institution'] ?? '').toString(),
        'usuarioId': (data[userIdField] ?? data['userId'] ?? '').toString(),
      });
    }

    // Filtro "contains" por nombre completo en MEMORIA (no rompe índices)
    // *Ojo*: si quieres que afecte al total, habría que escanear; aquí mantenemos total aprox.
    // (igual que hicimos en los demás módulos).
    // NOTA: se hace en la vista; aquí devolvemos la página tal cual.

    final hasNext = docs.length == limite;
    final lastDoc = docs.isNotEmpty ? docs.last : null;
    return UserHistoryPage(items: items, hasNext: hasNext, lastDoc: lastDoc);
  }

  Future<int> contarTotal({
    String? role,
    String? action,
    DateTimeRange? rango,
    String? nameContains, // NOTA: este "contains" no se aplica aquí (sería costoso)
  }) async {
    int total = await _countIn(
          col: _COL_EN,
          dateField: 'fecha',
          actionField: 'accion',
          roleField: 'rol',
          role: role,
          action: action,
          rango: rango,
        ) ??
        0;

    if (total == 0) {
      total = await _countIn(
            col: _COL_ES,
            dateField: 'fecha',
            actionField: 'accion',
            roleField: 'rol',
            role: role,
            action: action,
            rango: rango,
          ) ??
          0;
    }
    return total;
  }

  Future<int?> _countIn({
    required String col,
    required String dateField,
    required String actionField,
    required String roleField,
    String? role,
    String? action,
    DateTimeRange? rango,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _db.collection(col);
      if (role != null && role.trim().isNotEmpty) {
        q = q.where(roleField, isEqualTo: role.trim());
      }
      if (action != null && action.trim().isNotEmpty) {
        q = q.where(actionField, isEqualTo: action.trim());
      }
      if (rango != null) {
        q = q
            .where(dateField, isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start))
            .where(dateField, isLessThanOrEqualTo: Timestamp.fromDate(rango.end));
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
