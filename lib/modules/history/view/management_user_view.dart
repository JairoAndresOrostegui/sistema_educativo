import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../export/utils/user_export_utils.dart';
import '../services/user_history_service.dart';

class GestionUsuariosView extends StatefulWidget {
  const GestionUsuariosView({super.key});

  @override
  State<GestionUsuariosView> createState() => _GestionUsuariosViewState();
}

class _GestionUsuariosViewState extends State<GestionUsuariosView> {
  final _svc = AdminUserHistoryService();

  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _hasNext = false;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  String _query = '';
  String? _rolSel;
  String? _accionSel;
  DateTimeRange? _rango;

  static const int _pageSize = 100;

  Set<String> _roles = {};
  Set<String> _acciones = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _items.clear();
      _hasNext = false;
      _lastDoc = null;
    });

    final page = await _svc.obtenerHistorial(
      nameContains: null,
      role: _rolSel,
      action: _accionSel,
      rango: _rango,
      limite: _pageSize,
      startAfter: null,
    );

    setState(() {
      _items.addAll(page.items);
      _hasNext = page.hasNext;
      _lastDoc = page.lastDoc;
      _loading = false;
      _rebuildFiltersSourcesAndSanitizeSelection();
    });
  }

  Future<void> _loadMore() async {
    if (!_hasNext || _loading) return;
    setState(() => _loading = true);

    final page = await _svc.obtenerHistorial(
      nameContains: null,
      role: _rolSel,
      action: _accionSel,
      rango: _rango,
      limite: _pageSize,
      startAfter: _lastDoc,
    );

    setState(() {
      _items.addAll(page.items);
      _hasNext = page.hasNext;
      _lastDoc = page.lastDoc;
      _loading = false;
      _rebuildFiltersSourcesAndSanitizeSelection();
    });
  }

  void _rebuildFiltersSourcesAndSanitizeSelection() {
    _roles = {for (final m in _items) (m['rol'] ?? '').toString()}
      ..removeWhere((e) => e.isEmpty);
    _acciones = {for (final m in _items) (m['accion'] ?? '').toString()}
      ..removeWhere((e) => e.isEmpty);
    if (_rolSel != null && !_roles.contains(_rolSel)) _rolSel = null;
    if (_accionSel != null && !_acciones.contains(_accionSel))
      _accionSel = null;
  }

  String _norm(String s) {
    const rep = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'Á': 'a',
      'É': 'e',
      'Í': 'i',
      'Ó': 'o',
      'Ú': 'u',
      'ñ': 'n',
      'Ñ': 'n',
    };
    final t = s.trim();
    final sb = StringBuffer();
    for (final r in t.runes) {
      final ch = String.fromCharCode(r);
      sb.write(rep[ch] ?? ch);
    }
    return sb.toString().toLowerCase();
  }

  String _rangeLabel(DateTimeRange? r) {
    if (r == null) return 'Rango de fechas';
    final f = DateFormat('yyyy-MM-dd');
    return '${f.format(r.start)} → ${f.format(r.end)}';
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final ini =
        _rango?.start ??
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 7));
    final end = _rango?.end ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: ini, end: end),
    );
    if (picked != null) {
      setState(() => _rango = picked);
      await _reload();
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

    // MISMO FORMATO VISUAL DE FECHAS QUE "Documentos"
    final df = DateFormat('yyyy-MM-dd');
    final rangoTexto =
        _rango == null
            ? ''
            : '${df.format(_rango!.start)}  →  ${df.format(_rango!.end)}';

    final needle = _norm(_query);
    final filtered =
        _items.where((u) {
          if (_rolSel != null && _rolSel!.isNotEmpty) {
            if ((u['rol'] ?? '') != _rolSel) return false;
          }
          if (_accionSel != null && _accionSel!.isNotEmpty) {
            if ((u['accion'] ?? '') != _accionSel) return false;
          }
          if (needle.isNotEmpty) {
            final haystack = _norm(
              '${(u["nombres"] ?? "")} '
              '${(u["apellidos"] ?? "")} '
              '${(u["rol"] ?? "")} '
              '${(u["accion"] ?? "")} '
              '${(u["realizadoPor"] ?? "")}',
            );
            if (!haystack.contains(needle)) return false;
          }
          return true;
        }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.red.withOpacity(.15)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Total de registros de usuario',
                        child: Text('Total registros: ${_items.length}'),
                      ),
                    ),
                    Text(
                      'Mostrando: ${filtered.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText:
                            'Buscar (nombre, apellido, rol, acción, autor)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      value: _rolSel,
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos los roles'),
                        ),
                        ..._roles.map(
                          (r) => DropdownMenuItem<String?>(
                            value: r,
                            child: Text(r),
                          ),
                        ),
                      ],
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _rolSel = v),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      value: _accionSel,
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todas las acciones'),
                        ),
                        ..._acciones.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a,
                            child: Text(a),
                          ),
                        ),
                      ],
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Acción',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _accionSel = v),
                    ),
                  ),

                  // ⬇️ Igual que "Documentos": TextFormField readonly para el rango
                  SizedBox(
                    width: 280,
                    child: TextFormField(
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Rango de fechas',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: rangoTexto),
                      onTap: _pickRange,
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Aplicar filtros'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _query = '';
                        _rolSel = null;
                        _accionSel = null;
                        _rango = null;
                      });
                      _reload();
                    },
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (kIsWeb && filtered.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => UserHistoryUtils.exportarExcel(filtered),
                      icon: const Icon(Icons.table_view),
                      label: const Text('Exportar Excel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => UserHistoryUtils.exportarPDF(filtered),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Exportar PDF'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child:
                    _loading && _items.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                        ? const Center(child: Text('No hay registros'))
                        : ListView.builder(
                          itemCount: filtered.length + (_hasNext ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (_hasNext && i == filtered.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Center(
                                  child:
                                      _loading
                                          ? const CircularProgressIndicator()
                                          : OutlinedButton.icon(
                                            onPressed: _loadMore,
                                            icon: const Icon(Icons.expand_more),
                                            label: const Text('Cargar más'),
                                          ),
                                ),
                              );
                            }

                            final r = filtered[i];
                            final fecha = r['fecha'] as DateTime?;
                            final fechaTexto =
                                fecha != null
                                    ? DateFormat(
                                      'yyyy-MM-dd HH:mm:ss',
                                    ).format(fecha)
                                    : '-';

                            final titulo =
                                '${(r['nombres'] ?? '')} ${(r['apellidos'] ?? '')} - ${(r['accion'] ?? '')}';

                            final subtitulo = [
                              'Rol: ${(r['rol'] ?? '')}',
                              'Realizado por: ${(r['realizadoPor'] ?? '')}',
                              'Fecha: $fechaTexto',
                            ].join('\n');

                            return Semantics(
                              label: 'Registro de log de usuario',
                              child: Card(
                                color: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: Colors.red.withOpacity(.12),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  title: Text(titulo),
                                  subtitle: Text(subtitulo),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
