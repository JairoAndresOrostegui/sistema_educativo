import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';
import 'package:intl/intl.dart';
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
    _EstadoTab('Por corregir', 'correccion_solicitada'),
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
    final user = context.read<UserProviderV2>().user!;
    final isTeacher = user.role.trim().toLowerCase() == 'docente';
    if (isTeacher && (user.groupId ?? '').trim().isEmpty) return;
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('enrollments')
        .where(
          'estado',
          whereIn: [
            'prematriculado',
            'pendiente_revision',
            'correccion_solicitada',
          ],
        );
    if (!user.isSuperadmin) {
      query = query
          .where('institution', isEqualTo: user.institution)
          .where('campus', isEqualTo: user.campus);
    }
    if (isTeacher && (user.groupId ?? '').trim().isNotEmpty) {
      query = query.where('data.groupId', isEqualTo: user.groupId!.trim());
    }
    _pendingSub = query.snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() => _pendingCount = snapshot.size);
    });
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final service = EnrollmentService();
      final user = context.read<UserProviderV2>().user!;
      final isTeacher = user.role.trim().toLowerCase() == 'docente';
      if (isTeacher && (user.groupId ?? '').trim().isEmpty) {
        if (mounted) setState(() => _items = []);
        return;
      }
      final data = await service.listByEstado(
        _estadoActual,
        limit: 50,
        institution: user.isSuperadmin ? null : user.institution,
        campus: user.isSuperadmin ? null : user.campus,
        groupId: isTeacher ? user.groupId?.trim() : null,
      );
      if (mounted) {
        setState(() => _items = data);
      }
    } catch (_) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error',
        message: 'No se pudo cargar el listado de matrículas.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _aprobar(Enrollment e) async {
    if ((e.vinculaUsuarioId ?? '').isEmpty) {
      await DialogUtils.showError(
        context: context,
        title: 'Falta vincular al estudiante',
        message:
            'Edita la matrícula y busca el usuario estudiantil antes de aprobarla.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar matrícula'),
        content: const Text(
          'La solicitud pasará a Matriculado. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await EnrollmentService().transitionEnrollment(
        id: e.id,
        action: 'approve',
        linkedStudentId: e.vinculaUsuarioId,
      );
      if (!mounted) return;
      await DialogUtils.showSuccess(
        context: context,
        title: 'Aprobado',
        message: 'La matricula fue marcada como matriculado.',
      );
      if (!mounted) return;
      final shouldPrint = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Imprimir matrícula'),
          content: const Text('¿Deseas generar el formulario en PDF?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generar PDF'),
            ),
          ],
        ),
      );
      if (shouldPrint == true) {
        await EnrollmentPdfUtils.export(
          e.data,
          estado: 'matriculado',
          anio: e.anioMatricula,
        );
      }
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

  Future<void> _accionDocente(Enrollment e, String action) async {
    final controller = TextEditingController();
    final solicitarCorreccion = action == 'request_correction';
    final observation = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          solicitarCorreccion ? 'Solicitar corrección' : 'Agregar observación',
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Observación obligatoria',
            border: OutlineInputBorder(),
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
    if (observation == null || observation.isEmpty) return;
    try {
      await EnrollmentService().transitionEnrollment(
        id: e.id,
        action: action,
        observation: observation,
      );
      if (!mounted) return;
      await DialogUtils.showSuccess(
        context: context,
        title: 'Actualizado',
        message: solicitarCorreccion
            ? 'Se solicitó la corrección al acudiente.'
            : 'La observación quedó registrada.',
      );
      await _fetch();
    } catch (_) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error',
        message: 'No fue posible registrar la observación.',
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
    try {
      await EnrollmentService().transitionEnrollment(
        id: e.id,
        action: 'reject',
        observation: motivo,
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
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar'),
        content: const Text('¿Deseas marcar este registro como retirado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await EnrollmentService().transitionEnrollment(
        id: e.id,
        action: 'withdraw',
      );
      if (!mounted) return;
      await DialogUtils.showSuccess(
        context: context,
        title: 'Retirado',
        message: 'Se marco como retirado.',
      );
      _fetch();
    } catch (_) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error',
        message: 'No se pudo retirar este registro.',
      );
    }
  }

  void _editar(Enrollment e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnrollmentFormScreen(
          enrollmentId: e.id,
          initialEstado: e.estado,
          existingData: e.data,
          initialLinkedStudentId: e.vinculaUsuarioId,
          modeOverride: EnrollmentEntryMode.admin,
          anioMatricula: e.anioMatricula,
          institution: e.institution,
          campus: e.campus,
        ),
      ),
    ).then((_) => _fetch());
  }

  void _ver(Enrollment e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnrollmentFormScreen(
          enrollmentId: e.id,
          initialEstado: e.estado,
          existingData: e.data,
          initialLinkedStudentId: e.vinculaUsuarioId,
          modeOverride: EnrollmentEntryMode.admin,
          anioMatricula: e.anioMatricula,
          institution: e.institution,
          campus: e.campus,
          forceReadOnly: true,
        ),
      ),
    );
  }

  String _estadoDisplay(String estado) {
    switch (estado) {
      case 'matriculado':
        return 'Matriculado';
      case 'rechazado':
        return 'Rechazado';
      case 'desmatriculado':
        return 'Retirado';
      case 'pendiente_revision':
        return 'Pendiente';
      case 'prematriculado':
        return 'Pre-matriculado';
      case 'correccion_solicitada':
        return 'Corrección solicitada';
      default:
        return estado;
    }
  }

  void _runListAction(String action, Enrollment enrollment) {
    switch (action) {
      case 'view':
        _ver(enrollment);
        return;
      case 'edit':
        _editar(enrollment);
        return;
      case 'approve':
        _aprobar(enrollment);
        return;
      case 'reject':
        _rechazar(enrollment);
        return;
      case 'withdraw':
        _desmatricular(enrollment);
        return;
      case 'observe':
        _accionDocente(enrollment, 'observe');
        return;
      case 'correction':
        _accionDocente(enrollment, 'request_correction');
        return;
      case 'history':
        _showHistory(enrollment);
        return;
    }
  }

  Future<void> _showHistory(Enrollment enrollment) async {
    late final List<Map<String, dynamic>> history;
    try {
      history = await EnrollmentService().listHistory(enrollment.id);
    } catch (_) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Historial no disponible',
        message: 'No fue posible cargar los movimientos de la matrícula.',
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historial de la matrícula'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
          child: history.isEmpty
              ? const Center(child: Text('No hay movimientos registrados.'))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final timestamp = item['createdAt'];
                    final date = timestamp is Timestamp
                        ? DateFormat(
                            'dd/MM/yyyy, h:mm a',
                          ).format(timestamp.toDate().toLocal())
                        : 'Fecha pendiente';
                    final observation = (item['observation'] ?? '')
                        .toString()
                        .trim();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: Text(
                        '${_historyAction(item['action']?.toString())}: '
                        '${_estadoDisplay((item['toStatus'] ?? '').toString())}',
                      ),
                      subtitle: Text(
                        '$date\nActor: ${item['performedByRole'] ?? 'Sistema'}'
                        '${observation.isEmpty ? '' : '\n$observation'}',
                      ),
                      isThreeLine: observation.isNotEmpty,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _historyAction(String? action) => switch (action) {
    'created' => 'Creada',
    'save_review' => 'Guardada en revisión',
    'update_enrolled' => 'Datos actualizados',
    'approve' => 'Aprobada',
    'reject' => 'Rechazada',
    'withdraw' => 'Retirada',
    'request_correction' => 'Corrección solicitada',
    'resubmit' => 'Corrección enviada',
    'observe' => 'Observación registrada',
    _ => action ?? 'Movimiento',
  };

  @override
  void dispose() {
    _pendingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProviderV2>().user!;
    final role = user.role.trim().toLowerCase();
    final isTeacher = role == 'docente';
    final permissions = user.permissions
        .map((value) => value.trim().toLowerCase())
        .toSet();
    final canEdit =
        user.isSuperadmin || permissions.contains('matricula.editar');
    final compactList = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(
        leading: const BackToDashboardButton(),
        title: Text(
          isTeacher ? 'Matrículas de mi grado' : 'Gestión de matrículas',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.assignment_ind, color: AppPalette.primary),
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_pendingCount',
                      style: TextStyle(
                        color: AppPalette.surface,
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
          labelColor: AppPalette.primary,
          unselectedLabelColor: AppPalette.muted,
          indicatorColor: AppPalette.primary,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetch,
              child: _items.isEmpty
                  ? const ListTile(
                      title: Text('Sin matrículas en este estado.'),
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
                            title: Text(nombre.isEmpty ? 'Sin nombre' : nombre),
                            subtitle: Text(
                              'Doc: ${e.data['numeroIdentidad'] ?? 'N/D'}  Estado: $estadoLabel',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: compactList
                                ? PopupMenuButton<String>(
                                    tooltip: 'Acciones de matrícula',
                                    onSelected: (action) =>
                                        _runListAction(action, e),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: Text('Ver detalle'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'history',
                                        child: Text('Ver historial'),
                                      ),
                                      if (!isTeacher &&
                                          canEdit &&
                                          (e.estado == 'prematriculado' ||
                                              e.estado ==
                                                  'pendiente_revision' ||
                                              e.estado == 'matriculado'))
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Editar'),
                                        ),
                                      if (!isTeacher &&
                                          canEdit &&
                                          (e.estado == 'prematriculado' ||
                                              e.estado ==
                                                  'pendiente_revision')) ...[
                                        const PopupMenuItem(
                                          value: 'correction',
                                          child: Text('Solicitar corrección'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'approve',
                                          child: Text('Aprobar'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'reject',
                                          child: Text('Rechazar'),
                                        ),
                                      ],
                                      if (!isTeacher &&
                                          canEdit &&
                                          e.estado == 'matriculado')
                                        const PopupMenuItem(
                                          value: 'withdraw',
                                          child: Text('Retirar'),
                                        ),
                                      if (isTeacher && canEdit)
                                        const PopupMenuItem(
                                          value: 'observe',
                                          child: Text('Agregar observación'),
                                        ),
                                      if (isTeacher &&
                                          canEdit &&
                                          (e.estado == 'prematriculado' ||
                                              e.estado == 'pendiente_revision'))
                                        const PopupMenuItem(
                                          value: 'correction',
                                          child: Text('Solicitar corrección'),
                                        ),
                                    ],
                                  )
                                : Wrap(
                                    spacing: 8,
                                    children: [
                                      IconButton(
                                        onPressed: () => _ver(e),
                                        icon: const Icon(Icons.visibility),
                                        tooltip: 'Ver detalle',
                                      ),
                                      IconButton(
                                        onPressed: () => _showHistory(e),
                                        icon: const Icon(Icons.history),
                                        tooltip: 'Ver historial',
                                      ),
                                      if (!isTeacher &&
                                          canEdit &&
                                          (e.estado == 'prematriculado' ||
                                              e.estado ==
                                                  'pendiente_revision' ||
                                              e.estado == 'matriculado'))
                                        IconButton(
                                          onPressed: () => _editar(e),
                                          icon: const Icon(Icons.edit),
                                          tooltip: 'Editar',
                                        ),
                                      if (!isTeacher &&
                                          canEdit &&
                                          (e.estado == 'prematriculado' ||
                                              e.estado == 'pendiente_revision'))
                                        IconButton(
                                          onPressed: () => _accionDocente(
                                            e,
                                            'request_correction',
                                          ),
                                          icon: const Icon(Icons.rule),
                                          tooltip: 'Solicitar corrección',
                                        ),
                                      if (!isTeacher &&
                                          canEdit &&
                                          (e.estado == 'prematriculado' ||
                                              e.estado == 'pendiente_revision'))
                                        IconButton(
                                          onPressed: () => _aprobar(e),
                                          icon: Icon(
                                            Icons.check_circle,
                                            color: AppPalette.success,
                                          ),
                                          tooltip: 'Aprobar',
                                        ),
                                      if (!isTeacher &&
                                          canEdit &&
                                          (e.estado == 'prematriculado' ||
                                              e.estado == 'pendiente_revision'))
                                        IconButton(
                                          onPressed: () => _rechazar(e),
                                          icon: Icon(
                                            Icons.cancel,
                                            color: AppPalette.primary,
                                          ),
                                          tooltip: 'Rechazar',
                                        ),
                                      if (!isTeacher &&
                                          canEdit &&
                                          e.estado == 'matriculado')
                                        IconButton(
                                          onPressed: () => _desmatricular(e),
                                          icon: Icon(
                                            Icons.undo,
                                            color: AppPalette.warning,
                                          ),
                                          tooltip: 'Retirar',
                                        ),
                                      if (isTeacher && canEdit)
                                        IconButton(
                                          onPressed: () =>
                                              _accionDocente(e, 'observe'),
                                          icon: const Icon(Icons.comment),
                                          tooltip: 'Agregar observación',
                                        ),
                                      if (isTeacher &&
                                          canEdit &&
                                          (e.estado == 'prematriculado' ||
                                              e.estado == 'pendiente_revision'))
                                        IconButton(
                                          onPressed: () => _accionDocente(
                                            e,
                                            'request_correction',
                                          ),
                                          icon: const Icon(Icons.rule),
                                          tooltip: 'Solicitar corrección',
                                        ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: isTeacher || !canEdit
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EnrollmentFormScreen(
                      modeOverride: EnrollmentEntryMode.admin,
                    ),
                  ),
                ).then((_) => _fetch());
              },
              icon: const Icon(Icons.add),
              label: const Text('Nueva'),
              backgroundColor: AppPalette.primary,
            ),
    );
  }
}

class _EstadoTab {
  final String label;
  final String estado;
  const _EstadoTab(this.label, this.estado);
}
