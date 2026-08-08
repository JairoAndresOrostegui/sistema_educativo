import 'package:sistema_educativo/config/app_palette.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/file_history_service.dart';
import '../export/utils/file_export_utils.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../models/academic/academic_group.dart';

class GestionDocumentosView extends StatefulWidget {
  const GestionDocumentosView({super.key});

  @override
  State<GestionDocumentosView> createState() => _GestionDocumentosViewState();
}

class _GestionDocumentosViewState extends State<GestionDocumentosView> {
  // Servicio
  final _service = DocumentHistoryService();

  // Tenant (desde Provider)
  String? _institutionId;
  String? _campusId;

  // Estado filtros
  String? _groupSelected;
  DateTimeRange? _rango; // filtro por rango de fechas
  bool _filtrosPendientes = false;

  // Datos
  final int _porPagina = 20;
  bool _cargando = false;
  List<Map<String, dynamic>> _documentos = [];
  int _totalEnRango = 0;

  // Paginación por cursores
  final List<DocumentSnapshot<Map<String, dynamic>>?> _cursors = [null];
  int _pageIndex = 0;
  bool _hasNext = false;

  // Grados para el dropdown
  List<AcademicGroup> _groups = [];

  @override
  void initState() {
    super.initState();

    // Leer tenant del Provider (sin auth)
    final user = context.read<UserProviderV2>().user;
    _institutionId = user?.institution;
    _campusId = user?.campus;

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

    // Si no hay usuario/tenant aún, no seguimos (evita consultar sin filtros obligatorios)
    if (_institutionId == null || _campusId == null) return;

    _cargarGrupos();
    _aplicarFiltros(recargar: true);
  }

  Future<void> _cargarGrupos() async {
    if (_institutionId == null || _campusId == null) return;
    final list = await _service.obtenerGrupos(
      institutionId: _institutionId!,
      campusId: _campusId!,
    );
    if (!mounted) return;
    setState(() => _groups = list);
  }

  Future<void> _aplicarFiltros({bool recargar = false}) async {
    if (_institutionId == null || _campusId == null) return;

    setState(() => _cargando = true);

    if (recargar) {
      _cursors
        ..clear()
        ..add(null);
      _pageIndex = 0;
    }

    final res = await _service.obtenerHistorialDocumentos(
      institutionId: _institutionId!,
      campusId: _campusId!,
      groupId: _groupSelected,
      rango: _rango,
      limite: _porPagina,
      startAfter: _cursors[_pageIndex],
    );

    final total = await _service.contarTotalDocumentos(
      institutionId: _institutionId!,
      campusId: _campusId!,
      groupId: _groupSelected,
      rango: _rango,
    );

    if (!mounted) return;
    setState(() {
      _documentos = res.items;
      _hasNext = res.hasNext;
      if (res.lastDoc != null) {
        if (_cursors.length == _pageIndex + 1) {
          _cursors.add(res.lastDoc);
        } else {
          _cursors[_pageIndex + 1] = res.lastDoc;
        }
      }
      _totalEnRango = total;
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
    if (kIsWeb && _documentos.isNotEmpty) {
      DocumentHistoryUtils.exportarExcel(_documentos);
    }
  }

  Future<void> _exportarPDF() async {
    if (_filtrosPendientes) {
      await _aplicarFiltros(recargar: true);
    }
    if (kIsWeb && _documentos.isNotEmpty) {
      DocumentHistoryUtils.exportarPDF(_documentos);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        body: SafeArea(
          child: Center(child: Text('Disponible solo en la version web.')),
        ),
      );
    }
    final df = DateFormat('yyyy-MM-dd');
    final rangoTexto = _rango == null
        ? ''
        : '${df.format(_rango!.start)}  -  ${df.format(_rango!.end)}';

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
                  label: 'Total de documentos en el rango seleccionado',
                  child: Text('Total en rango: $_totalEnRango'),
                ),
              ),
              SizedBox(height: 16),

              // Filtros
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _groupSelected,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos los grupos'),
                        ),
                        ..._groups.map(
                          (group) => DropdownMenuItem<String?>(
                            value: group.id,
                            child: Text(group.name),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _groupSelected = v;
                          _filtrosPendientes = true;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Grupo',
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
                        _groupSelected = null;
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
              SizedBox(height: 16),

              // Exportar (solo Web)
              if (kIsWeb && _documentos.isNotEmpty)
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
              if (kIsWeb && _documentos.isNotEmpty) SizedBox(height: 12),

              // Lista
              Expanded(
                child: _cargando
                    ? Center(child: CircularProgressIndicator())
                    : _documentos.isEmpty
                    ? Center(child: Text('No hay registros'))
                    : ListView.builder(
                        itemCount: _documentos.length,
                        itemBuilder: (_, i) {
                          final r = _documentos[i];
                          final fecha = r['fechaSubida'] as DateTime?;
                          final fechaTexto = fecha != null
                              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
                              : '-';
                          return Semantics(
                            label: 'Registro de documento subido',
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
                                title: Text('📄 ${r['nombre'] ?? ''}'),
                                subtitle: Text(
                                  'Grupo: ${r['grupo'] ?? ''}\n'
                                  'Subido por: ${r['subidoPor'] ?? ''}\n'
                                  'Fecha: $fechaTexto',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Paginación
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
