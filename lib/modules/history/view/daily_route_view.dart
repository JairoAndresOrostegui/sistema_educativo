// Archivo: screens/admin_history/view/daily_route_view.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // ⬅️ NUEVO
import '../../../providers/user_provider_v2.dart'; // ⬅️ NUEVO

import '../services/daily_route_history_service.dart';
import '../export/utils/daily_route_export_utils.dart';
import '../../../utils/format_utils.dart';

class RutasDiariasView extends StatefulWidget {
  const RutasDiariasView({super.key});

  @override
  State<RutasDiariasView> createState() => _RutasDiariasViewState();
}

class _RutasDiariasViewState extends State<RutasDiariasView> {
  final TextEditingController _nombreCtrl = TextEditingController();

  String? _estadoSeleccionado; // 'pendiente' | 'activa' | 'finalizada'
  DateTimeRange? _rango; // filtro por rango de fechas

  final int _porPagina = 20;
  bool _cargando = false;
  bool _filtrosPendientes = false; // si cambió algo y aún no se aplicó

  List<Map<String, dynamic>> _rutas = [];
  int _totalFinalizadas = 0;

  // Paginación por cursores
  final List<DocumentSnapshot<Map<String, dynamic>>?> _cursors = [null];
  int _pageIndex = 0;
  bool _hasNext = false;

  // ⬇️ NUEVO: guardamos una sola vez los filtros obligatorios
  String? _institutionId;
  String? _campusId;

  @override
  void initState() {
    super.initState();

    // ⬇️ NUEVO: leemos del Provider una sola vez
    final u = context.read<UserProviderV2>().user;
    _institutionId = u?.institution;
    _campusId = u?.campus;

    // rango por defecto: últimos 7 días
    final now = DateTime.now();
    _rango = DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
    );

    _aplicarFiltros(recargar: true);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _aplicarFiltros({bool recargar = false}) async {
    setState(() => _cargando = true);

    // ⬇️ NUEVO: si faltan filtros obligatorios, salimos sin romper el flujo
    if (_institutionId == null || _campusId == null) {
      setState(() {
        _cargando = false;
        _filtrosPendientes = false;
      });
      return;
    }

    if (recargar) {
      _cursors
        ..clear()
        ..add(null);
      _pageIndex = 0;
    }

    final service = RutaHistoryService();

    final res = await service.obtenerHistorialRutas(
      institutionId: _institutionId!, // ⬅️ NUEVO (obligatorio)
      campusId: _campusId!, // ⬅️ NUEVO (obligatorio)
      nombreRuta:
          _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
      estado: _estadoSeleccionado,
      rango: _rango,
      limite: _porPagina,
      startAfter: _cursors[_pageIndex],
    );

    final totalFin = await service.contarRutasFinalizadas(
      institutionId: _institutionId!, // ⬅️ NUEVO (obligatorio)
      campusId: _campusId!, // ⬅️ NUEVO (obligatorio)
      rango: _rango,
      nombreRuta:
          _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
    );

    setState(() {
      _rutas = res.items;
      _hasNext = res.hasNext;
      if (res.lastDoc != null) {
        if (_cursors.length == _pageIndex + 1) {
          _cursors.add(res.lastDoc);
        } else {
          _cursors[_pageIndex + 1] = res.lastDoc;
        }
      }
      _totalFinalizadas = totalFin;
      _cargando = false;
      _filtrosPendientes = false;
    });
  }

  Future<void> _siguientePagina() async {
    if (!_hasNext) return;
    setState(() {
      _pageIndex += 1;
      _cargando = true;
    });
    await _aplicarFiltros(recargar: false);
  }

