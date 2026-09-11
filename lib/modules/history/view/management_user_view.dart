import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../export/utils/user_export_utils.dart';
import '../services/user_history_service.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/user_facing_error.dart';
import '../../../providers/user_provider_v2.dart';
import '../widgets/history_date_range_field.dart';

class GestionUsuariosView extends StatefulWidget {
  const GestionUsuariosView({super.key});

  @override
  State<GestionUsuariosView> createState() => _GestionUsuariosViewState();
}

class _GestionUsuariosViewState extends State<GestionUsuariosView> {
  final _svc = AdminUserHistoryService();
  final _searchController = TextEditingController();
  late final String _institutionId;
  late final String _campusId;

  final List<Map<String, dynamic>> _items = [];
  int _total = 0;
  bool _loading = false;
  bool _hasNext = false;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  String _query = '';
  String? _rolSel;
  String? _accionSel;
  DateTimeRange? _rango;

  static final int _pageSize = 100;

  static const _roles = <String>{
    'Administrador',
    'Docente',
    'Auxiliar',
    'Familiar',
    'Estudiante',
  };
  static const _acciones = <String>{
    'creado',
    'editado',
    'reactivado',
    'desactivado',
    'retirado',
    'eliminado',
    'clave_temporal_generada',
    'clave_temporal_cambiada',
    'foto_perfil_actualizada',
  };

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProviderV2>().user!;
    _institutionId = user.institution;
    _campusId = user.campus;
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _items.clear();
      _hasNext = false;
      _lastDoc = null;
    });

    try {
      final page = await _svc.obtenerHistorial(
        institutionId: _institutionId,
        campusId: _campusId,
        nameContains: _query.trim().isEmpty ? null : _query.trim(),
        role: _rolSel,
        action: _accionSel,
        rango: _rango,
        limite: _pageSize,
        startAfter: null,
      );
      final total = await _svc.contarTotal(
        institutionId: _institutionId,
        campusId: _campusId,
        nameContains: _query.trim().isEmpty ? null : _query.trim(),
        role: _rolSel,
        action: _accionSel,
        rango: _rango,
      );

      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasNext = page.hasNext;
        _lastDoc = page.lastDoc;
        _total = total;
        _loading = false;
      });
    } catch (error) {
      await _showLoadError(error);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasNext || _loading) return;
    setState(() => _loading = true);

    try {
      final page = await _svc.obtenerHistorial(
        institutionId: _institutionId,
        campusId: _campusId,
        nameContains: _query.trim().isEmpty ? null : _query.trim(),
        role: _rolSel,
        action: _accionSel,
        rango: _rango,
        limite: _pageSize,
        startAfter: _lastDoc,
      );

      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasNext = page.hasNext;
        _lastDoc = page.lastDoc;
        _loading = false;
      });
    } catch (error) {
      await _showLoadError(error);
    }
  }

  Future<void> _showLoadError(Object error) async {
    if (!mounted) return;
    setState(() => _loading = false);
    await DialogUtils.showError(
      context: context,
      title: 'No se pudo cargar el historial',
      message: userFacingError(error),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final ini =
        _rango?.start ??
        DateTime(now.year, now.month, now.day).subtract(Duration(days: 7));
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
    final colors = Theme.of(context).colorScheme;
    if (!kIsWeb) {
      return Scaffold(
        body: SafeArea(
          child: Center(child: Text('Disponible solo en la versión web.')),
        ),
      );
    }

    // MISMO FORMATO VISUAL DE FECHAS QUE "Documentos"
    final df = DateFormat('yyyy-MM-dd');
    final rangoTexto = _rango == null
        ? ''
        : '${df.format(_rango!.start)}  →  ${df.format(_rango!.end)}';

    final filtered = _items;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: .06),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Total de registros de usuario',
                        child: Text('Total registros: $_total'),
                      ),
                    ),
                    Text(
                      'Mostrando: ${filtered.length}',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _searchController,
                      decoration: InputDecoration(
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
                      initialValue: _rolSel,
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
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
                      decoration: InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _rolSel = v),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _accionSel,
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
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
                      decoration: InputDecoration(
                        labelText: 'Acción',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _accionSel = v),
                    ),
                  ),

                  // ⬇️ Igual que "Documentos": TextFormField readonly para el rango
                  SizedBox(
                    width: 280,
                    child: HistoryDateRangeField(
                      value: rangoTexto,
                      onTap: _pickRange,
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: _reload,
                    icon: Icon(Icons.filter_alt),
                    label: Text('Aplicar filtros'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _query = '';
                        _rolSel = null;
                        _accionSel = null;
                        _rango = null;
                      });
                      _reload();
                    },
                    child: Text('Limpiar'),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (kIsWeb && filtered.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => UserHistoryUtils.exportarExcel(filtered),
                      icon: Icon(Icons.table_view),
                      label: Text('Exportar visibles a Excel'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => UserHistoryUtils.exportarPDF(filtered),
                      icon: Icon(Icons.picture_as_pdf),
                      label: Text('Exportar visibles a PDF'),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ],
              Expanded(
                child: _loading && _items.isEmpty
                    ? Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? Center(child: Text('No hay registros'))
                    : ListView.builder(
                        itemCount: filtered.length + (_hasNext ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (_hasNext && i == filtered.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: _loading
                                    ? CircularProgressIndicator()
                                    : OutlinedButton.icon(
                                        onPressed: _loadMore,
                                        icon: Icon(Icons.expand_more),
                                        label: Text('Cargar más'),
                                      ),
                              ),
                            );
                          }

                          final r = filtered[i];
                          final fecha = r['fecha'] as DateTime?;
                          final fechaTexto = fecha != null
                              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha)
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
                              color: colors.surface,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: colors.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: EdgeInsets.symmetric(
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
