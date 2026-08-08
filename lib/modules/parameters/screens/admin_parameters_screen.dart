import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/material.dart';

import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../models/parameter_entry.dart';
import '../services/parameter_admin_service.dart';
import '../widgets/academic_groups_admin_panel.dart';

class AdminParametersScreen extends StatefulWidget {
  const AdminParametersScreen({super.key});

  @override
  State<AdminParametersScreen> createState() => _AdminParametersScreenState();
}

class _AdminParametersScreenState extends State<AdminParametersScreen> {
  final ParameterAdminService _service = ParameterAdminService();
  bool _loading = true;
  bool _saving = false;
  List<ParameterEntry> _items = [];
  List<String> _claves = [];
  String? _filtroClave;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final claves = await _service.listClaves();
      final items = await _service.list(clave: _filtroClave);
      if (!mounted) return;
      setState(() {
        _claves = claves;
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error',
        message: 'No se pudieron cargar los parámetros.\n$e',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({ParameterEntry? entry}) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _ParameterFormDialog(
        entry: entry,
        claves: _claves,
        onSubmit: (data) async {
          setState(() => _saving = true);
          try {
            if (entry == null) {
              await _service.create(
                clave: data.clave,
                etiqueta: data.etiqueta,
                valor: data.valor,
                orden: data.orden,
                activo: data.activo,
              );
            } else {
              await _service.update(
                id: entry.id,
                etiqueta: data.etiqueta,
                valor: data.valor,
                orden: data.orden,
                activo: data.activo,
              );
            }
            if (!mounted) return;
            Navigator.pop(context, true);
            await _load();
          } catch (e) {
            if (!mounted) return;
            await DialogUtils.showError(
              context: context,
              title: 'Error',
              message: 'No se pudo guardar.\n$e',
            );
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
      ),
    );
  }

  Future<void> _delete(ParameterEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar parametro'),
        content: Text(
          'Eliminaras "${entry.etiqueta}" de la clave "${entry.clave}". Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      await _service.delete(entry.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error',
        message: 'No se pudo eliminar.\n$e',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parámetros'),
        leading: BackToDashboardButton(),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refrescar',
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _openForm(),
        icon: Icon(Icons.add),
        label: Text('Nuevo'),
        backgroundColor: AppPalette.primary,
        foregroundColor: AppPalette.surface,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  AcademicGroupsAdminPanel(),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Filtrar por clave:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _filtroClave,
                          decoration: InputDecoration(
                            labelText: 'Clave',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text('Todas')),
                            ..._claves.map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => _filtroClave = v);
                            _load();
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (_items.isEmpty)
                    Card(
                      child: ListTile(
                        title: Text('Sin parámetros'),
                        subtitle: Text('Crea uno nuevo para empezar.'),
                      ),
                    )
                  else
                    ..._items.map(
                      (e) => Card(
                        margin: EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text('${e.etiqueta} (${e.valor})'),
                          subtitle: Text(
                            'Clave: ${e.clave}   •   Orden: ${e.orden}   •   Activo: ${e.activo ? 'Si' : 'No'}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: _saving
                                    ? null
                                    : () => _openForm(entry: e),
                                icon: Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: _saving ? null : () => _delete(e),
                                icon: Icon(
                                  Icons.delete,
                                  color: AppPalette.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

class _ParameterFormData {
  final String clave;
  final String etiqueta;
  final String valor;
  final int orden;
  final bool activo;

  _ParameterFormData({
    required this.clave,
    required this.etiqueta,
    required this.valor,
    required this.orden,
    required this.activo,
  });
}

class _ParameterFormDialog extends StatefulWidget {
  final ParameterEntry? entry;
  final List<String> claves;
  final Future<void> Function(_ParameterFormData data) onSubmit;

  const _ParameterFormDialog({
    required this.entry,
    required this.claves,
    required this.onSubmit,
  });

  @override
  State<_ParameterFormDialog> createState() => _ParameterFormDialogState();
}

class _ParameterFormDialogState extends State<_ParameterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _claveController;
  late TextEditingController _etiquetaController;
  late TextEditingController _valorController;
  late TextEditingController _ordenController;
  bool _activo = true;
  String? _claveSeleccionada;
  bool _usandoClaveNueva = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _claveSeleccionada = entry?.clave;
    _claveController = TextEditingController(text: entry?.clave ?? '');
    _etiquetaController = TextEditingController(text: entry?.etiqueta ?? '');
    _valorController = TextEditingController(text: entry?.valor ?? '');
    _ordenController = TextEditingController(
      text: entry?.orden.toString() ?? '1',
    );
    _activo = entry?.activo ?? true;
  }

  @override
  void dispose() {
    _claveController.dispose();
    _etiquetaController.dispose();
    _valorController.dispose();
    _ordenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.entry != null;
    final clavesDisponibles = widget.claves.where((c) => c != 'grade').toList();

    return AlertDialog(
      title: Text(esEdicion ? 'Editar parametro' : 'Nuevo parametro'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (esEdicion)
                TextFormField(
                  controller: _claveController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Clave',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _usandoClaveNueva
                      ? '_nueva_'
                      : (_claveSeleccionada?.isEmpty ?? true
                            ? null
                            : _claveSeleccionada),
                  decoration: InputDecoration(
                    labelText: 'Clave',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    ...clavesDisponibles.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    ),
                    DropdownMenuItem(
                      value: '_nueva_',
                      child: Text('Otra (escribir)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == '_nueva_') {
                      setState(() {
                        _usandoClaveNueva = true;
                        _claveSeleccionada = null;
                        _claveController.text = '';
                      });
                    } else {
                      setState(() {
                        _usandoClaveNueva = false;
                        _claveSeleccionada = v;
                        _claveController.text = v ?? '';
                      });
                    }
                  },
                  validator: (v) {
                    final clave = _usandoClaveNueva
                        ? _claveController.text.trim()
                        : (v ?? '');
                    if (clave.isEmpty) return 'Requerido';
                    if (clave == 'grade') {
                      return 'La clave "grade" no es editable';
                    }
                    return null;
                  },
                ),
              if (!esEdicion && _usandoClaveNueva)
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: TextFormField(
                    controller: _claveController,
                    decoration: InputDecoration(
                      labelText: 'Nueva clave',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return 'Requerido';
                      if (v == 'grade') {
                        return 'La clave "grade" no es editable';
                      }
                      return null;
                    },
                  ),
                ),
              SizedBox(height: 12),
              TextFormField(
                controller: _etiquetaController,
                decoration: InputDecoration(
                  labelText: 'Etiqueta (texto mostrado)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _valorController,
                decoration: InputDecoration(
                  labelText: 'Valor (se guarda en BD)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _ordenController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Orden',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (int.tryParse(v) == null) return 'Debe ser numero';
                  return null;
                },
              ),
              SizedBox(height: 12),
              SwitchListTile(
                title: Text('Activo'),
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final clave = _claveController.text.trim().isEmpty
                ? (_claveSeleccionada ?? '')
                : _claveController.text.trim();
            if (clave == 'grade') {
              await DialogUtils.showError(
                context: context,
                title: 'Clave no editable',
                message: 'La clave "grade" no se puede modificar.',
              );
              return;
            }
            final orden = int.tryParse(_ordenController.text.trim()) ?? 0;
            final data = _ParameterFormData(
              clave: clave,
              etiqueta: _etiquetaController.text.trim(),
              valor: _valorController.text.trim(),
              orden: orden,
              activo: _activo,
            );
            await widget.onSubmit(data);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.primary,
            foregroundColor: AppPalette.surface,
          ),
          child: Text(widget.entry == null ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }
}
