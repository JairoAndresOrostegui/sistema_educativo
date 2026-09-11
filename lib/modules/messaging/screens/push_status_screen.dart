import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/messaging/push_job_status.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/user_facing_error.dart';

class PushStatusScreen extends StatefulWidget {
  const PushStatusScreen({super.key});
  @override
  State<PushStatusScreen> createState() => _PushStatusScreenState();
}

class _PushStatusScreenState extends State<PushStatusScreen> {
  final _jobs = <PushJobStatus>[];
  bool _busy = false;
  String? _error;
  bool _more = true;
  static const _labels = {
    'pending': 'Pendiente',
    'sending': 'Enviando',
    'retry': 'Reintento programado',
    'failed': 'Fallido',
    'partial': 'Terminado con rechazos',
    'accepted': 'Procesado por Firebase',
    'skipped': 'Sin dispositivos vigentes',
    'unknown': 'Estado desconocido',
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool more = false}) async {
    if (_busy || context.read<UserProviderV2>().user?.isSuperadmin != true) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await FirebaseFunctions.instance
          .httpsCallable('consultarEstadoNotificaciones')
          .call({if (more && _jobs.isNotEmpty) 'beforeId': _jobs.last.id});
      final payload = response.data;
      if (payload is! Map || payload['jobs'] is! List) {
        throw const FormatException('Respuesta de notificaciones no válida.');
      }
      final jobs = <PushJobStatus>[];
      for (final item in payload['jobs'] as List) {
        if (item is Map) jobs.add(PushJobStatus.fromMap(item));
      }
      if (!mounted) return;
      setState(() {
        if (!more) _jobs.clear();
        _jobs.addAll(jobs);
        _more = jobs.length == 50;
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry(PushJobStatus job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reintentar pendientes'),
        content: const Text(
          'Solo se reintentarán los dispositivos fallidos. '
          'La acción quedará auditada. Una entrega incierta podría repetirse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('reintentarNotificacion')
          .call({'id': job.id});
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userFacingError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = context.watch<UserProviderV2>().user?.isSuperadmin == true;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver al tablero',
          onPressed: () => context.go('/admin_dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Estado de notificaciones'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !allowed
          ? const Center(child: Text('Acceso exclusivo del superadministrador'))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Firebase confirma aceptación, no entrega ni lectura. '
                    'Un móvil y un navegador por usuario. Lotes de hasta 500 dispositivos.',
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (!_busy && _jobs.isEmpty)
                    const Text('Sin envíos registrados.'),
                  for (final job in _jobs)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${job.type} · ${_labels[job.status] ?? job.status}',
                            ),
                            Text(
                              'Institución: ${job.institutionId} · Sede: ${job.campusId}',
                            ),
                            Text(
                              'Fecha: ${job.createdAt == null ? 'No disponible' : DateFormat('dd/MM/yyyy, h:mm a').format(job.createdAt!.toLocal())}',
                            ),
                            Text(
                              'Aceptados: ${job.accepted} · Rechazados: ${job.rejected} · '
                              'Omitidos: ${job.skipped} · Pendientes: ${job.pending}',
                            ),
                            Text('Intentos: ${job.attempts}'),
                            if (job.lastError != null)
                              SelectableText('Error: ${job.lastError}'),
                            if (job.status == 'failed')
                              TextButton.icon(
                                onPressed: _busy ? null : () => _retry(job),
                                icon: const Icon(Icons.replay),
                                label: const Text('Reintentar pendientes'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_more && _jobs.isNotEmpty)
                    TextButton(
                      onPressed: _busy ? null : () => _load(more: true),
                      child: const Text('Cargar anteriores'),
                    ),
                ],
              ),
            ),
    );
  }
}
