import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/route_history_service.dart';
import '../export/utils/route_export_utils.dart';

class GestionRutasView extends StatefulWidget {
  const GestionRutasView({super.key});

  @override
  State<GestionRutasView> createState() => _GestionRutasViewState();
}

class _GestionRutasViewState extends State<GestionRutasView> {
  final _service = AdminRouteHistoryService();

  // Filtros
  String _nombreContiene = '';
  String? _accion; // 'created'|'edited'|'deleted' (o null = todas)
  DateTimeRange? _rango;
  bool _filtrosPendientes = false;

  // Datos
  final int _porPagina = 20;
  bool _cargando = true;
  List<Map<String, dynamic>> _items = [];
  int _total = 0;

  // Paginación por cursor
  final List<dynamic> _cursors = [null];
  int _pageIndex = 0;
  bool _hasNext = false;

  @override
  void initState() {
    super.initState();
    // Rango por defecto: últimos 30 días
    final now = DateTime.now();
    _rango = DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 29)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
    );
    _aplicarFiltros(recargar: true);
  }

  Future<void> _aplicarFiltros({bool recargar = false}) async {
    setState(() => _cargando = true);

    if (recargar) {
      _cursors
        ..clear()
        ..add(null);
      _pageIndex = 0;
    }

    final page = await _service.obtenerHistorialRutasAdmin(
      routeNameContains: _nombreContiene.trim().isEmpty
          ? null
          : _nombreContiene.trim(),
      action: _accion,
      rango: _rango,
      limite: _porPagina,
      startAfter: _cursors[_pageIndex],
    );

    final total = await _service.contarTotal(
      action: _accion,
      rango: _rango,
      routeNameContains: _nombreContiene.trim().isEmpty
          ? null
          : _nombreContiene.trim(),
    );

    setState(() {
      _items = page.items;
      _hasNext = page.hasNext;
      if (page.lastDoc != null) {
        if (_cursors.length == _pageIndex + 1) {
          _cursors.add(page.lastDoc);
        } else {
          _cursors[_pageIndex + 1] = page.lastDoc;
        }
      }
      _total = total;
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
          ).subtract(Duration(days: 29)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
      initialDateRange: initial,
      helpText: 'Rango de fechas',
      saveText: 'Aplicar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: AppPalette.primary),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
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
    if (kIsWeb && _items.isNotEmpty) {
      AdminRouteLogUtils.exportarExcel(_items);
    }
  }

  Future<void> _exportarPDF() async {
    if (_filtrosPendientes) {
      await _aplicarFiltros(recargar: true);
    }
    if (kIsWeb && _items.isNotEmpty) {
      AdminRouteLogUtils.exportarPDF(_items);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        body: SafeArea(
          child: Center(child: Text('Disponible solo en la versión web.')),
        ),
      );
    }
    final df = DateFormat('yyyy-MM-dd');
    final rangoTexto = _rango == null
        ? ''
        : '${df.format(_rango!.start)}  →  ${df.format(_rango!.end)}';

    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumen superior
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  border: Border.all(
                    color: AppPalette.error.withValues(alpha: .15),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.onSurface.withValues(alpha: .03),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Semantics(
                  label: 'Total de registros en el rango/criterios',
                  child: Text('Total registros: $_total'),
                ),
              ),
              SizedBox(height: 16),

              // Filtros
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Nombre de la ruta (contiene)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _nombreContiene,
                      onChanged: (v) {
                        setState(() {
                          _nombreContiene = v;
                          _filtrosPendientes = true;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _accion,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Todas las acciones'),
                        ),
                        DropdownMenuItem(
                          value: 'created',
                          child: Text('Creada'),
                        ),
                        DropdownMenuItem(
                          value: 'edited',
                          child: Text('Editada'),
                        ),
                        DropdownMenuItem(
                          value: 'deleted',
                          child: Text('Eliminada'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _accion = v;
                          _filtrosPendientes = true;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Acción',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Rango de fechas',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: rangoTexto),
                      onTap: _pickDateRange,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.filter_alt),
                    onPressed: () => _aplicarFiltros(recargar: true),
                    label: Text('Filtrar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: AppPalette.surface,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        _nombreContiene = '';
                        _accion = null;
                        _rango = DateTimeRange(
                          start: DateTime(
                            now.year,
                            now.month,
                            now.day,
                          ).subtract(Duration(days: 29)),
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
                    child: Text('Limpiar'),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Exportar (solo Web)
              if (kIsWeb && _items.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _exportarExcel,
                        icon: Icon(Icons.table_view),
                        label: Text('Exportar Excel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _exportarPDF,
                        icon: Icon(Icons.picture_as_pdf),
                        label: Text('Exportar PDF'),
                      ),
                    ],
                  ),
                ),
              if (kIsWeb && _items.isNotEmpty) SizedBox(height: 12),

              // Lista
              Expanded(
                child: _cargando
                    ? Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                    ? Center(child: Text('No hay registros'))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final r = _items[i];
                          final fecha = r['fecha'] as DateTime?;
                          final fechaTexto = fecha != null
                              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
                              : '-';
                          final detalles =
                              r['detalles']; // Map<String, dynamic>?

                          return Semantics(
                            label: 'Registro de log de rutas',
                            child: Card(
                              color: AppPalette.surface,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: AppPalette.error.withValues(
                                    alpha: .12,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                childrenPadding: EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                title: Text(
                                  '${r['nombreRuta'] ?? ''} — ${_labelAccion(r['accion'])}',
                                ),
                                subtitle: Text(
                                  'Por: ${r['nombreAdmin'] ?? ''} • $fechaTexto',
                                ),
                                children: [
                                  if (detalles is Map<String, dynamic> &&
                                      detalles.isNotEmpty)
                                    _DetallesList(detalles: detalles),
                                  if (detalles == null ||
                                      (detalles is Map && detalles.isEmpty))
                                    Text('Sin detalles de cambios.'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Paginación
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Página ${_pageIndex + 1}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left),
                        onPressed: _pageIndex == 0 || _cargando
                            ? null
                            : _paginaAnterior,
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right),
                        onPressed: !_hasNext || _cargando
                            ? null
                            : _siguientePagina,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _labelAccion(String? action) {
    switch (action) {
      case 'created':
        return 'Creada';
      case 'edited':
        return 'Editada';
      case 'deleted':
        return 'Eliminada';
      default:
        return (action ?? '').isEmpty ? 'Acción' : action!;
    }
  }
}

class _DetallesList extends StatelessWidget {
  final Map<String, dynamic> detalles;
  const _DetallesList({required this.detalles});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        body: SafeArea(
          child: Center(child: Text('Disponible solo en la versión web.')),
        ),
      );
    }
    final keys = detalles.keys.toList()..sort();
    if (keys.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: keys.map((k) {
        final v = detalles[k];
        return Padding(
          padding: EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$k: ', style: TextStyle(fontWeight: FontWeight.w700)),
              Expanded(
                child: Text(
                  v is String ? v : v?.toString() ?? '',
                  softWrap: true,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
