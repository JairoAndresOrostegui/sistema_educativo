import 'package:flutter/material.dart';
import '../services/daily_route_service.dart';
import '../utils/route_ui_helpers.dart';

Future<String?> routeTextDialog(BuildContext context, String title) async {
  final c = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: TextField(controller: c, maxLength: 500),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  c.dispose();
  return value;
}

Future<void> showRouteAdminTools(
  BuildContext context, {
  required bool drivers,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _RouteTools(drivers: drivers),
  );
}

class _RouteTools extends StatefulWidget {
  final bool drivers;
  const _RouteTools({required this.drivers});
  @override
  State<_RouteTools> createState() => _RouteToolsState();
}

class _RouteToolsState extends State<_RouteTools> {
  List<dynamic> _items = [];
  String? _error;
  bool _busy = false;
  String get _function =>
      widget.drivers ? 'gestionarConductores' : 'gestionarCambiosParada';
  @override
  void initState() {
    super.initState();
    _call({});
  }

  Future<void> _call(Map<String, dynamic> data) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await RouteOperations.call(_function, data);
      if (mounted) {
        setState(() => _items = result['items'] is List ? result['items'] : []);
      }
    } catch (e) {
      if (mounted) setState(() => _error = routeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _driver() async {
    final data = <String, dynamic>{'action': 'save'};
    for (final entry in {
      'name': 'Nombre del conductor',
      'document': 'Documento',
      'phone': 'Teléfono',
      'license': 'Licencia de conducción',
      'notes': 'Observaciones de la hoja de vida',
    }.entries) {
      final value = await routeTextDialog(context, entry.value);
      if (!mounted || value == null) return;
      data[entry.key] = value;
    }
    await _call(data);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.drivers
          ? 'Conductores (sin acceso al sistema)'
          : 'Solicitudes de cambio de parada',
    ),
    content: SizedBox(
      width: 650,
      height: 420,
      child: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          Expanded(
            child: ListView(
              children: _items.whereType<Map>().map((raw) {
                final v = Map<String, dynamic>.from(raw);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.drivers
                              ? '${routeText(v['name'], fallback: 'Conductor')} · ${routeText(v['license'], fallback: 'Sin licencia registrada')}'
                              : '${routeText(v['routeName'], fallback: 'Recorrido')} · ${routeText(v['studentId'], fallback: 'Estudiante')}',
                        ),
                        Text(
                          widget.drivers
                              ? '${routeText(v['phone'], fallback: 'Sin teléfono')}\n${routeText(v['notes'])}'
                              : '${routeText(v['address'], fallback: 'Sin dirección')}\n${routeText(v['reason'], fallback: 'Sin motivo')}',
                        ),
                        if (!widget.drivers)
                          Wrap(
                            children: [
                              for (final approve in [true, false])
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          final reason = await routeTextDialog(
                                            context,
                                            'Motivo de la decisión',
                                          );
                                          if (reason != null &&
                                              reason.isNotEmpty) {
                                            await _call({
                                              ...Map<String, dynamic>.from(v),
                                              'action': 'decide',
                                              'approved': approve,
                                              'reason': reason,
                                            });
                                          }
                                        },
                                  child: Text(approve ? 'Aprobar' : 'Rechazar'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      if (widget.drivers)
        TextButton(
          onPressed: _busy ? null : _driver,
          child: const Text('Registrar conductor'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );
}
