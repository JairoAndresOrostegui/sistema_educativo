import 'package:flutter/material.dart';

import '../../../../models/user/user_model_v2.dart';
import '../../../../utils/dialog_utils.dart';
import '../../services/user_service_v2.dart';

class TeacherTransferDialog extends StatefulWidget {
  final List<userModelv2> users;
  final String institutionId;
  final String campusId;
  final bool isSuperadmin;

  const TeacherTransferDialog({
    super.key,
    required this.users,
    required this.institutionId,
    required this.campusId,
    required this.isSuperadmin,
  });

  @override
  State<TeacherTransferDialog> createState() => _TeacherTransferDialogState();
}

class _TeacherTransferDialogState extends State<TeacherTransferDialog> {
  final _service = UserServiceV2();
  userModelv2? _source;
  userModelv2? _target;
  TeacherTransferPreview? _preview;
  bool _temporary = true;
  bool _allowMerge = false;
  bool _loading = false;
  DateTime? _endsAt;
  List<ActiveTeacherTransfer> _activeTransfers = [];

  @override
  void initState() {
    super.initState();
    _loadActiveTransfers();
  }

  Future<void> _loadActiveTransfers() async {
    setState(() => _loading = true);
    try {
      final items = await _service.listActiveTeacherTransfers(
        institutionId: widget.institutionId,
        campusId: widget.campusId,
        allTenants: widget.isSuperadmin,
      );
      if (mounted) setState(() => _activeTransfers = items);
    } catch (_) {
      // La previsualización de un traslado nuevo sigue disponible.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revert(ActiveTeacherTransfer transfer) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar reemplazo temporal'),
        content: Text(
          '${transfer.sourceTeacherName} recuperará su acceso y la carga que '
          'todavía permanezca asignada a ${transfer.targetTeacherName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    setState(() => _loading = true);
    try {
      await _service.revertTemporaryTeacherTransfer(transfer.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No se pudo restaurar la carga',
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<userModelv2> get _teachers =>
      widget.users
          .where((item) => item.role == 'Docente' && item.status == 'activo')
          .toList()
        ..sort((a, b) => _name(a).compareTo(_name(b)));

  List<userModelv2> get _targets => _teachers
      .where(
        (item) =>
            item.id != _source?.id &&
            item.institution == _source?.institution &&
            item.campus == _source?.campus,
      )
      .toList();

  String _name(userModelv2 user) => '${user.firstName} ${user.lastName}';

  Future<void> _previewTransfer() async {
    if (_source == null || _target == null) return;
    setState(() {
      _loading = true;
      _preview = null;
    });
    try {
      final preview = await _service.previewTeacherTransfer(
        sourceTeacherId: _source!.id,
        targetTeacherId: _target!.id,
      );
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No se pudo calcular la carga',
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2, now.month, now.day),
      initialDate: _endsAt ?? now.add(const Duration(days: 30)),
    );
    if (selected != null) setState(() => _endsAt = selected);
  }

  Future<void> _execute() async {
    final preview = _preview;
    if (_source == null || _target == null || preview == null) return;
    if (preview.conflicts.isNotEmpty) {
      await DialogUtils.showError(
        context: context,
        title: 'Hay conflictos pendientes',
        message: preview.conflicts.join('\n'),
      );
      return;
    }
    if (_temporary && _endsAt == null) {
      await DialogUtils.showError(
        context: context,
        title: 'Falta la fecha final',
        message: 'Indica hasta cuándo estará vigente el reemplazo.',
      );
      return;
    }
    final confirmation = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar continuidad docente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_name(_source!)} quedará inactivo inmediatamente y '
              '${_name(_target!)} recibirá la carga vigente.',
            ),
            const SizedBox(height: 12),
            const Text('Escribe TRASLADAR para confirmar.'),
            TextField(controller: confirmation, autofocus: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              confirmation.text.trim() == 'TRASLADAR',
            ),
            child: const Text('Ejecutar traslado'),
          ),
        ],
      ),
    );
    confirmation.dispose();
    if (accepted != true) return;
    setState(() => _loading = true);
    try {
      await _service.executeTeacherTransfer(
        sourceTeacherId: _source!.id,
        targetTeacherId: _target!.id,
        temporary: _temporary,
        allowMerge: _allowMerge,
        endsAt: _endsAt,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No se pudo trasladar la carga',
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = <String, String>{
      'schedules': 'Horarios',
      'tutoring': 'Dirección de grupo',
      'routes': 'Rutas asignadas',
      'dailyRoutes': 'Rutas diarias abiertas',
      'messageThreads': 'Conversaciones con acceso delegado',
      'accessibleFiles': 'Archivos con acceso delegado',
    };
    final availableWidth = MediaQuery.sizeOf(context).width - 80;
    final contentWidth = availableWidth.clamp(280.0, 640.0).toDouble();
    final fieldWidth = (contentWidth - 40).clamp(240.0, 600.0).toDouble();
    return AlertDialog(
      title: const Text('Continuidad docente'),
      content: SizedBox(
        width: contentWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Traslada toda la responsabilidad académica vigente sin '
                'cambiar la autoría histórica de mensajes o archivos.',
              ),
              if (_activeTransfers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Reemplazos vigentes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ..._activeTransfers.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_ind_outlined),
                    title: Text(
                      '${item.sourceTeacherName} → ${item.targetTeacherName}',
                    ),
                    subtitle: Text(
                      item.temporary
                          ? 'Temporal · ${item.academicYear}'
                          : 'Definitivo · ${item.academicYear}',
                    ),
                    trailing: item.temporary
                        ? TextButton(
                            onPressed: _loading ? null : () => _revert(item),
                            child: const Text('Restaurar'),
                          )
                        : null,
                  ),
                ),
                const Divider(),
              ],
              const SizedBox(height: 16),
              DropdownMenu<String>(
                width: fieldWidth,
                enableFilter: true,
                enableSearch: true,
                label: const Text('Docente saliente'),
                dropdownMenuEntries: _teachers
                    .map(
                      (item) => DropdownMenuEntry(
                        value: item.id,
                        label: '${_name(item)} · ${item.campus}',
                      ),
                    )
                    .toList(),
                onSelected: (id) {
                  setState(() {
                    _source = _teachers.firstWhere((item) => item.id == id);
                    _target = null;
                    _preview = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownMenu<String>(
                key: ValueKey(_source?.id),
                width: fieldWidth,
                enabled: _source != null,
                enableFilter: true,
                enableSearch: true,
                label: const Text('Docente reemplazo'),
                dropdownMenuEntries: _targets
                    .map(
                      (item) =>
                          DropdownMenuEntry(value: item.id, label: _name(item)),
                    )
                    .toList(),
                onSelected: (id) {
                  setState(() {
                    _target = _targets.firstWhere((item) => item.id == id);
                    _preview = null;
                  });
                  _previewTransfer();
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Temporal')),
                  ButtonSegment(value: false, label: Text('Definitivo')),
                ],
                selected: {_temporary},
                onSelectionChanged: (value) =>
                    setState(() => _temporary = value.first),
              ),
              if (_temporary)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha prevista de regreso'),
                  subtitle: Text(
                    _endsAt == null
                        ? 'Sin seleccionar'
                        : '${_endsAt!.day}/${_endsAt!.month}/${_endsAt!.year}',
                  ),
                  trailing: TextButton(
                    onPressed: _pickEndDate,
                    child: const Text('Elegir'),
                  ),
                ),
              if (_loading) const LinearProgressIndicator(),
              if (_preview case final preview?) ...[
                const SizedBox(height: 12),
                Text(
                  'Impacto en ${preview.academicYear}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ...preview.impact.entries
                    .where((item) => item.value > 0)
                    .map(
                      (item) => Text(
                        '• ${labels[item.key] ?? item.key}: ${item.value}',
                      ),
                    ),
                if (preview.targetHasLoad)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _allowMerge,
                    title: const Text('Combinar con la carga existente'),
                    subtitle: const Text(
                      'Solo se habilita si no hay choques de horario o tutoría.',
                    ),
                    onChanged: preview.conflicts.isEmpty
                        ? (value) =>
                              setState(() => _allowMerge = value ?? false)
                        : null,
                  ),
                if (preview.conflicts.isNotEmpty)
                  ...preview.conflicts.map(
                    (item) => Text(
                      '• $item',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed:
              _loading ||
                  _preview == null ||
                  _preview!.conflicts.isNotEmpty ||
                  (_preview!.targetHasLoad && !_allowMerge)
              ? null
              : _execute,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Trasladar carga'),
        ),
      ],
    );
  }
}
