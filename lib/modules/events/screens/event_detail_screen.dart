import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/open_external_link.dart';
import '../../../utils/user_facing_error.dart';
import '../../qr/screens/qr_scanner_screen.dart';
import '../../user/services/active_student_service.dart';
import '../models/event_models.dart';
import '../services/event_service.dart';

String eventCop(int value) =>
    'COP \$${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

String _when(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final labels = MaterialLocalizations.of(context);
  return '${labels.formatShortDate(local)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.service,
    this.studentId,
    this.scan,
  });
  final String eventId;
  final EventGateway service;
  final String? studentId;
  final Future<String?> Function(BuildContext)? scan;
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  EventDetail? _detail;
  List<EventChild> _children = const [];
  String? _studentId;
  String? _error;
  bool _busy = true;
  bool _scanning = false;
  bool _openingDialog = false;
  int _loadId = 0;
  final _requestIds = <String, String>{};
  bool get _family => context.read<UserProviderV2>().user?.role == 'Familiar';
  bool get _staff {
    final user = context.read<UserProviderV2>().user;
    return user?.role == 'Administrador' || user?.role == 'Docente';
  }

  bool _can(String action) =>
      !_busy && !_scanning && !_openingDialog && _detail?.can(action) == true;
  @override
  void initState() {
    super.initState();
    _studentId = widget.studentId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final id = ++_loadId;
    setState(() {
      _busy = true;
      _error = null;
      _detail = null;
    });
    try {
      if (_family) {
        final children = await widget.service.children();
        if (!mounted || id != _loadId) return;
        _children = children;
        if (children.isEmpty) {
          throw StateError('No hay hijos activos vinculados.');
        }
        final preferred =
            _studentId ?? context.read<UserProviderV2>().user?.activeStudentId;
        _studentId = children.any((c) => c.id == preferred)
            ? preferred
            : children.first.id;
        await ActiveStudentService().select(
          userProvider: context.read<UserProviderV2>(),
          studentId: _studentId!,
        );
        if (!mounted || id != _loadId) return;
      }
      final detail = await widget.service.detail(
        widget.eventId,
        studentId: _studentId,
      );
      if (mounted && id == _loadId) setState(() => _detail = detail);
    } catch (error) {
      if (mounted && id == _loadId && _family) {
        final selected = context.read<UserProviderV2>().user?.activeStudentId;
        if (_children.any((child) => child.id == selected)) {
          _studentId = selected;
        }
      }
      if (mounted && id == _loadId) {
        setState(() => _error = userFacingError(error));
      }
    } finally {
      if (mounted && id == _loadId) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _load();
    } catch (error) {
      if (mounted &&
          error is FirebaseFunctionsException &&
          error.code == 'aborted') {
        await _load();
      }
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _idempotent(Map<String, dynamic> data) {
    final key = jsonEncode(data);
    final id = _requestIds.putIfAbsent(key, () {
      final random = Random.secure();
      return List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    });
    return {...data, 'requestId': id};
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
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
      ) ==
      true;

  Future<void> _saveDefinition(Map<String, dynamic> changes) async {
    final event = _detail!.event;
    await _run(() async {
      await widget.service.saveDraft(
        eventId: event.id,
        expectedRevision: event.revision,
        value: {...event.toDraftMap(), ...changes},
      );
    });
  }

  Future<void> _publicity() async {
    final event = _detail!.event;
    final values = await _editFields(context, 'Aviso del colegio', [
      _Field('text', 'Texto del aviso', event.publicityText, max: 2000),
      _Field(
        'url',
        'Enlace HTTPS (opcional)',
        event.publicityUrl,
        url: true,
        max: 500,
      ),
    ]);
    if (values != null && mounted) await _saveDefinition({'publicity': values});
  }

  Future<void> _requirement([EventRequirement? item]) async {
    final event = _detail!.event;
    final values = await _editFields(
      context,
      item == null ? 'Nuevo requisito' : 'Editar requisito',
      [
        _Field(
          'label',
          'Requisito',
          item?.label ?? '',
          required: true,
          max: 120,
        ),
        _Field(
          'instructions',
          'Indicaciones (opcional)',
          item?.instructions ?? '',
          max: 2000,
        ),
        _Field(
          'targetType',
          'Se verifica por',
          item?.targetType ?? 'student',
          options: const {'student': 'Estudiante', 'family': 'Cada familiar'},
        ),
        _Field(
          'completionType',
          'Forma de cumplimiento',
          item?.completionType ?? 'manual',
          options: const {
            'manual': 'Verificación manual',
            'attendance': 'Asistencia',
            'payment': 'Pago registrado por el colegio',
          },
        ),
        _Field(
          'required',
          'Obligatorio',
          '${item?.required ?? true}',
          options: const {'true': 'Sí', 'false': 'No'},
        ),
        _Field(
          'amountCop',
          'Valor COP (opcional)',
          item?.amountCop?.toString() ?? '',
          integer: true,
        ),
      ],
    );
    if (values == null || !mounted) return;
    final replacement = EventRequirement(
      id: item?.id ?? 'req_${DateTime.now().microsecondsSinceEpoch}',
      label: values['label']!,
      instructions: values['instructions']!,
      targetType: values['targetType']!,
      completionType: values['completionType']!,
      required: values['required'] == 'true',
      amountCop: int.tryParse(values['amountCop']!),
    );
    await _saveDefinition({
      'requirements': [
        for (final existing in event.requirements)
          if (existing.id != item?.id) existing.toMap(),
        replacement.toMap(),
      ],
    });
  }

  Future<void> _food([EventFoodItem? item]) async {
    final values = await _editFields(
      context,
      item == null ? 'Nuevo alimento' : 'Editar alimento',
      [
        _Field('name', 'Nombre', item?.name ?? '', required: true, max: 120),
        _Field(
          'description',
          'Descripción (opcional)',
          item?.description ?? '',
          max: 2000,
        ),
        _Field(
          'priceCop',
          'Precio COP',
          item?.priceCop.toString() ?? '',
          required: true,
          integer: true,
        ),
        _Field(
          'active',
          'Disponible para reservar',
          '${item?.active ?? true}',
          options: const {'true': 'Sí', 'false': 'No'},
        ),
      ],
    );
    if (values == null || !mounted) return;
    await _run(() async {
      await widget.service.saveFood({
        'eventId': widget.eventId,
        'itemId': ?item?.id,
        'expectedRevision': item?.revision ?? 0,
        'name': values['name'],
        'description': values['description'],
        'priceCop': int.parse(values['priceCop']!),
        'active': values['active'] == 'true',
      });
    });
  }

  Future<void> _material([EventMaterial? item]) async {
    if (_openingDialog || _busy) return;
    setState(() => _openingDialog = true);
    try {
      final event = _detail!.event;
      final scope = await widget.service.contexts();
      if (!mounted) return;
      final allowedIds = event.audienceType == 'all'
          ? scope.groups.map((g) => g.id).toSet()
          : {
              ...event.targetGroupIds,
              ...scope.students
                  .where((s) => event.targetStudentIds.contains(s.id))
                  .map((s) => s.groupId),
            };
      final groups = scope.groups
          .where((g) => allowedIds.contains(g.id))
          .toList();
      final values = await _editFields(
        context,
        item == null ? 'Nuevo material o traje' : 'Editar preparación',
        [
          _Field(
            'kind',
            'Tipo',
            item?.kind ?? 'material',
            options: const {'material': 'Material', 'costume': 'Traje'},
          ),
          _Field('name', 'Nombre', item?.name ?? '', required: true, max: 120),
          _Field(
            'instructions',
            'Indicaciones',
            item?.instructions ?? '',
            max: 2000,
          ),
          _Field(
            'amountCop',
            'Valor COP (opcional)',
            item?.amountCop?.toString() ?? '',
            integer: true,
          ),
          _Field(
            'address',
            'Dónde conseguirlo (opcional)',
            item?.address ?? '',
            max: 250,
          ),
          _Field(
            'url',
            'Enlace HTTPS (opcional)',
            item?.url ?? '',
            url: true,
            max: 500,
          ),
          _Field(
            'active',
            'Visible',
            '${item?.active ?? true}',
            options: const {'true': 'Sí', 'false': 'No'},
          ),
        ],
        groups: groups,
        selectedGroups:
            item?.groupIds
                .where((id) => groups.any((g) => g.id == id))
                .toList() ??
            const [],
      );
      if (values == null || !mounted) return;
      await _run(() async {
        await widget.service.saveMaterial({
          'eventId': widget.eventId,
          'materialId': ?item?.id,
          'expectedRevision': item?.revision ?? 0,
          'kind': values['kind'],
          'name': values['name'],
          'instructions': values['instructions'],
          'amountCop': int.tryParse(values['amountCop']!),
          'address': values['address'],
          'url': values['url'],
          'active': values['active'] == 'true',
          'groupIds': jsonDecode(values['_groups']!),
        });
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _openingDialog = false);
    }
  }

  Future<void> _reserve([EventFoodOrder? order]) async {
    final studentId = _studentId;
    if (studentId == null || !_can('canOrder') || order?.locked == true) return;
    final items = _detail!.foodItems.where((item) => item.active).toList();
    if (items.isEmpty) return;
    final values = await _editFields(
      context,
      'Reserva anticipada',
      [
        for (final item in items)
          _Field(
            item.id,
            '${item.name} · ${eventCop(item.priceCop)}',
            '${order?.lines.where((l) => l['itemId'] == item.id).firstOrNull?['quantity'] ?? 0}',
            integer: true,
            maxInteger: 100,
          ),
      ],
      notice:
          'Indica cantidades de 0 a 100. El colegio confirmará la disponibilidad. '
          'El total definitivo lo calcula el servidor; aquí no se realiza ningún cobro.',
    );
    if (values == null || !mounted) return;
    final lines = [
      for (final item in items)
        if ((int.tryParse(values[item.id]!) ?? 0) > 0)
          {'itemId': item.id, 'quantity': int.parse(values[item.id]!)},
    ];
    if (lines.isEmpty) {
      setState(
        () =>
            _error = 'Indica al menos un alimento con cantidad mayor que cero.',
      );
      return;
    }
    final total = lines.fold<int>(
      0,
      (sum, line) =>
          sum +
          items.firstWhere((item) => item.id == line['itemId']).priceCop *
              (line['quantity'] as int),
    );
    if (!await _confirm(
          'Confirmar reserva',
          '${lines.map((line) => '${line['quantity']} × ${items.firstWhere((item) => item.id == line['itemId']).name}').join('\n')}\n'
              'Total a confirmar: ${eventCop(total)}.\n'
              'Se guardará para el hijo seleccionado. No se realiza un cobro ni se garantizan existencias. '
              'Si un precio cambió, tendrás que revisar el catálogo y confirmar de nuevo.',
        ) ||
        !mounted) {
      return;
    }
    final request = _idempotent({
      'eventId': widget.eventId,
      'studentId': studentId,
      'expectedRevision': order?.revision ?? 0,
      'expectedTotalCop': total,
      'lines': lines,
    });
    await _run(() async {
      await widget.service.reserveFood(request);
    });
  }

  Future<void> _cancelOrder(EventFoodOrder order) async {
    if (!await _confirm(
          'Cancelar reserva',
          '¿Cancelar tu reserva de ${eventCop(order.totalCop)}?',
        ) ||
        !mounted) {
      return;
    }
    final request = _idempotent({
      'eventId': widget.eventId,
      'studentId': order.studentId,
      'expectedRevision': order.revision,
      'lines': <Map<String, dynamic>>[],
      'cancel': true,
    });
    await _run(() async {
      await widget.service.reserveFood(request);
    });
  }

  Future<void> _manageOrder(EventFoodOrder order) async {
    final started = !DateTime.now().isBefore(_detail!.event.startAt);
    final values = await _editFields(
      context,
      'Registrar pago o entrega',
      [
        _Field(
          'paymentState',
          'Pago',
          order.paymentState,
          options: const {'pending': 'Pendiente', 'paid': 'Pago recibido'},
        ),
        if (started)
          _Field(
            'deliveryState',
            'Entrega',
            order.deliveryState,
            options: const {'pending': 'Pendiente', 'delivered': 'Entregado'},
          ),
        _Field(
          'reason',
          'Motivo / comprobación',
          '',
          required: true,
          max: 1000,
        ),
      ],
      notice:
          '${order.familyName} · ${order.studentName}\n${eventCop(order.totalCop)}. '
          'Registro manual: comprueba el pago o la entrega antes de confirmar.'
          '${started ? '' : ' La entrega se habilita al iniciar el evento.'}',
    );
    if (values == null ||
        !mounted ||
        !await _confirm(
          'Confirmar registro',
          'Se actualizará este pedido y quedará tu nombre y fecha en el historial.',
        )) {
      return;
    }
    final request = _idempotent({
      'eventId': widget.eventId,
      'orderId': order.id,
      'expectedRevision': order.revision,
      ...values,
    });
    if (mounted) {
      await _run(() async {
        await widget.service.manageOrder(request);
      });
    }
  }

  Future<void> _fulfill({Map<String, dynamic>? qr, String? payload}) async {
    final detail = _detail!;
    final choices = <String, String>{};
    final targets = <String, Map<String, String>>{};
    final eligibleIds = (qr?['requirementIds'] as List?)
        ?.whereType<String>()
        .toSet();
    final requirements = detail.event.requirements.where(
      (r) =>
          (eligibleIds == null || eligibleIds.contains(r.id)) &&
          (qr == null || qr['targetType'] == r.targetType) &&
          (r.completionType != 'attendance' ||
              !DateTime.now().isBefore(detail.event.startAt)),
    );
    for (final participant in detail.participants) {
      final studentId = '${participant['studentId']}';
      final studentName = '${participant['studentName']}';
      if (qr != null &&
          !eventMaps(qr['students']).any((s) => s['id'] == studentId)) {
        continue;
      }
      for (final r in requirements) {
        final persons = r.targetType == 'student'
            ? [
                {'id': studentId, 'name': studentName},
              ]
            : eventMaps(participant['families']);
        for (final person in persons) {
          if (qr != null && qr['targetId'] != person['id']) continue;
          final key = '${r.id}|$studentId|${person['id']}';
          choices[key] = '${r.label} · ${person['name']} · $studentName';
          targets[key] = {
            'requirementId': r.id,
            'targetType': r.targetType,
            'targetId': '${person['id']}',
            'studentId': studentId,
          };
        }
      }
    }
    if (choices.isEmpty) {
      setState(
        () => _error =
            'No hay requisitos y destinatarios elegibles para registrar.',
      );
      return;
    }
    final values = await _editFields(
      context,
      'Cumplimiento individual',
      [
        _Field(
          'target',
          'Requisito y destinatario',
          choices.keys.first,
          options: choices,
        ),
        _Field(
          'completed',
          'Estado',
          'true',
          options: const {'true': 'Cumplido', 'false': 'Pendiente / corregir'},
        ),
        _Field(
          'reason',
          'Motivo / comprobación',
          '',
          required: true,
          max: 1000,
        ),
      ],
      notice:
          'Cada familiar y estudiante conserva su propio registro. '
          'Escanear un QR no registra nada hasta confirmar.',
    );
    if (values == null || !mounted) return;
    final target = targets[values['target']]!;
    final existing = detail.completions
        .where(
          (c) =>
              c.requirementId == target['requirementId'] &&
              c.targetType == target['targetType'] &&
              c.targetId == target['targetId'],
        )
        .firstOrNull;
    if (!await _confirm(
          'Confirmar cumplimiento',
          '${choices[values['target']]}\n'
              '${values['completed'] == 'true' ? 'Cumplido' : 'Pendiente'}. '
              'Se guardará únicamente para esta persona.',
        ) ||
        !mounted) {
      return;
    }
    final request = _idempotent({
      'eventId': widget.eventId,
      ...target,
      'completed': values['completed'] == 'true',
      'expectedRevision': existing?.revision ?? 0,
      'reason': values['reason'],
      'qrPayload': ?payload,
    });
    await _run(() async {
      await widget.service.saveCompletion(request);
    });
  }

  Future<void> _scan() async {
    if (_scanning || _busy) return;
    setState(() => _scanning = true);
    try {
      final payload = await (widget.scan ?? scanInstitutionalQr)(context);
      if (payload == null || !mounted) return;
      final qr = await widget.service.prepareQr({
        'eventId': widget.eventId,
        'payload': payload,
        'source': 'camera',
        'clientPlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
      if (!mounted) return;
      await _fulfill(qr: qr, payload: payload);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
    child: ExpansionTile(
      title: Text(title),
      leading: Icon(icon),
      initiallyExpanded: true,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _action(String text, IconData icon, VoidCallback? callback) =>
      OutlinedButton.icon(
        onPressed: _busy || _scanning || _openingDialog ? null : callback,
        icon: Icon(icon),
        label: Text(text),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = _detail;
    final event = detail?.event;
    final canDefine =
        _can('canConfigure') && event?.status == SchoolEventStatus.draft;
    final familyId = context.read<UserProviderV2>().user?.id;
    final order = detail?.orders
        .where((o) => o.familyId == familyId && o.studentId == _studentId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del evento'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.primary,
        actions: [
          IconButton(
            onPressed: _busy || _scanning || _openingDialog ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_children.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                key: ValueKey(_studentId),
                initialValue: _studentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Hijo seleccionado',
                ),
                items: _children
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _busy || _scanning || _openingDialog
                    ? null
                    : (id) {
                        if (id != null && id != _studentId) {
                          setState(() {
                            _studentId = id;
                            _detail = null;
                          });
                          _load();
                        }
                      },
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null)
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            if (event != null && detail != null) ...[
              Text(
                event.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (event.subtitle.isNotEmpty)
                Text(
                  event.subtitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              Text('${event.typeLabel} · ${event.status.label}'),
              _section('Información', Icons.info_outline, [
                Text(event.description),
                const SizedBox(height: 8),
                Text('Lugar: ${event.location}'),
                Text('Inicio: ${_when(context, event.startAt)}'),
                Text('Final: ${_when(context, event.endAt)}'),
                if (event.responsibleNames.isNotEmpty)
                  Text(
                    'Responsables: ${event.responsibleNames.values.join(', ')}',
                  ),
                if (event.publicityText.isNotEmpty) Text(event.publicityText),
                if (event.publicityUrl.isNotEmpty)
                  _action(
                    'Abrir aviso',
                    Icons.link,
                    () => openExternalLink(
                      context,
                      Uri.parse(event.publicityUrl),
                    ),
                  ),
                for (final link in event.links)
                  _action(
                    link.label,
                    Icons.link,
                    () => openExternalLink(context, Uri.parse(link.url)),
                  ),
                if (canDefine)
                  _action(
                    'Editar aviso del colegio',
                    Icons.campaign,
                    _publicity,
                  ),
                if (_family &&
                    _studentId != null &&
                    event.status == SchoolEventStatus.published &&
                    DateTime.now().isBefore(event.startAt) &&
                    (event.registrationRequired ||
                        event.requiresFamilyAuthorization))
                  Wrap(
                    spacing: 8,
                    children: [
                      _action(
                        event.myResponse == 'attending'
                            ? 'Asistirá'
                            : 'Confirmar asistencia',
                        Icons.check,
                        () => _run(
                          () => widget.service.respond(
                            eventId: event.id,
                            studentId: _studentId!,
                            response: 'attending',
                          ),
                        ),
                      ),
                      _action(
                        'No asistirá',
                        Icons.close,
                        () => _run(
                          () => widget.service.respond(
                            eventId: event.id,
                            studentId: _studentId!,
                            response: 'declined',
                          ),
                        ),
                      ),
                    ],
                  ),
              ]),
              _section('Preparación', Icons.checkroom, [
                if (detail.materials.isEmpty)
                  const Text('No hay materiales o trajes publicados.'),
                for (final material in detail.materials)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${material.kind == 'costume' ? 'Traje' : 'Material'}: ${material.name}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!material.active) const Text('Inactivo'),
                        if (material.instructions.isNotEmpty)
                          Text(material.instructions),
                        if (material.amountCop != null)
                          Text(eventCop(material.amountCop!)),
                        if (material.address.isNotEmpty) Text(material.address),
                        if (material.url.isNotEmpty)
                          TextButton(
                            onPressed: () => openExternalLink(
                              context,
                              Uri.parse(material.url),
                            ),
                            child: const Text('Abrir enlace'),
                          ),
                      ],
                    ),
                    trailing: _can('canManageMaterials')
                        ? IconButton(
                            tooltip: 'Editar material',
                            onPressed: () => _material(material),
                            icon: const Icon(Icons.edit_outlined),
                          )
                        : null,
                  ),
                if (_can('canManageMaterials'))
                  _action('Agregar material o traje', Icons.add, _material),
                const Divider(),
                const Text('Requisitos del evento'),
                if (event.requirements.isEmpty)
                  const Text('Sin requisitos configurados.'),
                for (final requirement in event.requirements)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(requirement.label),
                    subtitle: Text(
                      [
                        requirement.instructions,
                        '${requirement.targetLabel} · ${requirement.completionLabel}',
                        requirement.required ? 'Obligatorio' : 'Opcional',
                        if (requirement.amountCop != null)
                          eventCop(requirement.amountCop!),
                      ].where((s) => s.isNotEmpty).join('\n'),
                    ),
                    trailing: canDefine
                        ? PopupMenuButton<String>(
                            tooltip: 'Acciones del requisito',
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text('Retirar del borrador'),
                              ),
                            ],
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _requirement(requirement);
                                return;
                              }
                              if (await _confirm(
                                    'Retirar requisito',
                                    requirement.label,
                                  ) &&
                                  mounted) {
                                await _saveDefinition({
                                  'requirements': event.requirements
                                      .where((r) => r.id != requirement.id)
                                      .map((r) => r.toMap())
                                      .toList(),
                                });
                              }
                            },
                          )
                        : null,
                  ),
                if (canDefine)
                  _action(
                    'Agregar requisito',
                    Icons.add_task,
                    event.requirements.length < 40 ? _requirement : null,
                  ),
              ]),
              if (event.isPresentation && event.foodEnabled)
                _section('Alimentos', Icons.restaurant_outlined, [
                  const Text(
                    'Reserva anticipada. El colegio confirma disponibilidad. '
                    'No hay existencias garantizadas, pasarela ni cobros desde la app.',
                  ),
                  if (detail.foodItems.isEmpty)
                    const Text('Aún no hay alimentos disponibles.'),
                  for (final food in detail.foodItems)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(food.name),
                      subtitle: Text(
                        '${food.description}\n${eventCop(food.priceCop)}${food.active ? '' : ' · Inactivo'}',
                      ),
                      trailing: _can('canConfigure')
                          ? IconButton(
                              tooltip: 'Editar alimento',
                              onPressed: () => _food(food),
                              icon: const Icon(Icons.edit_outlined),
                            )
                          : null,
                    ),
                  if (_can('canConfigure'))
                    _action('Agregar alimento', Icons.add, _food),
                  if (_can('canOrder') && order?.locked != true)
                    _action(
                      order == null
                          ? 'Reservar alimentos'
                          : 'Editar mi reserva',
                      Icons.shopping_basket_outlined,
                      () => _reserve(order),
                    ),
                  for (final current in detail.orders)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${current.familyName} · ${current.studentName}',
                            ),
                            for (final line in current.lines)
                              Text(
                                '${line['quantity']} × ${line['name']} · ${eventCop((line['priceCop'] as num).toInt())}',
                              ),
                            Text(
                              'Total confirmado: ${eventCop(current.totalCop)}',
                            ),
                            Text(
                              current.state == 'cancelled'
                                  ? 'Reserva cancelada'
                                  : '${current.paymentState == 'paid' ? 'Pago recibido' : 'Pago pendiente'} · ${current.deliveryState == 'delivered' ? 'Entregado' : 'Entrega pendiente'}',
                            ),
                            if (_can('canOrder') &&
                                !current.locked &&
                                current.state == 'reserved' &&
                                current.familyId == familyId)
                              TextButton(
                                onPressed: () => _cancelOrder(current),
                                child: const Text('Cancelar mi reserva'),
                              ),
                            if (_can('canManageFulfillment') &&
                                current.state == 'reserved')
                              _action(
                                'Registrar pago / entrega',
                                Icons.fact_check_outlined,
                                () => _manageOrder(current),
                              ),
                          ],
                        ),
                      ),
                    ),
                ]),
              _section('Seguimiento', Icons.fact_check_outlined, [
                const Text(
                  'El cumplimiento de una persona no cambia el de los demás familiares o estudiantes.',
                ),
                if (event.requirements.isEmpty)
                  const Text('No hay requisitos configurados.'),
                ..._checklist(detail),
                if (_can('canManageFulfillment')) ...[
                  _action(
                    'Registrar cumplimiento',
                    Icons.checklist,
                    () => _fulfill(),
                  ),
                  _action(
                    'Leer QR para seguimiento',
                    Icons.qr_code_scanner,
                    _scan,
                  ),
                ],
                if (!_staff && event.myAttendance != null)
                  Text(
                    'Asistencia: ${event.myAttendance == 'present' ? 'Presente' : 'Ausente'}',
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _checklist(EventDetail detail) {
    final user = context.read<UserProviderV2>().user!;
    final rows = <String, (EventRequirement, String, String)>{};
    for (final requirement in detail.event.requirements) {
      final candidates = _staff
          ? detail.participants
          : [
              {
                'studentId': _studentId ?? user.id,
                'studentName':
                    _children
                        .where((c) => c.id == _studentId)
                        .firstOrNull
                        ?.name ??
                    'Mi registro',
                'families': _family
                    ? [
                        {'id': user.id, 'name': 'Mi registro familiar'},
                      ]
                    : [],
              },
            ];
      for (final student in candidates) {
        final persons = requirement.targetType == 'student'
            ? [
                {'id': student['studentId'], 'name': student['studentName']},
              ]
            : eventMaps(student['families']);
        for (final person in persons) {
          final id = '${person['id']}';
          rows['${requirement.id}|$id'] = (
            requirement,
            id,
            '${person['name']}',
          );
        }
      }
    }
    return [
      for (final row in rows.values)
        Builder(
          builder: (context) {
            final completion = detail.completions
                .where(
                  (c) =>
                      c.requirementId == row.$1.id &&
                      c.targetId == row.$2 &&
                      c.targetType == row.$1.targetType,
                )
                .firstOrNull;
            final completed = completion?.completed == true;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                completed ? Icons.check_circle_outline : Icons.pending_actions,
              ),
              title: Text(row.$1.label),
              subtitle: Text(
                '${row.$3} · ${completed ? 'Cumplido' : 'Pendiente'}'
                '${completion?.markedAt == null ? '' : '\n${_when(context, completion!.markedAt!)}'}'
                '${completion?.markedBy.isNotEmpty == true ? '\nRegistrado por: ${completion!.markedBy}' : ''}',
              ),
            );
          },
        ),
    ];
  }
}

