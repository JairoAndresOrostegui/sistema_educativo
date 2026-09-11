import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/user_facing_error.dart';
import '../../user/services/active_student_service.dart';
import '../models/attendance_models.dart';
import '../services/attendance_service.dart';
import '../utils/attendance_export.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, this.service});

  final AttendanceGateway? service;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final AttendanceGateway _service;
  AttendanceContext? _context;
  List<AttendanceSession> _sessions = const [];
  List<AttendanceOwnRecord> _ownRecords = const [];
  List<AttendanceChild> _children = const [];
  String? _studentId;
  String _studentName = '';
  bool _loading = true;
  String? _error;

  bool get _isStaff {
    final role = context.read<UserProviderV2>().user?.role;
    return role == 'Administrador' || role == 'Docente';
  }

  bool get _canCreate {
    final user = context.read<UserProviderV2>().user;
    return _isStaff &&
        user != null &&
        (user.isSuperadmin || user.permissions.contains('asistencia.crear'));
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AttendanceService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isStaff) {
        final values = await Future.wait([
          _service.contexts(),
          _service.sessions(),
        ]);
        if (!mounted) return;
        setState(() {
          _context = values[0] as AttendanceContext;
          _sessions = values[1] as List<AttendanceSession>;
        });
      } else {
        await _loadOwn();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userFacingError(
            error,
            fallback: 'No fue posible cargar la asistencia.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOwn() async {
    final provider = context.read<UserProviderV2>();
    final user = provider.user!;
    if (user.role == 'Familiar') {
      _children = await _service.children();
      if (_children.isEmpty) {
        _studentId = null;
        _studentName = '';
        _ownRecords = const [];
        return;
      }
      final preferred = user.activeStudentId;
      _studentId = _children.any((child) => child.id == preferred)
          ? preferred
          : _children.first.id;
      await ActiveStudentService().select(
        userProvider: provider,
        studentId: _studentId!,
      );
    } else {
      _studentId = user.id;
    }
    final result = await _service.own(studentId: _studentId);
    _studentName = result.$1;
    _ownRecords = result.$2;
  }

  Future<void> _selectChild(String? studentId) async {
    if (studentId == null || studentId == _studentId) return;
    setState(() => _loading = true);
    try {
      await ActiveStudentService().select(
        userProvider: context.read<UserProviderV2>(),
        studentId: studentId,
      );
      _studentId = studentId;
      _studentName = '';
      _ownRecords = const [];
      final result = await _service.own(studentId: studentId);
      if (!mounted) return;
      setState(() {
        _studentName = result.$1;
        _ownRecords = result.$2;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final attendanceContext = _context;
    if (attendanceContext == null || attendanceContext.groups.isEmpty) return;
    final isAdmin =
        context.read<UserProviderV2>().user?.role == 'Administrador';
    var groupId = attendanceContext.groups.first.id;
    String? subjectId;
    var selectedDate = DateTime.now();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final subjects = attendanceContext.subjects
              .where((subject) => subject.groupId == groupId)
              .toList();
          if (subjectId != null &&
              !subjects.any((subject) => subject.id == subjectId)) {
            subjectId = null;
          }
          return AlertDialog(
            scrollable: true,
            title: const Text('Nueva lista de asistencia'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: groupId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Grupo'),
                    items: attendanceContext.groups
                        .map(
                          (group) => DropdownMenuItem(
                            value: group.id,
                            child: Text(group.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      groupId = value!;
                      subjectId = null;
                    }),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: subjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sesión',
                      helperText: 'El docente usa una asignatura de su carga.',
                    ),
                    items: [
                      if (isAdmin)
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Jornada completa'),
                        ),
                      ...subjects.map(
                        (subject) => DropdownMenuItem<String?>(
                          value: subject.id,
                          child: Text(subject.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => subjectId = value),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha'),
                    subtitle: Text(_dateLabel(selectedDate)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        firstDate: DateTime(selectedDate.year - 1),
                        lastDate: DateTime.now(),
                        initialDate: selectedDate,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: (!isAdmin && subjectId == null)
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final sessionId = await _service.openSession(
        groupId: groupId,
        subjectId: subjectId,
        date: _wireDate(selectedDate),
      );
      if (!mounted) return;
      await _openSession(sessionId);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _report() async {
    final attendanceContext = _context;
    if (attendanceContext == null) return;
    final today = DateTime.now();
    var dateFrom = today.subtract(const Duration(days: 30));
    var dateTo = today;
    String? groupId;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Reporte de asistencia'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: groupId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Grupo'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos mis grupos'),
                    ),
                    ...attendanceContext.groups.map(
                      (group) => DropdownMenuItem<String?>(
                        value: group.id,
                        child: Text(group.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => groupId = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Desde'),
                  subtitle: Text(_dateLabel(dateFrom)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      firstDate: DateTime(attendanceContext.academicYear),
                      lastDate: dateTo,
                      initialDate: dateFrom,
                    );
                    if (picked != null) {
                      setDialogState(() => dateFrom = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hasta'),
                  subtitle: Text(_dateLabel(dateTo)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      firstDate: dateFrom,
                      lastDate: today,
                      initialDate: dateTo,
                    );
                    if (picked != null) {
                      setDialogState(() => dateTo = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final report = await _service.report(
        dateFrom: _wireDate(dateFrom),
        dateTo: _wireDate(dateTo),
        groupId: groupId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _AttendanceReportDialog(report: report),
      );
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSession(String sessionId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            AttendanceSessionScreen(sessionId: sessionId, service: _service),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackToDashboardButton(),
        title: const Text('Lista de asistencia'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.primary,
        actions: [
          if (_isStaff)
            IconButton(
              tooltip: 'Generar reporte',
              onPressed: _loading ? null : _report,
              icon: const Icon(Icons.assessment_outlined),
            ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canCreate && !_loading
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Nueva lista'),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ),
            if (_error == null)
              if (_isStaff) ..._staffBody() else ..._ownBody(),
          ],
        ),
      ),
    );
  }

  List<Widget> _staffBody() {
    if (!_loading && _context?.groups.isEmpty == true) {
      return const [
        _EmptyAttendance(
          message: 'No tienes grupos vigentes para registrar asistencia.',
        ),
      ];
    }
    if (!_loading && _sessions.isEmpty) {
      return const [
        _EmptyAttendance(
          message: 'Aún no hay listas. Usa “Nueva lista” para comenzar.',
        ),
      ];
    }
    return [
      for (final session in _sessions)
        Card(
          child: ListTile(
            leading: Icon(session.isOpen ? Icons.edit_note : Icons.task_alt),
            title: Text(
              '${session.groupName}${session.subjectName == null ? '' : ' · ${session.subjectName}'}',
            ),
            subtitle: Text(
              '${session.date} · ${session.markedCount}/${session.studentCount} marcados · '
              '${session.isOpen ? 'Abierta' : 'Cerrada'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSession(session.id),
          ),
        ),
      const SizedBox(height: 88),
    ];
  }

  List<Widget> _ownBody() {
    return [
      if (_children.length > 1)
        DropdownButtonFormField<String>(
          initialValue: _studentId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Hijo seleccionado'),
          items: _children
              .map(
                (child) =>
                    DropdownMenuItem(value: child.id, child: Text(child.name)),
              )
              .toList(),
          onChanged: _loading ? null : _selectChild,
        ),
      if (_studentName.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _studentName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      if (!_loading && _studentId == null)
        const _EmptyAttendance(
          message: 'No hay un estudiante activo vinculado.',
        ),
      if (!_loading && _studentId != null && _ownRecords.isEmpty)
        const _EmptyAttendance(
          message: 'Todavía no hay registros de asistencia.',
        ),
      for (final record in _ownRecords)
        Card(
          child: ListTile(
            leading: Icon(_stateIcon(record.state)),
            title: Text('${record.state.label} · ${record.date}'),
            subtitle: Text(
              [
                record.groupName,
                record.observation,
              ].where((value) => value.isNotEmpty).join('\n'),
            ),
          ),
        ),
    ];
  }
}

class _AttendanceReportDialog extends StatelessWidget {
  const _AttendanceReportDialog({required this.report});

  final AttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final visibleRows = report.rows.take(500).toList();
    return AlertDialog(
      title: Text('Reporte ${report.dateFrom} a ${report.dateTo}'),
      content: SizedBox(
        width: 900,
        height: 560,
        child: ListView(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${report.sessionCount} listas')),
                for (final state in AttendanceState.values)
                  Chip(
                    label: Text(
                      '${state.label}: ${report.summary[state] ?? 0}',
                    ),
                  ),
              ],
            ),
            if (report.rows.length > visibleRows.length)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'La vista muestra 500 de ${report.rows.length} registros. '
                  'La exportación incluye todos.',
                ),
              ),
            if (visibleRows.isEmpty)
              const _EmptyAttendance(
                message: 'No hay asistencias cerradas en este rango.',
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Grupo')),
                    DataColumn(label: Text('Asignatura')),
                    DataColumn(label: Text('Estudiante')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Observación')),
                  ],
                  rows: [
                    for (final row in visibleRows)
                      DataRow(
                        cells: [
                          DataCell(Text(row.date)),
                          DataCell(Text(row.groupName)),
                          DataCell(Text(row.subjectName)),
                          DataCell(Text(row.studentName)),
                          DataCell(Text(row.state.label)),
                          DataCell(Text(row.observation)),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (kIsWeb && report.rows.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () {
              try {
                exportAttendanceReport(report);
              } catch (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      userFacingError(
                        error,
                        fallback:
                            'No fue posible exportar el reporte. Intenta nuevamente.',
                      ),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Exportar Excel'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class AttendanceSessionScreen extends StatefulWidget {
  const AttendanceSessionScreen({
    super.key,
    required this.sessionId,
    required this.service,
  });
  final String sessionId;
  final AttendanceGateway service;

  @override
  State<AttendanceSessionScreen> createState() =>
      _AttendanceSessionScreenState();
}

class _AttendanceSessionScreenState extends State<AttendanceSessionScreen> {
  AttendanceSession? _session;
  List<AttendanceEntry> _roster = const [];
  bool _loading = true;
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
      final result = await widget.service.session(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = result.$1;
        _roster = result.$2;
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setState(int index, AttendanceState? value) {
    if (value == null) return;
    setState(() {
      _roster = [..._roster];
      _roster[index] = _roster[index].copyWith(state: value);
    });
  }

  Future<void> _observation(int index) async {
    var value = _roster[index].observation;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_roster[index].studentName),
        content: TextFormField(
          initialValue: value,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Observación'),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _roster = [..._roster];
      _roster[index] = _roster[index].copyWith(observation: result);
    });
  }

  Future<bool> _save() async {
    final session = _session;
    final entries = _roster.where((entry) => entry.state != null).toList();
    if (session == null || entries.isEmpty) {
      setState(() => _error = 'Marca al menos un estudiante.');
      return false;
    }
    setState(() => _loading = true);
    try {
      await widget.service.save(
        sessionId: session.id,
        expectedRevision: session.revision,
        entries: entries,
      );
      await _load();
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _close() async {
    if (_roster.any((entry) => entry.state == null)) {
      setState(() => _error = 'Marca a todos los estudiantes antes de cerrar.');
      return;
    }
    if (!await _save() || !mounted) return;
    final session = _session!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar asistencia'),
        content: const Text(
          'El docente ya no podrá cambiarla. Las correcciones posteriores '
          'quedarán reservadas a administración y serán auditadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await widget.service.close(
        sessionId: session.id,
        expectedRevision: session.revision,
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = _session;
    final user = context.watch<UserProviderV2>().user;
    final canCorrectClosed =
        session?.isOpen == false &&
        (user?.isSuperadmin == true ||
            user?.role == 'Administrador' &&
                (user?.permissions.contains('asistencia.editar') ?? false));
    final canEdit = session?.isOpen == true || canCorrectClosed;
    return Scaffold(
      appBar: AppBar(
        title: Text(session?.groupName ?? 'Asistencia'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.primary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: TextStyle(color: scheme.error)),
            if (session != null) ...[
              Text(
                '${session.date}${session.subjectName == null ? '' : ' · ${session.subjectName}'} · '
                '${session.isOpen ? 'Abierta' : 'Cerrada'}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (session.isOpen)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                              _roster = _roster
                                  .map(
                                    (entry) => entry.copyWith(
                                      state: AttendanceState.present,
                                    ),
                                  )
                                  .toList();
                            }),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Todos presentes'),
                    ),
                    FilledButton.icon(
                      onPressed: _loading ? null : _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _loading ? null : _close,
                      icon: const Icon(Icons.lock),
                      label: const Text('Guardar y cerrar'),
                    ),
                  ],
                ),
              if (canCorrectClosed)
                Center(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _save,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Guardar corrección'),
                  ),
                ),
              for (var index = 0; index < _roster.length; index++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _roster[index].studentName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        DropdownButtonFormField<AttendanceState>(
                          initialValue: _roster[index].state,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                          ),
                          items: AttendanceState.values
                              .map(
                                (state) => DropdownMenuItem(
                                  value: state,
                                  child: Text(state.label),
                                ),
                              )
                              .toList(),
                          onChanged: canEdit && !_loading
                              ? (value) => _setState(index, value)
                              : null,
                        ),
                        if (_roster[index].observation.isNotEmpty)
                          Text(_roster[index].observation),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: canEdit && !_loading
                                ? () => _observation(index)
                                : null,
                            icon: const Icon(Icons.notes),
                            label: const Text('Observación'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyAttendance extends StatelessWidget {
  const _EmptyAttendance({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const Icon(Icons.fact_check_outlined, size: 56),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

String _wireDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _dateLabel(DateTime value) => _wireDate(value);

IconData _stateIcon(AttendanceState state) => switch (state) {
  AttendanceState.present => Icons.check_circle,
  AttendanceState.absent => Icons.cancel,
  AttendanceState.late => Icons.schedule,
  AttendanceState.excused => Icons.medical_information_outlined,
};
