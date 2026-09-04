import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/academic/academic_year.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/academic_year_service.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/parameters_service.dart';

class AcademicYearsAdminPanel extends StatefulWidget {
  const AcademicYearsAdminPanel({super.key});

  @override
  State<AcademicYearsAdminPanel> createState() =>
      _AcademicYearsAdminPanelState();
}

class _AcademicYearsAdminPanelState extends State<AcademicYearsAdminPanel> {
  final _service = AcademicYearService();
  final _parameters = ParametersService();
  List<InstitutionOption> _institutions = [];
  List<AcademicYear> _years = [];
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
    await _load();
  }

  Future<void> _load() async {
    if (_institutionId == null || _campusId == null) return;
    setState(() => _loading = true);
    try {
      final years = await _service.list(
        institutionId: _institutionId!,
        campusId: _campusId!,
      );
      if (mounted) setState(() => _years = years);
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No se pudieron consultar los años lectivos',
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _prepare() async {
    final active = _years.where((item) => item.status == 'active').firstOrNull;
    final controller = TextEditingController(
      text: '${(active?.year ?? DateTime.now().year) + 1}',
    );
    var cloneGroups = true;
    var cloneSchedules = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Preparar nuevo año lectivo'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Se crea primero como borrador. No cambia el año vigente '
                  'ni borra información.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Año'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: cloneGroups,
                  title: const Text('Copiar estructura de grupos'),
                  onChanged: (value) => setDialogState(() {
                    cloneGroups = value ?? false;
                    if (!cloneGroups) cloneSchedules = false;
                  }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: cloneSchedules,
                  title: const Text('Copiar horarios como borrador'),
                  subtitle: const Text(
                    'Luego deben revisarse docentes y conflictos.',
                  ),
                  onChanged: cloneGroups
                      ? (value) => setDialogState(
                          () => cloneSchedules = value ?? false,
                        )
                      : null,
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
              child: const Text('Preparar'),
            ),
          ],
        ),
      ),
    );
    final year = int.tryParse(controller.text.trim());
    controller.dispose();
    if (accepted != true || year == null) return;
    try {
      final result = await _service.prepare(
        institutionId: _institutionId!,
        campusId: _campusId!,
        year: year,
        cloneGroups: cloneGroups,
        cloneSchedules: cloneSchedules,
      );
      await _load();
      if (mounted) {
        await DialogUtils.showSuccess(
          context: context,
          title: 'Año $year preparado',
          message:
              'Se copiaron ${result['copiedGroups']} grupos y '
              '${result['copiedSchedules']} horarios.',
        );
      }
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No se pudo preparar el año',
          message: error.toString(),
        );
      }
    }
  }

  Future<void> _activate(AcademicYear year) async {
    final confirmation = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Activar ${year.year}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'El año vigente quedará cerrado y será de solo lectura. '
              'Esta operación no se ejecuta automáticamente el 1 de enero.',
            ),
            const SizedBox(height: 12),
            Text('Escribe ACTIVAR ${year.year} para confirmar.'),
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
              confirmation.text.trim() == 'ACTIVAR ${year.year}',
            ),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    confirmation.dispose();
    if (accepted != true) return;
    try {
      await _service.activate(year);
      await _load();
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No se pudo activar el año',
          message: error.toString(),
        );
      }
    }
  }

  InstitutionOption? get _institution =>
      _institutions.where((item) => item.id == _institutionId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProviderV2>().user!;
    final campuses = _institution?.campuses ?? const <String>[];
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
                    'Años lectivos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _prepare,
                  icon: const Icon(Icons.add),
                  label: const Text('Preparar siguiente'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'El año lectivo es universal para matrículas, horarios, '
              'mensajes, archivos, autorizaciones y rutas.',
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
                        _institutionId = value;
                        _campusId = _institutions
                            .firstWhere((item) => item.id == value)
                            .campuses
                            .firstOrNull;
                        await _load();
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
                        await _load();
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else
              ..._years.map(
                (year) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    year.status == 'active'
                        ? Icons.event_available
                        : year.status == 'closed'
                        ? Icons.history
                        : Icons.edit_calendar_outlined,
                  ),
                  title: Text('${year.year} · ${year.statusLabel}'),
                  subtitle: Text(
                    '${year.copiedGroups} grupos copiados · '
                    '${year.copiedSchedules} horarios copiados',
                  ),
                  trailing: year.status == 'draft'
                      ? FilledButton.tonal(
                          onPressed: () => _activate(year),
                          child: const Text('Activar'),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
