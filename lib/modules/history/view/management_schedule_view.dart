import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/schedule_history_service.dart';
import '../export/utils/schedule_export_utils.dart';

class GestionHorariosView extends StatefulWidget {
  const GestionHorariosView({super.key});

  @override
  State<GestionHorariosView> createState() => _GestionHorariosViewState();
}

class _GestionHorariosViewState extends State<GestionHorariosView> {
  final _service = AdminScheduleHistoryService();

  // Filtros
  String _gradoContiene = '';
  String _materiaContiene = '';
  String? _dia; // lunes..domingo
  String? _accion; // create_subject|update_subject|delete_subject
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
    final now = DateTime.now();
    _rango = DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 29)),
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

    final page = await _service.obtenerHistorialHorarios(
      gradeContains:
          _gradoContiene.trim().isEmpty ? null : _gradoContiene.trim(),
      subjectContains:
          _materiaContiene.trim().isEmpty ? null : _materiaContiene.trim(),
      day: _dia?.toLowerCase(),
      action: _accion,
      rango: _rango,
      limite: _porPagina,
      startAfter: _cursors[_pageIndex],
    );

    final total = await _service.contarTotal(
      action: _accion,
      day: _dia?.toLowerCase(),
      rango: _rango,
      gradeContains:
          _gradoContiene.trim().isEmpty ? null : _gradoContiene.trim(),
      subjectContains:
          _materiaContiene.trim().isEmpty ? null : _materiaContiene.trim(),
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
          ).subtract(const Duration(days: 29)),
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
      ScheduleHistoryUtils.exportarExcel(_items);
    }
  }

  Future<void> _exportarPDF() async {
    if (_filtrosPendientes) {
      await _aplicarFiltros(recargar: true);
    }
    if (kIsWeb && _items.isNotEmpty) {
      ScheduleHistoryUtils.exportarPDF(_items);
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumen superior
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                child: Semantics(
                  label: 'Total de registros en el rango/criterios',
                  child: Text('Total registros: $_total'),
                ),
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
                      decoration: const InputDecoration(
                        labelText: 'Grado (contiene)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _gradoContiene,
                      onChanged: (v) {
                        setState(() {
                          _gradoContiene = v;
                          _filtrosPendientes = true;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Materia (contiene)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _materiaContiene,
                      onChanged: (v) {
                        setState(() {
                          _materiaContiene = v;
                          _filtrosPendientes = true;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _dia,
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Todos los días'),
                        ),
                        DropdownMenuItem(value: 'lunes', child: Text('Lunes')),
                        DropdownMenuItem(
                          value: 'martes',
                          child: Text('Martes'),
                        ),
                        DropdownMenuItem(
                          value: 'miércoles',
                          child: Text('Miércoles'),
                        ),
                        DropdownMenuItem(
                          value: 'jueves',
                          child: Text('Jueves'),
                        ),
                        DropdownMenuItem(
                          value: 'viernes',
                          child: Text('Viernes'),
                        ),
                        DropdownMenuItem(
                          value: 'sábado',
                          child: Text('Sábado'),
                        ),
                        DropdownMenuItem(
                          value: 'domingo',
                          child: Text('Domingo'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _dia = v;
                          _filtrosPendientes = true;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Día',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _accion,
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Todas las acciones'),
                        ),
                        DropdownMenuItem(
                          value: 'create_subject',
                          child: Text('Crear materia'),
                        ),
                        DropdownMenuItem(
                          value: 'update_subject',
                          child: Text('Editar materia'),
                        ),
                        DropdownMenuItem(
                          value: 'delete_subject',
                          child: Text('Eliminar materia'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _accion = v;
                          _filtrosPendientes = true;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Acción',
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
                      final now = DateTime.now();
                      setState(() {
                        _gradoContiene = '';
                        _materiaContiene = '';
                        _dia = null;
                        _accion = null;
                        _rango = DateTimeRange(
                          start: DateTime(
                            now.year,
                            now.month,
                            now.day,
                          ).subtract(const Duration(days: 29)),
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

              const SizedBox(height: 12),

              // Exportar (Web)
              if (kIsWeb && _items.isNotEmpty)
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
              if (kIsWeb && _items.isNotEmpty) const SizedBox(height: 12),

              // Lista
              Expanded(
                child:
                    _cargando
                        ? const Center(child: CircularProgressIndicator())
                        : _items.isEmpty
                        ? const Center(child: Text('No hay registros'))
                        : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final r = _items[i];
                            final fecha = r['fecha'] as DateTime?;
                            final fechaTexto =
                                fecha != null
                                    ? DateFormat(
                                      'yyyy-MM-dd HH:mm:ss',
                                    ).format(fecha)
                                    : '-';
                            final mensaje = (r['mensaje'] ?? '') as String;

                            return Semantics(
                              label: 'Registro de log de horarios',
                              child: Card(
                                color: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: Colors.red.withValues(alpha: .12),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  title: Text(
                                    '${r['grado'] ?? ''} — ${r['accion'] ?? ''}',
                                  ),
                                  subtitle: Text(
                                    'Materia: ${r['materia'] ?? ''}\n'
                                    'Día: ${r['dia'] ?? ''}\n'
                                    'Usuario: ${r['usuarioNombre'] ?? ''}\n'
                                    'Fecha: $fechaTexto${mensaje.isNotEmpty ? '\n$mensaje' : ''}',
                                  ),
                                ),
                              ),
                            );
                          },
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
                            _pageIndex == 0 || _cargando
                                ? null
                                : _paginaAnterior,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed:
                            !_hasNext || _cargando ? null : _siguientePagina,
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
