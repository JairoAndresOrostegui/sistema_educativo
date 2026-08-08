import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/academic/academic_group.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/academic_group_service.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/parameters_service.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final user = context.read<UserProviderV2>().user!;
    _institutionId = user.institution;
    _campusId = user.campus;
    _institutions = await _parameters.getInstitutions();
    await _loadGroups();
  }

  Future<void> _loadGroups() async {
    if (_institutionId == null || _campusId == null) return;
    setState(() => _loading = true);
    try {
      final groups = await _service.list(
        institutionId: _institutionId!,
        campusId: _campusId!,
        activeOnly: false,
      );
      if (mounted) setState(() => _groups = groups);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([AcademicGroup? group]) async {
    final level = TextEditingController(text: group?.level);
    final section = TextEditingController(text: group?.section ?? 'A');
    final order = TextEditingController(text: '${group?.order ?? 0}');
    var active = group?.active ?? true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(group == null ? 'Nuevo grupo' : 'Editar grupo'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: level,
                  decoration: const InputDecoration(
                    labelText: 'Nivel (ejemplo: Cuarto)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: section,
                  decoration: const InputDecoration(
                    labelText: 'Sección (ejemplo: A)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Orden'),
                ),
                if (group != null)
                  SwitchListTile(
                    value: active,
                    title: const Text('Grupo activo'),
                    onChanged: (value) => setDialogState(() => active = value),
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      if (group == null) {
        await _service.create(
          institutionId: _institutionId!,
          campusId: _campusId!,
          level: level.text.trim(),
          section: section.text.trim(),
          order: int.tryParse(order.text) ?? 0,
        );
      } else {
        await _service.update(
          id: group.id,
          level: level.text.trim(),
          section: section.text.trim(),
          order: int.tryParse(order.text) ?? group.order,
          active: active,
        );
      }
      await _loadGroups();
    } catch (error) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'No se pudo guardar el grupo',
        message: error.toString(),
      );
    } finally {
      level.dispose();
      section.dispose();
      order.dispose();
    }
  }

  Future<void> _delete(AcademicGroup group) async {
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
        message: error.toString(),
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
    final user = context.watch<UserProviderV2>().user!;
    if (!user.isSuperadmin && !user.permissions.contains('usuarios.editar')) {
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
                  onPressed: _loading ? null : _openForm,
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
                        onPressed: () => _openForm(group),
                        onDeleted: () => _delete(group),
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

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
