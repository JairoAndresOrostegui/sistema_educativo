import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/academic/academic_group.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/academic_group_service.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/parameters_service.dart';
import '../../../utils/user_facing_error.dart';

class AcademicGroupsAdminPanel extends StatefulWidget {
  const AcademicGroupsAdminPanel({super.key});

  @override
  State<AcademicGroupsAdminPanel> createState() =>
      _AcademicGroupsAdminPanelState();
}

class _AcademicGroupsAdminPanelState extends State<AcademicGroupsAdminPanel> {
  final _service = AcademicGroupService();
  final _parameters = ParametersService();
  List<InstitutionOption> _institutions = [];
  List<AcademicGroup> _groups = [];
  String? _institutionId;
  String? _campusId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final user = context.read<UserProviderV2>().user;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Tu sesión no está disponible. Inicia sesión nuevamente.';
        });
      }
      return;
    }
    try {
      _institutionId = user.institution;
      _campusId = user.campus;
      if (user.isSuperadmin) {
        _institutions = await _parameters.getInstitutions();
      } else {
        _institutions = [
          InstitutionOption(
            id: user.institution,
            label: user.institution,
            campuses: [user.campus],
          ),
        ];
      }
      await _loadGroups();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = userFacingError(
            error,
            fallback: 'No se pudieron consultar los grupos.',
          );
        });
      }
    }
  }

  Future<void> _loadGroups() async {
    if ((_institutionId ?? '').isEmpty || (_campusId ?? '').isEmpty) {
      setState(() {
        _groups = [];
        _loading = false;
        _error = 'Selecciona una institución y una sede válidas.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await _service.listForAdministration(
        institutionId: _institutionId!,
        campusId: _campusId!,
      );
      if (mounted) setState(() => _groups = groups);
    } catch (error) {
      if (mounted) {
        setState(() {
          _groups = [];
          _error = userFacingError(
            error,
            fallback: 'No se pudieron consultar los grupos.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([AcademicGroup? group]) async {
    final level = TextEditingController(text: group?.level);
    final section = TextEditingController(text: group?.section ?? 'A');
    final order = TextEditingController(text: '${group?.order ?? 0}');
    var active = group?.active ?? true;
    final formKey = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(group == null ? 'Nuevo grupo' : 'Editar grupo'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: level,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Nivel (ejemplo: Cuarto)',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Escribe el nivel.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: section,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Sección (ejemplo: A)',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Escribe la sección.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Orden'),
                    validator: (value) {
                      final parsed = int.tryParse((value ?? '').trim());
                      if (parsed == null) return 'Escribe un número entero.';
                      if (parsed < 0 || parsed > 10000) {
                        return 'Usa un valor entre 0 y 10000.';
                      }
                      return null;
                    },
                  ),
                  if (group != null)
                    SwitchListTile(
                      value: active,
                      title: const Text('Grupo activo'),
                      onChanged: (value) =>
                          setDialogState(() => active = value),
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
    if (accepted != true) {
      level.dispose();
      section.dispose();
      order.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      if (group == null) {
        await _service.create(
          institutionId: _institutionId!,
          campusId: _campusId!,
          level: level.text.trim(),
          section: section.text.trim(),
          order: int.parse(order.text.trim()),
        );
      } else {
        await _service.update(
          id: group.id,
          level: level.text.trim(),
          section: section.text.trim(),
          order: int.parse(order.text.trim()),
          active: active,
          expectedRevision: group.revision,
        );
      }
      await _loadGroups();
    } catch (error) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'No se pudo guardar el grupo',
        message: userFacingError(error),
      );
    } finally {
      level.dispose();
      section.dispose();
      order.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(AcademicGroup group) async {
    if (group.active) return;
    Map<String, dynamic> result;
    try {
      result = await _service.deleteImpact(group.id);
    } catch (error) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'No se pudo revisar el impacto',
        message: userFacingError(error),
      );
      return;
    }
    if (!mounted) return;
    final impact = Map<String, dynamic>.from(
      result['impact'] as Map? ?? const <String, dynamic>{},
    );
    final references =
        <String, String>{
              'users': 'estudiantes',
              'tutors': 'docentes directores de grupo',
              'schedules': 'horarios y asignaturas',
              'authorizations': 'autorizaciones',
              'channels': 'canales acad\u00e9micos',
              'serviceChannels': 'canales de servicio',
              'files': 'publicaciones de archivos',
              'enrollments': 'matr\u00edculas',
            }.entries
            .map(
              (entry) => MapEntry(
                entry.value,
                (impact[entry.key] as num?)?.toInt() ?? 0,
              ),
            )
            .where((entry) => entry.value > 0)
            .toList();
    if (references.isNotEmpty) {
      await DialogUtils.showError(
        context: context,
        title: 'El grupo est\u00e1 protegido',
        message:
            'No se puede eliminar porque conserva informaci\u00f3n institucional:\n'
            '${references.map((entry) => '${entry.key}: ${entry.value}').join('\n')}\n\n'
            'Debe permanecer inactivo para conservar el historial.',
      );
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text(
          'Se eliminará ${group.name} solo si no tiene usuarios, horarios, '
          'matrículas, autorizaciones ni archivos vinculados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await _service.delete(group.id);
      await _loadGroups();
    } catch (error) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'El grupo está protegido',
        message: userFacingError(error),
      );
    }
  }

  InstitutionOption? get _selectedInstitution {
    for (final item in _institutions) {
      if (item.id == _institutionId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProviderV2>().user;
    if (user == null) return const SizedBox.shrink();
    final canEdit =
        user.isSuperadmin || user.permissions.contains('parametros.editar');
    final canView = canEdit || user.permissions.contains('parametros.ver');
    if (!canView) {
      return const SizedBox.shrink();
    }
    final campuses = _selectedInstitution?.campuses ?? const <String>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Grupos académicos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading || _saving || !canEdit ? null : _openForm,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo grupo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Los grupos son independientes por sede: Cuarto A y Cuarto B '
              'pueden coexistir sin mezclar información.',
            ),
            if (user.isSuperadmin) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _institutionId,
                      decoration: const InputDecoration(
                        labelText: 'Institución',
                      ),
                      items: _institutions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        final institution = _institutions.firstWhere(
                          (item) => item.id == value,
                        );
                        _institutionId = value;
                        _campusId = institution.campuses.firstOrNull;
                        await _loadGroups();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('$_institutionId:$_campusId'),
                      initialValue: _campusId,
                      decoration: const InputDecoration(labelText: 'Sede'),
                      items: campuses
                          .map(
                            (campus) => DropdownMenuItem(
                              value: campus,
                              child: Text(campus),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        _campusId = value;
                        await _loadGroups();
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else if (_error != null)
              _ParameterLoadError(message: _error!, onRetry: _loadGroups)
            else if (_groups.isEmpty)
              const Text('No hay grupos configurados en esta sede.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _groups
                    .map(
                      (group) => InputChip(
                        avatar: Icon(
                          group.active
                              ? Icons.school_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        label: Text(group.name),
                        onPressed: canEdit && !_saving
                            ? () => _openForm(group)
                            : null,
                        onDeleted: canEdit && user.isSuperadmin && !group.active
                            ? (_saving ? null : () => _delete(group))
                            : null,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParameterLoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ParameterLoadError({required this.message, required this.onRetry});

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

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
