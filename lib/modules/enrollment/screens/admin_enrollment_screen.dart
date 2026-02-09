import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../export/enrollment_pdf_utils.dart';
import '../models/enrollment_model.dart';
import '../screens/enrollment_form_screen.dart';
import '../services/enrollment_service.dart';

class AdminEnrollmentScreen extends StatefulWidget {
  const AdminEnrollmentScreen({super.key});

  @override
  State<AdminEnrollmentScreen> createState() => _AdminEnrollmentScreenState();
}

class _AdminEnrollmentScreenState extends State<AdminEnrollmentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  List<Enrollment> _items = [];
  String _estadoActual = 'pendiente_revision';
  int _pendingCount = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pendingSub;

  final _tabs = const [
    _EstadoTab('Pendientes', 'pendiente_revision'),
    _EstadoTab('Pre-matriculado', 'prematriculado'),
    _EstadoTab('Matriculados', 'matriculado'),
    _EstadoTab('Rechazados', 'rechazado'),
    _EstadoTab('Retirados', 'desmatriculado'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _estadoActual = _tabs[_tabController.index].estado;
      _fetch();
    });
    _listenPending();
    _fetch();
  }

  void _listenPending() {
    _pendingSub = FirebaseFirestore.instance
        .collection('enrollments')
        .where('estado', whereIn: ['prematriculado', 'pendiente_revision'])
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          setState(() => _pendingCount = snapshot.size);
        });
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final service = EnrollmentService();
      final data = await service.listByEstado(_estadoActual, limit: 50);
      if (mounted) {
        setState(() => _items = data);
      }
    } catch (_) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error',
        message: 'No se pudo cargar el listado de matriculas.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _aprobar(Enrollment e) async {
    if (!mounted) return;
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    // ignore: use_build_context_synchronously
    // ignore: use_build_context_synchronously
    final up = context.read<UserProviderV2>();
    try {
      await EnrollmentService().updateEnrollment(
        id: e.id,
        data: e.data,
        estado: 'matriculado',
        revisadoPor: up.user?.id,
        vinculaUsuarioId: e.vinculaUsuarioId,
      );
      if (!mounted) return;
      await DialogUtils.showSuccess(
        context: context,
        title: 'Aprobado',
        message: 'La matricula fue marcada como matriculado.',
      );
      await EnrollmentPdfUtils.export(
        e.data,
        estado: 'matriculado',
        anio: e.anioMatricula,
      );
      _fetch();
    } catch (_) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error',
        message: 'No se pudo aprobar esta matricula.',
      );
    }
  }

  Future<void> _rechazar(Enrollment e) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Rechazar matricula'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );

    if (motivo == null || motivo.isEmpty) return;

    if (!mounted) return;
    final up = context.read<UserProviderV2>();
    try {
      await EnrollmentService().updateEnrollment(
        id: e.id,
        data: e.data,
        estado: 'rechazado',
        revisadoPor: up.user?.id,
        rechazoMotivo: motivo,
        vinculaUsuarioId: e.vinculaUsuarioId,
      );
      if (!mounted) return;
      await DialogUtils.showSuccess(
        context: context,
        title: 'Rechazado',
        message: 'Se marco como rechazado.',
      );
      _fetch();
    } catch (_) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error',
        message: 'No se pudo rechazar esta matricula.',
      );
    }
  }

  Future<void> _desmatricular(Enrollment e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Desmatricular'),
            content: const Text(
              '¿Deseas marcar este registro como desmatriculado?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Desmatricular'),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    // ignore: use_build_context_synchronously
    final up = context.read<UserProviderV2>();
    try {
      await EnrollmentService().updateEnrollment(
        id: e.id,
        data: e.data,
        estado: 'desmatriculado',
        revisadoPor: up.user?.id,
        vinculaUsuarioId: e.vinculaUsuarioId,
      );
      if (!mounted) return;
      await DialogUtils.showSuccess(
        context: context,
        title: 'Desmatriculado',
        message: 'Se marcó como desmatriculado.',
      );
      _fetch();
    } catch (_) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error',
        message: 'No se pudo desmatricular este registro.',
      );
    }
  }

  void _editar(Enrollment e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EnrollmentFormScreen(
              enrollmentId: e.id,
              initialEstado: e.estado,
              existingData: e.data,
              modeOverride: EnrollmentEntryMode.admin,
              anioMatricula: e.anioMatricula,
            ),
      ),
    ).then((_) => _fetch());
  }

  String _estadoDisplay(String estado) {
    switch (estado) {
      case 'matriculado':
        return 'Matriculado';
      case 'rechazado':
        return 'Rechazado';
      case 'desmatriculado':
        return 'Desmatriculado';
      case 'pendiente_revision':
        return 'Pendiente';
      case 'prematriculado':
        return 'Pre-matriculado';
      default:
        return estado;
    }
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackToDashboardButton(),
        title: const Text('Gestion de matriculas'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.assignment_ind, color: Colors.redAccent),
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
          labelColor: Colors.redAccent,
          indicatorColor: Colors.redAccent,
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _fetch,
                child:
                    _items.isEmpty
                        ? const ListTile(
                          title: Text('Sin matriculas en este estado.'),
                        )
                        : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, index) {
                            final e = _items[index];
                            final nombre =
                                (e.data['nombresApellidosAlumno'] ??
                                        '${e.data['nombresAlumno'] ?? ''} ${e.data['apellidosAlumno'] ?? ''}')
                                    .toString()
                                    .trim();
                            final estadoLabel = _estadoDisplay(e.estado);
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                title: Text(
                                  nombre.isEmpty ? 'Sin nombre' : nombre,
                                ),
                                subtitle: Text(
                                  'Doc: ${e.data['numeroIdentidad'] ?? 'N/D'}  Estado: $estadoLabel',
                                ),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    IconButton(
                                      onPressed: () => _editar(e),
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Editar',
                                    ),
                                    if (e.estado != 'matriculado')
                                      IconButton(
                                        onPressed: () => _aprobar(e),
                                        icon: const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        ),
                                        tooltip: 'Aprobar',
                                      ),
                                    if (e.estado != 'rechazado')
                                      IconButton(
                                        onPressed: () => _rechazar(e),
                                        icon: const Icon(
                                          Icons.cancel,
                                          color: Colors.redAccent,
                                        ),
                                        tooltip: 'Rechazar',
                                      ),
                                    if (e.estado == 'matriculado')
                                      IconButton(
                                        onPressed: () => _desmatricular(e),
                                        icon: const Icon(
                                          Icons.undo,
                                          color: Colors.orange,
                                        ),
                                        tooltip: 'Desmatricular',
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => const EnrollmentFormScreen(
                    modeOverride: EnrollmentEntryMode.admin,
                  ),
            ),
          ).then((_) => _fetch());
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}

class _EstadoTab {
  final String label;
  final String estado;
  const _EstadoTab(this.label, this.estado);
}
