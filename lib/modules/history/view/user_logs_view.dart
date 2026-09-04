import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/user_logs_service.dart';
import '../export/utils/user_logs_export_utils.dart';

class GestionLogsUsuariosView extends StatefulWidget {
  const GestionLogsUsuariosView({super.key});

  @override
  State<GestionLogsUsuariosView> createState() =>
      _GestionLogsUsuariosViewState();
}

class _GestionLogsUsuariosViewState extends State<GestionLogsUsuariosView> {
  final _service = UserLogsService();

  String? _role;
  String _groupEquals = ''; // local (igual)
  String _nameContains = ''; // local (contiene)
  DateTimeRange? _rango;

  bool _cargando = false;
  int _total = 0;
  final int _porPagina = 20;
  List<Map<String, dynamic>> _items = [];

  final List<dynamic> _cursors = [null];
  int _pageIndex = 0;
  bool _hasNext = false;

  bool _filtrosPendientes = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rango = DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 14)),
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

    final page = await _service.getLogs(
      role: _role,
      event: null,
      campus: null,
      institution: null,
      platform: null,
      nameContains: _nameContains.trim().isEmpty ? null : _nameContains.trim(),
      rango: _rango,
      limit: _porPagina,
      startAfter: _cursors[_pageIndex],
    );

    final total = await _service.countLogs(
      role: _role,
      event: null,
      campus: null,
      institution: null,
      rango: _rango,
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
          ).subtract(Duration(days: 14)),
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
      UserLogsExportUtils.exportarExcel(_filtradoLocal(_items));
    }
  }

  Future<void> _exportarPDF() async {
    if (_filtrosPendientes) {
      await _aplicarFiltros(recargar: true);
    }
    if (_items.isNotEmpty) {
      await UserLogsExportUtils.exportarPDF(_filtradoLocal(_items));
    }
  }

  List<Map<String, dynamic>> _filtradoLocal(List<Map<String, dynamic>> base) {
    return base.where((r) {
      if (_groupEquals.trim().isNotEmpty) {
        if ((r['groupName'] ?? '').toString().trim() != _groupEquals.trim()) {
          return false;
        }
      }
      return true;
    }).toList();
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

    final itemsFiltradosLocal = _filtradoLocal(_items);

    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumen
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
                  label: 'Total de logs en el rango/criterios',
                  child: Text('Total logs: $_total'),
                ),
              ),
              SizedBox(height: 16),

              // Filtros
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _role,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Todos los roles'),
                        ),
                        DropdownMenuItem(
                          value: 'Administrador',
                          child: Text('Administrador'),
                        ),
                        DropdownMenuItem(
                          value: 'Docente',
                          child: Text('Docente'),
                        ),
                        DropdownMenuItem(
                          value: 'Familiar',
                          child: Text('Familiar'),
                        ),
                        DropdownMenuItem(
                          value: 'Estudiante',
                          child: Text('Estudiante'),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _role = v;
                        _filtrosPendientes = true;
                      }),
                      decoration: InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Nombre (contiene, local)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() {
                        _nameContains = v;
                        _filtrosPendientes = true;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Grupo (igual, local)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() {
                        _groupEquals = v;
                        _filtrosPendientes = true;
                      }),
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
                        _role = null;
                        _groupEquals = '';
                        _nameContains = '';
                        _rango = DateTimeRange(
                          start: DateTime(
                            now.year,
                            now.month,
                            now.day,
                          ).subtract(Duration(days: 14)),
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
              SizedBox(height: 16),

              // Exportar (solo Web)
              if (kIsWeb && itemsFiltradosLocal.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _exportarExcel,
                      icon: Icon(Icons.table_view),
                      label: Text('Exportar Excel'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _exportarPDF,
                      icon: Icon(Icons.picture_as_pdf),
                      label: Text('Exportar PDF'),
                    ),
                  ],
                ),
              if (kIsWeb && itemsFiltradosLocal.isNotEmpty)
                SizedBox(height: 12),

              // Lista
              Expanded(
                child: _cargando
                    ? Center(child: CircularProgressIndicator())
                    : itemsFiltradosLocal.isEmpty
                    ? Center(child: Text('No hay registros'))
                    : ListView.builder(
                        itemCount: itemsFiltradosLocal.length,
                        itemBuilder: (_, i) {
                          final r = itemsFiltradosLocal[i];

                          final fecha = r['timestamp'] as DateTime?;
                          final fechaTexto = fecha != null
                              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
                              : '-';

                          final nombre = (r['fullName'] ?? '').toString();
                          final rol = (r['role'] ?? '').toString();
                          final evento = (r['event'] ?? '').toString();
                          final campus = (r['campus'] ?? '').toString();
                          final inst = (r['institution'] ?? '').toString();
                          final grupo = (r['groupName'] ?? '').toString();

                          final header = '$nombre — $evento';
                          final sub = [
                            'Rol: $rol',
                            if (grupo.isNotEmpty) 'Grupo: $grupo',
                            if (campus.isNotEmpty) 'Campus: $campus',
                            if (inst.isNotEmpty) 'Institución: $inst',
                            'Fecha: $fechaTexto',
                          ].join('\n');

                          return Semantics(
                            label: 'Log de usuario',
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
                              child: ListTile(
                                title: Text('👤 $header'),
                                subtitle: Text(sub),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Página ${_pageIndex + 1}'),
                  Row(
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
}
