import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RouteHistoryPage {
  final List<Map<String, dynamic>> items;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  RouteHistoryPage({
    required this.items,
    required this.hasNext,
    required this.lastDoc,
  });
}

class AdminRouteHistoryService {
  final _db = FirebaseFirestore.instance;

  // Colecciones (nuevo/es)
  static const routesAdminHistoryCollection = 'routes_admin_history'; // vigente
  static const historialRutasAdminCollection = 'historial_rutas_admin'; // legado

  /// Página con filtros + paginación por cursor.
  /// - Normaliza a claves en español: nombreRuta, accion, nombreAdmin, fecha, detalles
  Future<RouteHistoryPage> obtenerHistorialRutasAdmin({
    String? routeNameContains,
    String? action, // 'created' | 'edited' | 'deleted'
    DateTimeRange? rango, // por 'date' (EN) o 'fecha' (ES)
    required int limite,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    // 1) Intentar en EN
    var page = await _query(
      col: routesAdminHistoryCollection,
      dateField: 'date',
      routeNameField: 'routeName',
      actionField: 'action',
      adminNameField: 'adminName',
      detailsField: 'details',
      routeNameContains: routeNameContains,
      action: action,
      rango: rango,
      limite: limite,
      startAfter: startAfter,
      mapToEs: true,
    );

    // 2) Fallback a ES si vacío
    if (page.items.isEmpty) {
      page = await _query(
        col: historialRutasAdminCollection,
        dateField: 'fecha',
        routeNameField: 'nombreRuta',
        actionField: 'accion',
        adminNameField: 'nombreAdmin',
        detailsField: 'detalles',
        routeNameContains: routeNameContains,
        action:
            action, // si en ES está en español, tu backend histórico lo guardaba así; si no, igual mostramos
        rango: rango,
        limite: limite,
        startAfter: startAfter,
        mapToEs: false, // ya viene en ES
      );
    }

    return page;
  }

  Future<RouteHistoryPage> _query({
    required String col,
    required String dateField,
    required String routeNameField,
    required String actionField,
    required String adminNameField,
    required String detailsField,
    required String? routeNameContains,
    required String? action,
    required DateTimeRange? rango,
    required int limite,
    required DocumentSnapshot<Map<String, dynamic>>? startAfter,
    required bool mapToEs,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection(col)
        .orderBy(dateField, descending: true)
        .limit(limite);

    if (action != null && action.trim().isNotEmpty) {
      q = q.where(actionField, isEqualTo: action.trim());
    }

    if (rango != null) {
      q = q
          .where(
            dateField,
            isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start),
          )
          .where(dateField, isLessThanOrEqualTo: Timestamp.fromDate(rango.end));
    }

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final docs = snap.docs;

    // Mapeo + filtro "contains" por nombre de ruta en memoria (Firestore no soporta contains)
    final items = <Map<String, dynamic>>[];
    for (final d in docs) {
      final data = d.data();

      // Normalizamos a ES para UI/exports
      final nombreRuta = (data[routeNameField] ?? '').toString();
      final accion = (data[actionField] ?? '').toString();
      final nombreAdmin = (data[adminNameField] ?? '').toString();
      final fechaTs = data[dateField] as Timestamp?;
      final fecha = fechaTs?.toDate();
      final detalles = data[detailsField];

      final normal =
          mapToEs
              ? {
                'id': d.id,
                'nombreRuta': nombreRuta,
                'accion':
                    accion, // viene en EN pero tus exports funcionan igual
                'nombreAdmin': nombreAdmin,
                'fecha': fecha,
                'detalles': detalles, // Map<String, dynamic>?
              }
              : {
                'id': d.id,
                'nombreRuta': nombreRuta,
                'accion': accion,
                'nombreAdmin': nombreAdmin,
                'fecha': fecha,
                'detalles': detalles,
              };

      // Filtro "contiene" (case-insensitive)
      if (routeNameContains != null && routeNameContains.trim().isNotEmpty) {
        final needle = routeNameContains.toLowerCase();
        if (!nombreRuta.toLowerCase().contains(needle)) continue;
      }

      items.add(normal);
    }

    final hasNext = docs.length == limite;
    final lastDoc = docs.isNotEmpty ? docs.last : null;

    return RouteHistoryPage(items: items, hasNext: hasNext, lastDoc: lastDoc);
  }

  /// Conteo total con los mismos filtros.
  /// NOTA: el filtro "contains" se aplica en cliente; aquí contamos por rango/acción.
  Future<int> contarTotal({
    String? action,
    DateTimeRange? rango,
    String? routeNameContains,
  }) async {
    // Intento EN
    final en = await _countIn(
      col: routesAdminHistoryCollection,
      dateField: 'date',
      actionField: 'action',
      action: action,
      rango: rango,
    );

    int total = en ?? 0;

    // Si EN devolvió 0, prueba ES
    if (total == 0) {
      final es = await _countIn(
        col: historialRutasAdminCollection,
        dateField: 'fecha',
        actionField: 'accion',
        action: action,
        rango: rango,
      );
      total = es ?? 0;
    }

    // Ajuste por filtro "contains" de nombre de ruta (aproximado):
    // Si necesitas conteo exacto con "contains", requeriría escanear; por performance
    // lo dejamos así. El listado/export SI respeta el "contains".
    return total;
  }

  Future<int?> _countIn({
    required String col,
    required String dateField,
    required String actionField,
    required String? action,
    required DateTimeRange? rango,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _db.collection(col);

      if (action != null && action.trim().isNotEmpty) {
        q = q.where(actionField, isEqualTo: action.trim());
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