  Future<void> _paginaAnterior() async {
    if (_pageIndex == 0) return;
    setState(() {
      _pageIndex -= 1;
      _cargando = true;
    });
    await _aplicarFiltros(recargar: false);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial =
        _rango ??
        DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
      initialDateRange: initial,
      helpText: 'Rango de fechas',
      saveText: 'Aplicar',
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(
                ctx,
              ).colorScheme.copyWith(primary: Colors.redAccent),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      setState(() {
        // normalizamos: start al 00:00 y end al 23:59:59
        final start = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        );
        final end = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
          999,
        );
        _rango = DateTimeRange(start: start, end: end);
        _filtrosPendientes = true;
      });
    }
  }

  Future<void> _exportarExcel() async {
    if (_filtrosPendientes) {
      await _aplicarFiltros(recargar: true);
    }
    if (kIsWeb && _rutas.isNotEmpty) {
      DailyRouteExportUtils.exportarExcel(_rutas);
    }
  }

  Future<void> _exportarPDF() async {
    if (_filtrosPendientes) {
      await _aplicarFiltros(recargar: true);
    }
    if (kIsWeb && _rutas.isNotEmpty) {
      DailyRouteExportUtils.exportarPDF(_rutas);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('Disponible solo en la versión web.')),
        ),
      );
    }
    final df = DateFormat('yyyy-MM-dd');
    final rangoTexto =
        _rango == null
            ? ''
            : '${df.format(_rango!.start)}  →  ${df.format(_rango!.end)}';

    return Semantics(
      label: 'Historial de rutas diarias',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.red.withValues(alpha: .15)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text('Total finalizadas (rango): $_totalFinalizadas'),
          ),
          const SizedBox(height: 16),

          // Filtros
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la ruta',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _filtrosPendientes = true,
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _estadoSeleccionado,
                  items: const [
                    DropdownMenuItem(
                      value: 'pendiente',
                      child: Text('pendiente'),
                    ),
                    DropdownMenuItem(value: 'activa', child: Text('activa')),
                    DropdownMenuItem(
                      value: 'finalizada',
                      child: Text('finalizada'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _estadoSeleccionado = v;
                      _filtrosPendientes = true;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextFormField(
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Rango de fechas',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: rangoTexto),
                  onTap: _pickDateRange,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.filter_alt),
                onPressed: () => _aplicarFiltros(recargar: true),
                label: const Text('Filtrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _nombreCtrl.clear();
                    _estadoSeleccionado = null;
                    final now = DateTime.now();
                    _rango = DateTimeRange(
                      start: DateTime(
                        now.year,
                        now.month,
                        now.day,
                      ).subtract(const Duration(days: 6)),
                      end: DateTime(
                        now.year,
                        now.month,
                        now.day,
                        23,
                        59,
                        59,
                        999,
                      ),
                    );
                    _filtrosPendientes = true;
                  });
                  _aplicarFiltros(recargar: true);
                },
                child: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Exportar (solo Web)
          if (kIsWeb && _rutas.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _exportarExcel,
                  icon: const Icon(Icons.table_view),
                  label: const Text('Exportar Excel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _exportarPDF,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Exportar PDF'),
                ),
              ],
            ),
          if (kIsWeb && _rutas.isNotEmpty) const SizedBox(height: 12),

          // Lista
          Expanded(
            child:
                _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _rutas.isEmpty
                    ? const Center(child: Text('Sin resultados.'))
                    : ListView.builder(
                      itemCount: _rutas.length,
                      itemBuilder: (_, i) => _buildRutaItem(_rutas[i]),
                    ),
          ),

          // Paginación
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Página ${_pageIndex + 1}'),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        _pageIndex == 0 || _cargando ? null : _paginaAnterior,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: !_hasNext || _cargando ? null : _siguientePagina,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRutaItem(Map<String, dynamic> ruta) {
    final estudiantes = List<Map<String, dynamic>>.from(
      ruta['estudiantes'] ?? [],
    );
    final fecha = (ruta['fecha'] as Timestamp).toDate();
    final inicioTs = ruta['horaInicio'];
    final finTs = ruta['horaFin'];
    final inicio = inicioTs is Timestamp ? inicioTs.toDate() : null;
    final fin = finTs is Timestamp ? finTs.toDate() : null;
    final duracion =
        (inicio != null && fin != null) ? fin.difference(inicio).inMinutes : 0;
    final estado = (ruta['estado'] ?? '').toString();

    return Semantics(
      label:
          'Ruta ${ruta['nombreRuta']} realizada el ${FormatUtils.formatoFechaHora(fecha)} '
          'por ${ruta['gestionadaPorNombre']} estado $estado',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.withValues(alpha: .15)),
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          title: Text(
            ruta['nombreRuta'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Por: ${ruta['gestionadaPorNombre']} • ${FormatUtils.formatoFechaHora(fecha)}\n'
            'Estado: $estado • Duración: $duracion min',
          ),
          children:
              estudiantes.map((est) {
                final recogido = est['recogido'] == true ? 'Si' : 'No';
                final anulado = est['anulado'] == true ? 'Si' : 'No';
                final activo = est['activo'] == true ? 'Si' : 'No';
                final hora =
                    est['horaRecogida'] != null
                        ? FormatUtils.formatoHora(
                          (est['horaRecogida'] as Timestamp).toDate(),
                        )
                        : '-';
                final avisos = est['avisosEnviados'] ?? 0;

                return ListTile(
                  dense: true,
                  title: Text(est['nombre'] ?? ''),
                  subtitle: Text(
                    'Dirección: ${est['direccion'] ?? ''}\nHora: $hora\nAvisos enviados: $avisos\nRecogido: $recogido\nAnulado: $anulado\nEn ruta: $activo',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}
