import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/user_facing_error.dart';
import '../../user/services/active_student_service.dart';
import '../models/event_models.dart';
import '../services/event_service.dart';
import '../utils/event_export.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.service});
  final EventGateway? service;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final EventGateway _service;
  EventContext? _eventContext;
  List<SchoolEvent> _events = const [];
  List<EventChild> _children = const [];
  String? _studentId;
  bool _loading = true;
  String? _error;

  bool get _isStaff {
    final role = context.read<UserProviderV2>().user?.role;
    return role == 'Administrador' || role == 'Docente';
  }

  bool _hasPermission(String permission) {
    final user = context.read<UserProviderV2>().user;
    if (user == null) return false;
    return user.isSuperadmin ||
        user.permissions.any(
          (item) => item.toString().trim().toLowerCase() == permission,
        );
  }

  bool get _canCreate => _isStaff && _hasPermission('eventos.crear');
  bool get _canEdit => _isStaff && _hasPermission('eventos.editar');

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EventService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isStaff) {
        final result = await Future.wait([
          _service.contexts(),
          _service.events(),
        ]);
        if (!mounted) return;
        setState(() {
          _eventContext = result[0] as EventContext;
          _events = result[1] as List<SchoolEvent>;
        });
      } else {
        final provider = context.read<UserProviderV2>();
        final user = provider.user!;
        if (user.role == 'Familiar') {
          _studentId = null;
          _children = await _service.children();
          if (_children.isNotEmpty) {
            _studentId =
                _children.any((item) => item.id == user.activeStudentId)
                ? user.activeStudentId
                : _children.first.id;
            await ActiveStudentService().select(
              userProvider: provider,
              studentId: _studentId!,
            );
          }
        } else {
          _studentId = user.id;
        }
        _events = _studentId == null
            ? const []
            : await _service.events(studentId: _studentId);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userFacingError(
            error,
            fallback: 'No fue posible cargar los eventos.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectChild(String? value) async {
    if (value == null || value == _studentId) return;
    setState(() => _loading = true);
    try {
      await ActiveStudentService().select(
        userProvider: context.read<UserProviderV2>(),
        studentId: value,
      );
      final events = await _service.events(studentId: value);
      if (mounted) {
        setState(() {
          _studentId = value;
          _events = events;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([SchoolEvent? event]) async {
    final eventContext = _eventContext;
    if (eventContext == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventEditorScreen(
          eventContext: eventContext,
          service: _service,
          event: event,
        ),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _change(SchoolEvent event, SchoolEventStatus status) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${status.label}: ${event.title}'),
        content: Text('¿Confirmas cambiar el evento a ${status.label}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await _service.changeStatus(
        eventId: event.id,
        expectedRevision: event.revision,
        status: status,
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(SchoolEvent event, String response) async {
    final studentId = _studentId;
    if (studentId == null) return;
    setState(() => _loading = true);
    try {
      await _service.respond(
        eventId: event.id,
        studentId: studentId,
        response: response,
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAttendance(SchoolEvent event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EventAttendanceScreen(event: event, service: _service),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openLink(String value) async {
    try {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No se pudo abrir el enlace.');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              error,
              fallback: 'No se pudo abrir el enlace. Intenta nuevamente.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showReport() async {
    final eventContext = _eventContext;
    if (eventContext == null) return;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(eventContext.academicYear),
      lastDate: DateTime(eventContext.academicYear, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(eventContext.academicYear),
        end: DateTime(eventContext.academicYear, 12, 31),
      ),
    );
    if (range == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final rows = await _service.report(
        from: range.start,
        to: DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
          999,
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reporte de eventos · ${rows.length}'),
          content: SizedBox(
            width: 720,
            child: rows.isEmpty
                ? const Text('No hay eventos en el rango seleccionado.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return ListTile(
                        leading: const Icon(Icons.event_note_outlined),
                        title: Text(row.title),
                        subtitle: Text(
                          '${_eventDate(context, row.startAt)} · ${row.location}\n'
                          '${row.status.label} · ${row.targetCount} destinatarios · '
                          '${row.confirmedCount} confirmados',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            if (kIsWeb && rows.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () {
                  try {
                    exportEventReport(
                      rows: rows,
                      from: range.start,
                      to: range.end,
                    );
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
                icon: const Icon(Icons.download_outlined),
                label: const Text('Exportar Excel'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Widget> _eventActions(SchoolEvent event) {
    final user = context.read<UserProviderV2>().user;
    if (user == null) return const [];
    final canManage =
        user.isSuperadmin ||
        user.role == 'Administrador' ||
        event.responsibleNames.containsKey(user.id);
    if (!canManage || !_canEdit) return const [];
    final started = !DateTime.now().isBefore(event.startAt);
    return switch (event.status) {
      SchoolEventStatus.draft => [
        TextButton.icon(
          onPressed: _loading ? null : () => _edit(event),
          icon: const Icon(Icons.edit),
          label: const Text('Editar'),
        ),
        FilledButton.icon(
          onPressed: _loading
              ? null
              : () => _change(event, SchoolEventStatus.published),
          icon: const Icon(Icons.campaign),
          label: const Text('Publicar'),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => _change(event, SchoolEventStatus.cancelled),
          child: const Text('Cancelar'),
        ),
      ],
      SchoolEventStatus.published => [
        if (started)
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _openAttendance(event),
            icon: const Icon(Icons.how_to_reg),
            label: const Text('Asistencia'),
          ),
        if (started)
          FilledButton(
            onPressed: _loading
                ? null
                : () => _change(event, SchoolEventStatus.closed),
            child: const Text('Finalizar'),
          )
        else
          TextButton(
            onPressed: _loading
                ? null
                : () => _change(event, SchoolEventStatus.cancelled),
            child: const Text('Cancelar'),
          ),
      ],
      SchoolEventStatus.closed => [
        OutlinedButton.icon(
          onPressed: _loading ? null : () => _openAttendance(event),
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Asistencia'),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => _change(event, SchoolEventStatus.archived),
          child: const Text('Archivar'),
        ),
      ],
      SchoolEventStatus.cancelled => [
        TextButton(
          onPressed: _loading
              ? null
              : () => _change(event, SchoolEventStatus.archived),
          child: const Text('Archivar'),
        ),
      ],
      SchoolEventStatus.archived => const [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackToDashboardButton(),
        title: const Text('Eventos'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.primary,
        actions: [
          if (_isStaff)
            IconButton(
              tooltip: 'Reporte de eventos',
              onPressed: _loading ? null : _showReport,
              icon: const Icon(Icons.summarize_outlined),
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
              onPressed: _edit,
              icon: const Icon(Icons.event_available),
              label: const Text('Nuevo evento'),
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
            if (_children.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _studentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Hijo seleccionado',
                ),
                items: _children
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: _loading ? null : _selectChild,
              ),
            if (!_loading && _error == null && _events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 56),
                    SizedBox(height: 12),
                    Text('No hay eventos disponibles.'),
                  ],
                ),
              ),
            for (final event in _error == null ? _events : <SchoolEvent>[])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Chip(label: Text(event.status.label)),
                        ],
                      ),
                      Text(
                        '${_eventDate(context, event.startAt)} · ${event.location}',
                      ),
                      const SizedBox(height: 8),
                      Text(event.description),
                      if (event.responsibleNames.isNotEmpty)
                        Text(
                          'Responsables: ${event.responsibleNames.values.join(', ')}',
                        ),
                      if (event.registrationRequired)
                        Text(
                          'Confirmados: ${event.confirmedCount}'
                          '${event.capacity == null ? '' : '/${event.capacity}'}',
                        ),
                      for (final link in event.links)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _openLink(link.url),
                            icon: const Icon(Icons.link),
                            label: Text(link.label),
                          ),
                        ),
                      if (!_isStaff && event.myAttendance != null)
                        Text(
                          'Asistencia: ${event.myAttendance == 'present' ? 'Presente' : 'Ausente'}',
                        ),
                      if (context.read<UserProviderV2>().user?.role ==
                              'Familiar' &&
                          DateTime.now().isBefore(event.startAt) &&
                          (event.registrationRequired ||
                              event.requiresFamilyAuthorization))
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _loading
                                  ? null
                                  : () => _respond(event, 'attending'),
                              icon: const Icon(Icons.check),
                              label: Text(
                                event.myResponse == 'attending'
                                    ? 'Asistirá'
                                    : 'Confirmar',
                              ),
                            ),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => _respond(event, 'declined'),
                              child: Text(
                                event.myResponse == 'declined'
                                    ? 'No asistirá'
                                    : 'No asistirá',
                              ),
                            ),
                          ],
                        ),
                      if (_isStaff)
                        Wrap(spacing: 8, children: _eventActions(event)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }
}

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({
    super.key,
    required this.eventContext,
    required this.service,
    this.event,
  });
  final EventContext eventContext;
  final EventGateway service;
  final SchoolEvent? event;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _capacity;
  late final TextEditingController _linkLabel;
  late final TextEditingController _linkUrl;
  late DateTime _start;
  late DateTime _end;
  late String _audienceType;
  late Set<String> _groupIds;
  late Set<String> _studentIds;
  late Set<String> _responsibleIds;
  late bool _registrationRequired;
  late bool _requiresAuthorization;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final defaultStart = tomorrow.year == widget.eventContext.academicYear
        ? DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8)
        : widget.eventContext.academicYear > tomorrow.year
        ? DateTime(widget.eventContext.academicYear, 1, 1, 8)
        : DateTime(widget.eventContext.academicYear, 12, 31, 8);
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _location = TextEditingController(text: event?.location ?? '');
    _capacity = TextEditingController(text: event?.capacity?.toString() ?? '');
    _linkLabel = TextEditingController(
      text: event?.links.isNotEmpty == true ? event!.links.first.label : '',
    );
    _linkUrl = TextEditingController(
      text: event?.links.isNotEmpty == true ? event!.links.first.url : '',
    );
    _start = event?.startAt ?? defaultStart;
    _end = event?.endAt ?? _start.add(const Duration(hours: 2));
    _audienceType = event?.audienceType ?? 'groups';
    _groupIds = {...?event?.targetGroupIds};
    _studentIds = {...?event?.targetStudentIds};
    _responsibleIds = {...?event?.responsibleNames.keys};
    _registrationRequired = event?.registrationRequired ?? false;
    _requiresAuthorization = event?.requiresFamilyAuthorization ?? false;
    if (_responsibleIds.isEmpty &&
        widget.eventContext.responsibleUsers.isNotEmpty) {
      _responsibleIds.add(widget.eventContext.responsibleUsers.first.id);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _capacity.dispose();
    _linkLabel.dispose();
    _linkUrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(widget.eventContext.academicYear),
      lastDate: DateTime(widget.eventContext.academicYear, 12, 31),
      initialDate: initial,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audienceType == 'groups' && _groupIds.isEmpty) {
      setState(() => _error = 'Selecciona al menos un grupo.');
      return;
    }
    if (_audienceType == 'students' && _studentIds.isEmpty) {
      setState(() => _error = 'Selecciona al menos un estudiante.');
      return;
    }
    if (_responsibleIds.isEmpty) {
      setState(() => _error = 'Selecciona al menos un responsable.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.service.saveDraft(
        eventId: widget.event?.id,
        expectedRevision: widget.event?.revision,
        value: {
          'title': _title.text,
          'description': _description.text,
          'location': _location.text,
          'startAtMillis': _start.millisecondsSinceEpoch,
          'endAtMillis': _end.millisecondsSinceEpoch,
          'audienceType': _audienceType,
          'targetGroupIds': _groupIds.toList(),
          'targetStudentIds': _studentIds.toList(),
          'responsibleUserIds': _responsibleIds.toList(),
          'registrationRequired': _registrationRequired,
          'requiresFamilyAuthorization': _requiresAuthorization,
          'capacity': _capacity.text.trim().isEmpty
              ? null
              : int.tryParse(_capacity.text.trim()),
          'links': _linkUrl.text.trim().isEmpty
              ? <Map<String, String>>[]
              : [
                  {
                    'label': _linkLabel.text.trim(),
                    'url': _linkUrl.text.trim(),
                  },
                ],
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProviderV2>().user!;
    final isAdmin = user.isSuperadmin || user.role == 'Administrador';
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Nuevo evento' : 'Editar evento'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.primary,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: TextStyle(color: scheme.error)),
              TextFormField(
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: _required,
              ),
              TextFormField(
                controller: _description,
                maxLength: 3000,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: _required,
              ),
              TextFormField(
                controller: _location,
                maxLength: 250,
                decoration: const InputDecoration(labelText: 'Lugar'),
                validator: _required,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Inicio'),
                subtitle: Text(_eventDate(context, _start)),
                trailing: const Icon(Icons.schedule),
                onTap: _loading
                    ? null
                    : () async {
                        final value = await _pickDateTime(_start);
                        if (value != null) setState(() => _start = value);
                      },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Final'),
                subtitle: Text(_eventDate(context, _end)),
                trailing: const Icon(Icons.schedule),
                onTap: _loading
                    ? null
                    : () async {
                        final value = await _pickDateTime(_end);
                        if (value != null) setState(() => _end = value);
                      },
              ),
              DropdownButtonFormField<String>(
                initialValue: _audienceType,
                decoration: const InputDecoration(labelText: 'Audiencia'),
                items: [
                  const DropdownMenuItem(
                    value: 'groups',
                    child: Text('Grupos completos'),
                  ),
                  const DropdownMenuItem(
                    value: 'students',
                    child: Text('Estudiantes específicos'),
                  ),
                  if (isAdmin || _audienceType == 'all')
                    DropdownMenuItem(
                      value: 'all',
                      enabled: isAdmin,
                      child: Text('Toda la sede'),
                    ),
                ],
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _audienceType = value!),
              ),
              if (_audienceType == 'groups') ...[
                const SizedBox(height: 12),
                Text('Grupos', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final group in widget.eventContext.groups)
                      FilterChip(
                        label: Text(group.name),
                        selected: _groupIds.contains(group.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _groupIds.add(group.id);
                          } else {
                            _groupIds.remove(group.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              if (_audienceType == 'students') ...[
                const SizedBox(height: 12),
                Text(
                  'Estudiantes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.eventContext.students.isEmpty)
                  const Text('No hay estudiantes activos en tus grupos.'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final student in widget.eventContext.students)
                      FilterChip(
                        label: Text('${student.name} · ${student.groupName}'),
                        selected: _studentIds.contains(student.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _studentIds.add(student.id);
                          } else {
                            _studentIds.remove(student.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Responsables',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final responsible
                      in widget.eventContext.responsibleUsers)
                    FilterChip(
                      label: Text(responsible.name),
                      selected: _responsibleIds.contains(responsible.id),
                      onSelected: user.role == 'Docente'
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                _responsibleIds.add(responsible.id);
                              } else {
                                _responsibleIds.remove(responsible.id);
                              }
                            }),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requiere confirmación de asistencia'),
                value: _registrationRequired,
                onChanged: (value) =>
                    setState(() => _registrationRequired = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requiere autorización familiar'),
                value: _requiresAuthorization,
                onChanged: (value) =>
                    setState(() => _requiresAuthorization = value),
              ),
              if (_registrationRequired)
                TextFormField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cupo (vacío significa sin límite)',
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Enlace adjunto opcional',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextFormField(
                controller: _linkLabel,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Nombre del enlace',
                ),
              ),
              TextFormField(
                controller: _linkUrl,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'URL HTTPS'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('Guardar borrador'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventAttendanceScreen extends StatefulWidget {
  const EventAttendanceScreen({
    super.key,
    required this.event,
    required this.service,
  });
  final SchoolEvent event;
  final EventGateway service;

  @override
  State<EventAttendanceScreen> createState() => _EventAttendanceScreenState();
}

class _EventAttendanceScreenState extends State<EventAttendanceScreen> {
  late SchoolEvent _event;
  List<EventAttendanceEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.service.attendance(widget.event.id);
      if (mounted) {
        setState(() {
          _event = result.$1;
          _entries = result.$2;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_entries.any((entry) => entry.state == null)) {
      setState(() => _error = 'Marca la asistencia de todos los estudiantes.');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.service.saveAttendance(
        eventId: widget.event.id,
        expectedRevision: _event.attendanceRevision,
        entries: _entries,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asistencia del evento guardada.')),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        // A large roster is saved in bounded batches. Reload confirmed marks
        // and the current revision if a later batch could not be saved.
        await _load();
        if (mounted) setState(() => _error = userFacingError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Asistencia · ${widget.event.title}'),
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
            for (var index = 0; index < _entries.length; index++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_entries[index].studentName),
                          Text(
                            _entries[index].response == 'attending'
                                ? 'Asistencia confirmada'
                                : _entries[index].response == 'declined'
                                ? 'Indicó que no asistiría'
                                : 'Sin respuesta previa',
                          ),
                        ],
                      );
                      final selector = DropdownButtonFormField<String>(
                        initialValue: _entries[index].state,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Asistencia',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'present',
                            child: Text('Presente'),
                          ),
                          DropdownMenuItem(
                            value: 'absent',
                            child: Text('Ausente'),
                          ),
                        ],
                        onChanged: _loading
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _entries = [..._entries];
                                  _entries[index] = _entries[index].copyWith(
                                    state: value,
                                  );
                                });
                              },
                      );
                      if (constraints.maxWidth < 480) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            details,
                            const SizedBox(height: 12),
                            selector,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 12),
                          SizedBox(width: 150, child: selector),
                        ],
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  _loading ||
                      _entries.isEmpty ||
                      _entries.any((entry) => entry.state == null)
                  ? null
                  : _save,
              icon: const Icon(Icons.save),
              label: const Text('Guardar asistencia'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Este campo es obligatorio.' : null;

String _eventDate(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(value)} · '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
}
