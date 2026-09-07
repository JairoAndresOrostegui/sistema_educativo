import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/route/route_model.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/navigation_utils.dart';
import '../services/admin_route_service.dart';
import '../services/daily_route_service.dart';
import '../services/location_service.dart';
import '../widgets/teacher/teacher_route_form_dialog.dart';
import '../widgets/route_history_dialog.dart';

class TeacherRouteScreen extends StatefulWidget {
  const TeacherRouteScreen({super.key});
  @override
  State<TeacherRouteScreen> createState() => _TeacherRouteScreenState();
}

class _TeacherRouteScreenState extends State<TeacherRouteScreen> {
  List<RouteModel> _routes = [];
  String? _selected;
  String? _dailyId;
  String? _error;
  bool _busy = false;
  final _location = LocationService();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _location.stopLocationUpdates();
    super.dispose();
  }

  Future<void> _load() async {
    final u = context.read<UserProviderV2>().user!;
    try {
      final routes = await RouteService().getRutasAsignadas(
        userId: u.id,
        institutionId: u.institution,
        campusId: u.campus,
      );
      if (mounted) setState(() => _routes = routes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron consultar las rutas.');
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _input(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            maxLength: 500,
            minLines: 1,
            maxLines: 4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorrido escolar'),
        centerTitle: true,
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
        leading: BackToDashboardButton(),
        actions: [
          IconButton(
            tooltip: 'Historial de recogidas',
            onPressed: () => showRouteHistory(context),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selected,
              decoration: const InputDecoration(labelText: 'Ruta asignada'),
              items: _routes
                  .map(
                    (r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(r.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (id) => _run(() async {
                      _location.stopLocationUpdates();
                      final result = await RouteOperations.call(
                        'prepararRecorrido',
                        {'routeId': id},
                      );
                      if (mounted) {
                        setState(() {
                          _selected = id;
                          _dailyId = result['id'] as String;
                        });
                      }
                    }),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: colors.error)),
              ),
            if (_dailyId != null)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('daily_routes')
                    .doc(_dailyId)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Text('No se pudo consultar el recorrido.');
                  }
                  final d = snap.data?.data();
                  if (d == null) return const SizedBox.shrink();
                  final active = d['estado'] == 'activa';
                  final pending = d['estado'] == 'pendiente';
                  final automatic = d['mode'] == 'automatic';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text('Estado: ${d['estado']}'),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          automatic ? 'Cálculo automático' : 'Cálculo manual',
                        ),
                        subtitle: const Text(
                          'Un cálculo al iniciar; después solo cuando pulses Recalcular. Los avisos manuales funcionan en ambos modos.',
                        ),
                        value: automatic,
                        onChanged: _busy || !(pending || active)
                            ? null
                            : (value) => _run(() async {
                                await RouteOperations.execute(
                                  _dailyId!,
                                  value ? 'automatic' : 'manual',
                                );
                                if (value && active) {
                                  await RouteOperations.call(
                                    'calcularTiemposRuta',
                                    {'id': _dailyId},
                                  );
                                }
                              }),
                      ),
                      if (pending)
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await RouteOperations.execute(
                                    _dailyId!,
                                    'start',
                                  );
                                  await _location.startLocationUpdates(
                                    _dailyId!,
                                  );
                                  if (automatic) {
                                    await RouteOperations.call(
                                      'calcularTiemposRuta',
                                      {'id': _dailyId},
                                    );
                                  }
                                }),
                          child: const Text('Iniciar recorrido'),
                        ),
                      if (active)
                        Wrap(
                          spacing: 8,
                          children: [
                            if (automatic)
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              '¿Recalcular tiempos?',
                                            ),
                                            content: const Text(
                                              'Consulta Google Maps y consume cuota. Úsalo ante una demora o novedad importante.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Recalcular'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await RouteOperations.call(
                                            'calcularTiemposRuta',
                                            {'id': _dailyId},
                                          );
                                        }
                                      }),
                                child: const Text('Recalcular tiempos'),
                              ),
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final message = await _input(
                                        'Aviso general para las familias del recorrido',
                                      );
                                      if (message != null &&
                                          message.isNotEmpty &&
                                          mounted) {
                                        await _run(
                                          () => RouteOperations.execute(
                                            _dailyId!,
                                            'announcement',
                                            {'reason': message},
                                          ),
                                        );
                                      }
                                    },
                              child: const Text('Enviar aviso general'),
                            ),
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await _location.startLocationUpdates(
                                        _dailyId!,
                                      );
                                    }),
                              child: const Text('Activar ubicación'),
                            ),
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await RouteOperations.execute(
                                        _dailyId!,
                                        'finish',
                                      );
                                      _location.stopLocationUpdates();
                                    }),
                              child: const Text('Finalizar recorrido'),
                            ),
                          ],
                        ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('daily_routes')
                            .doc(_dailyId)
                            .collection('students')
                            .orderBy('orden')
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return const Text(
                              'No se pudieron consultar las paradas.',
                            );
                          }
                          return Column(
                            children: (snap.data?.docs ?? []).map((s) {
                              final v = s.data();
                              final closed =
                                  v['recogido'] == true || v['anulado'] == true;
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v['nombre'] ?? '',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(v['direccion'] ?? ''),
                                      if (automatic &&
                                          v['estimatedMinutes'] != null)
                                        Text(
                                          'Estimación: ${v['estimatedMinutes']} min · tramo ${v['distanceMeters']} m. Consulta la hora de actualización; puede variar.',
                                        ),
                                      Text(
                                        v['recogido'] == true
                                            ? 'Recogido'
                                            : v['anulado'] == true
                                            ? 'Ausencia registrada'
                                            : 'Pendiente',
                                      ),
                                      if (pending)
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () async {
                                                      final address = await _input(
                                                        'Dirección para este recorrido',
                                                        initial:
                                                            v['direccion'] ??
                                                            '',
                                                      );
                                                      if (address != null &&
                                                          address.isNotEmpty) {
                                                        await _run(
                                                          () =>
                                                              RouteOperations.execute(
                                                                _dailyId!,
                                                                'address',
                                                                {
                                                                  'studentId':
                                                                      s.id,
                                                                  'address':
                                                                      address,
                                                                },
                                                              ),
                                                        );
                                                      }
                                                    },
                                              child: const Text(
                                                'Editar parada',
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _run(
                                                      () =>
                                                          RouteOperations.execute(
                                                            _dailyId!,
                                                            'active',
                                                            {
                                                              'studentId': s.id,
                                                              'active':
                                                                  v['activo'] !=
                                                                  true,
                                                            },
                                                          ),
                                                    ),
                                              child: Text(
                                                v['activo'] == true
                                                    ? 'No viaja hoy'
                                                    : 'Incluir hoy',
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (active &&
                                          !closed &&
                                          v['activo'] == true)
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            FilledButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _run(() async {
                                                      await RouteOperations.execute(
                                                        _dailyId!,
                                                        'pickup',
                                                        {'studentId': s.id},
                                                      );
                                                    }),
                                              child: const Text('Recogido'),
                                            ),
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () async {
                                                      final reason = await _input(
                                                        'Motivo de no recogida',
                                                      );
                                                      if (reason != null &&
                                                          reason.isNotEmpty) {
                                                        await _run(
                                                          () =>
                                                              RouteOperations.execute(
                                                                _dailyId!,
                                                                'absent',
                                                                {
                                                                  'studentId':
                                                                      s.id,
                                                                  'reason':
                                                                      reason,
                                                                },
                                                              ),
                                                        );
                                                      }
                                                    },
                                              child: const Text('No recogido'),
                                            ),
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () async {
                                                      final minutes =
                                                          await DialogUtils.askEstimatedMinutes(
                                                            context,
                                                            'Minutos para llegar a esta parada',
                                                          );
                                                      if (minutes != null) {
                                                        await _run(
                                                          () =>
                                                              RouteOperations.execute(
                                                                _dailyId!,
                                                                'eta',
                                                                {
                                                                  'studentId':
                                                                      s.id,
                                                                  'minutes':
                                                                      minutes,
                                                                },
                                                              ),
                                                        );
                                                      }
                                                    },
                                              child: const Text(
                                                'Avisar tiempo',
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _run(
                                                      () =>
                                                          RouteOperations.execute(
                                                            _dailyId!,
                                                            'arrival',
                                                            {'studentId': s.id},
                                                          ),
                                                    ),
                                              child: const Text('Ya llegamos'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