class _Field {
  const _Field(
    this.key,
    this.label,
    this.value, {
    this.required = false,
    this.integer = false,
    this.url = false,
    this.options,
    this.max = 250,
    this.maxInteger = 1000000000,
  });
  final String key, label, value;
  final bool required, integer, url;
  final Map<String, String>? options;
  final int max, maxInteger;
}

Future<Map<String, String>?> _editFields(
  BuildContext context,
  String title,
  List<_Field> fields, {
  String? notice,
  List<EventGroup>? groups,
  List<String> selectedGroups = const [],
}) => showDialog<Map<String, String>>(
  context: context,
  builder: (_) => _FieldsDialog(
    title: title,
    fields: fields,
    notice: notice,
    groups: groups,
    selectedGroups: selectedGroups,
  ),
);

class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog({
    required this.title,
    required this.fields,
    this.notice,
    this.groups,
    required this.selectedGroups,
  });
  final String title;
  final List<_Field> fields;
  final String? notice;
  final List<EventGroup>? groups;
  final List<String> selectedGroups;
  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  late final Map<String, TextEditingController> controllers;
  late final Set<String> selected;
  final formKey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    controllers = {
      for (final f in widget.fields)
        f.key: TextEditingController(text: f.value),
    };
    selected = widget.selectedGroups.toSet();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: SizedBox(
      width: 460,
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(widget.notice!),
              ),
            for (final field in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: field.options != null
                    ? DropdownButtonFormField<String>(
                        initialValue: controllers[field.key]!.text,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: field.label),
                        items: field.options!.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) controllers[field.key]!.text = v;
                        },
                      )
                    : TextFormField(
                        controller: controllers[field.key],
                        maxLength: field.max,
                        minLines: 1,
                        maxLines: field.integer ? 1 : 3,
                        keyboardType: field.integer
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: InputDecoration(labelText: field.label),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (field.required && text.isEmpty) {
                            return 'Completa este campo.';
                          }
                          if (text.isEmpty) return null;
                          if (field.integer) {
                            final n = int.tryParse(text);
                            if (n == null || n < 0 || n > field.maxInteger) {
                              return 'Usa un entero entre 0 y ${field.maxInteger}.';
                            }
                          }
                          if (field.url) {
                            final uri = Uri.tryParse(text);
                            if (uri?.scheme != 'https' || uri!.host.isEmpty) {
                              return 'Usa un enlace HTTPS válido.';
                            }
                          }
                          return null;
                        },
                      ),
              ),
            if (widget.groups != null) ...[
              const Text('Grupos destinatarios'),
              Wrap(
                spacing: 6,
                children: [
                  for (final group in widget.groups!)
                    FilterChip(
                      label: Text(group.name),
                      selected: selected.contains(group.id),
                      onSelected: (v) => setState(() {
                        if (v) {
                          selected.add(group.id);
                        } else {
                          selected.remove(group.id);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          if (widget.groups != null && selected.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selecciona al menos un grupo.')),
            );
            return;
          }
          Navigator.pop(context, {
            for (final e in controllers.entries) e.key: e.value.text.trim(),
            if (widget.groups != null) '_groups': jsonEncode(selected.toList()),
          });
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
