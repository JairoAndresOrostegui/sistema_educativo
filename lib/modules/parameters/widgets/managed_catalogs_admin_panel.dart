import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/user_facing_error.dart';
import '../models/managed_catalog_entry.dart';
import '../services/managed_catalog_service.dart';

class ManagedCatalogsAdminPanel extends StatefulWidget {
  const ManagedCatalogsAdminPanel({super.key});

  @override
  State<ManagedCatalogsAdminPanel> createState() =>
      _ManagedCatalogsAdminPanelState();
}

class _ManagedCatalogsAdminPanelState extends State<ManagedCatalogsAdminPanel> {
  final _service = ManagedCatalogService();
  bool _loading = true;
  bool _saving = false;
  List<ManagedCatalogEntry> _items = const [];
  String _selectedKey = 'eps';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.list();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _error = userFacingError(
          error,
          fallback: 'Revisa tu conexión e intenta nuevamente.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([ManagedCatalogEntry? current]) async {
    final key = current?.key ?? _selectedKey;
    final label = TextEditingController(text: current?.label ?? '');
    final value = TextEditingController(text: current?.value ?? '');
    final order = TextEditingController(text: '${current?.order ?? 0}');
    var active = current?.active ?? true;
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(current == null ? 'Agregar opción' : 'Editar opción'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: label,
                    decoration: const InputDecoration(
                      labelText: 'Nombre mostrado',
                    ),
                    maxLength: 100,
                    validator: (text) => (text ?? '').trim().isEmpty
                        ? 'Escribe el nombre mostrado.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: value,
                    readOnly: current != null,
                    decoration: InputDecoration(
                      labelText: 'Código interno',
                      helperText: current == null
                          ? 'No podrá cambiarse después de crear la opción.'
                          : 'Se conserva para no dañar registros existentes.',
                    ),
                    maxLength: 100,
                    validator: (text) => (text ?? '').trim().isEmpty
                        ? 'Escribe el código interno.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Orden'),
                    validator: (text) {
                      final parsed = int.tryParse((text ?? '').trim());
                      if (parsed == null) return 'Escribe un número entero.';
                      if (parsed < 0 || parsed > 10000) {
                        return 'Usa un valor entre 0 y 10000.';
                      }
                      return null;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Opción activa'),
                    subtitle: const Text(
                      'Al desactivarla deja de aparecer en nuevas selecciones.',
                    ),
                    value: active,
                    onChanged: (next) => setDialogState(() => active = next),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) {
      label.dispose();
      value.dispose();
      order.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.save(
        id: current?.id,
        key: key,
        label: label.text.trim(),
        value: value.text.trim(),
        order: int.parse(order.text.trim()),
        active: active,
        expectedRevision: current?.revision,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'No se pudo guardar la opción',
        message: userFacingError(
          error,
          fallback: 'Revisa los datos e intenta nuevamente.',
        ),
      );
    } finally {
      label.dispose();
      value.dispose();
      order.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProviderV2>().user;
    final canEdit = user?.isSuperadmin == true;
    final filtered = _items.where((item) => item.key == _selectedKey).toList();
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Catálogos administrativos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              canEdit
                  ? 'Administra opciones globales usadas por los formularios.'
                  : 'Estos catálogos son globales. Solo el superadministrador puede modificarlos.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 430
                  ? DropdownButtonFormField<String>(
                      initialValue: _selectedKey,
                      decoration: const InputDecoration(labelText: 'Catálogo'),
                      items: const [
                        DropdownMenuItem(value: 'eps', child: Text('EPS')),
                        DropdownMenuItem(
                          value: 'documentType',
                          child: Text('Tipos de documento'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedKey = value);
                        }
                      },
                    )
                  : SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'eps', label: Text('EPS')),
                        ButtonSegment(
                          value: 'documentType',
                          label: Text('Tipos de documento'),
                        ),
                      ],
                      selected: {_selectedKey},
                      onSelectionChanged: (selection) =>
                          setState(() => _selectedKey = selection.first),
                    ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _CatalogLoadError(message: _error!, onRetry: _load)
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No hay opciones registradas.'),
              )
            else
              ...filtered.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.active ? Icons.check_circle_outline : Icons.block,
                    color: item.active
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  title: Text(item.label),
                  subtitle: Text(
                    '${item.value} · orden ${item.order} · ${item.active ? 'Activa' : 'Inactiva'}',
                  ),
                  trailing: canEdit
                      ? IconButton(
                          tooltip: 'Editar',
                          onPressed: _saving ? null : () => _edit(item),
                          icon: const Icon(Icons.edit_outlined),
                        )
                      : null,
                ),
              ),
            if (canEdit) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _loading || _saving ? null : () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar opción'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogLoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _CatalogLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
