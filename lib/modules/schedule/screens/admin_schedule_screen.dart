import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';
import 'package:provider/provider.dart';

import '../../../models/schedule/subject_model.dart';
import '../../../models/academic/academic_group.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../providers/user_provider_v2.dart';
import '../services/schedule_service.dart';
import '../../../utils/parameters_service.dart';
import '../../../utils/academic_group_service.dart';
import '../widgets/subject_form_dialog.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../widgets/admin/admin_grade_dropdown.dart';
import '../widgets/admin/admin_day_column.dart';

class ScheduleAdminScreen extends StatefulWidget {
  const ScheduleAdminScreen({super.key});

  @override
  State<ScheduleAdminScreen> createState() => _ScheduleAdminScreenState();
}

class _ScheduleAdminScreenState extends State<ScheduleAdminScreen> {
  final ParametersService _parametersService = ParametersService();
  final ScheduleService _scheduleService = ScheduleService();
  final AcademicGroupService _groupService = AcademicGroupService();

  String? _selectedGroupId;
  String _selectedDay = 'lunes';
  bool _isLoading = false;
  String? _loadError;
  List<userModelv2> _teachers = [];
  Map<String, List<SubjectModel>> _allSchedules = {};
  List<AcademicGroup> _availableGroups = [];
  List<InstitutionOption> _institutions = [];
  String? _selectedInstitution;
  String? _selectedCampus;
  final ScrollController _webScrollController = ScrollController();

  // Overlay bloqueante
  bool _blocking = false;
  String _blockingText = 'Procesando...';

  final List<String> _daysOfWeek = const [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
  ];

  bool _permite(String clave) {
    final u = context.read<UserProviderV2>().user;
    if (u == null) return false;
    if (u.isSuperadmin == true) return true;
    final funcs = u.permissions;
    return funcs.contains(clave);
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _webScrollController.dispose();
    super.dispose();
  }

  void _setBlocking(bool v, {String text = 'Procesando...'}) {
    if (!mounted) return;
    setState(() {
      _blocking = v;
      _blockingText = text;
    });
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = context.read<UserProviderV2>().user;
      if (currentUser != null) {
        var institutions = await _parametersService.getInstitutions();
        if (!currentUser.isSuperadmin) {
          institutions = institutions
              .where((item) => item.id == currentUser.institution)
              .toList();
        }
        _institutions = institutions;
        _selectedInstitution = currentUser.institution;
        _selectedCampus = currentUser.campus;
        _teachers = await _scheduleService.getTeachers(
          institutionId: _selectedInstitution!,
          campusId: _selectedCampus!,
        );
        _availableGroups = await _groupService.list(
          institutionId: _selectedInstitution!,
          campusId: _selectedCampus!,
        );
        _loadError = null;
      }
    } catch (e) {
      _loadError = 'No se pudieron cargar los docentes. $e';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadSchedulesForGroup(String? groupId) async {
    if (groupId == null) {
      setState(() {
        _selectedGroupId = null;
        _allSchedules = {};
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedGroupId = groupId;
    });

    try {
      final currentUser = context.read<UserProviderV2>().user;
      if (currentUser != null) {
        _allSchedules = await _scheduleService.getSchedulesForGroup(
          institutionId: _selectedInstitution ?? currentUser.institution,
          campusId: _selectedCampus ?? currentUser.campus,
          groupId: groupId,
        );
      }
    } catch (_) {}

    setState(() => _isLoading = false);
  }

  Future<void> _showCreateDialog(String day) async {
    if (_selectedGroupId == null) {
      await DialogUtils.showError(
        context: context,
        title: 'Selecciona grupo',
        message: 'Por favor, selecciona un grupo primero.',
      );
      return;
    }

    if (!_permite('horarios.crear')) {
      await DialogUtils.showError(
        context: context,
        title: 'Sin permiso',
        message: 'No tienes permiso para crear.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false, // bloquea cierre accidental
      builder: (context) {
        final dialogContext = context;
        return SubjectFormDialog(
          teachers: _teachers,
          daysOfWeek: [day],
          onSave: (SubjectModel newSubject) async {
            _setBlocking(true, text: 'Guardando materia...');
            try {
              final currentUser = context.read<UserProviderV2>().user;
              if (currentUser != null) {
                final subjectToSave = newSubject.copyWith(
                  institutionId:
                      _selectedInstitution ?? currentUser.institution,
                  campusId: _selectedCampus ?? currentUser.campus,
                  groupId: _selectedGroupId!,
                  groupName: _availableGroups
                      .firstWhere((group) => group.id == _selectedGroupId)
                      .name,
                  day: day,
                );

                await _scheduleService.createSubject(
                  subject: subjectToSave,
                  creator: currentUser,
                );
                await _loadSchedulesForGroup(_selectedGroupId);
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(); // cierra dialogo
              }
            } catch (e) {
              if (mounted && dialogContext.mounted) {
                // muestra error y relanza para que el dialogo quite su spinner
                await DialogUtils.showError(
                  context: dialogContext,
                  title: 'Error al guardar',
                  message: 'No se pudo guardar la materia. ($e)',
                );
              }
              rethrow;
            } finally {
              _setBlocking(false);
            }
          },
        );
      },
    );
  }

  void _showEditDialog(SubjectModel subject) {
    if (!_permite('horarios.editar')) {
      DialogUtils.showError(
        context: context,
        title: 'Sin permiso',
        message: 'No tienes permiso para editar.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final dialogContext = context;
        return SubjectFormDialog(
          subjectToEdit: subject,
          teachers: _teachers,
          daysOfWeek: _daysOfWeek,
          onSave: (SubjectModel updated) async {
            _setBlocking(true, text: 'Actualizando materia...');
            try {
              final currentUser = context.read<UserProviderV2>().user;
              if (currentUser != null) {
                final toUpdate = subject.copyWith(
                  subject: updated.subject,
                  teacherId: updated.teacherId,
                  teacherName: updated.teacherName,
                  day: updated.day,
                  startTime: updated.startTime,
                  endTime: updated.endTime,
                );

                await _scheduleService.editSubject(
                  oldSubject: subject,
                  newSubject: toUpdate,
                  editor: currentUser,
                );
                await _loadSchedulesForGroup(_selectedGroupId);
                if (mounted && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              }
            } catch (e) {
              if (mounted && dialogContext.mounted) {
                await DialogUtils.showError(
                  context: dialogContext,
                  title: 'Error',
                  message: 'Error al editar la materia. ($e)',
                );
              }
              rethrow;
            } finally {
              _setBlocking(false);
            }
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(SubjectModel subject) {
    if (!_permite('horarios.eliminar')) {
      DialogUtils.showError(
        context: context,
        title: 'Sin permiso',
        message: 'No tienes permiso para eliminar.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirmar eliminacion'),
        content: Text(
          'Estas seguro de que deseas eliminar la materia "${subject.subject}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              _setBlocking(true, text: 'Eliminando materia...');
              try {
                final currentUser = context.read<UserProviderV2>().user;
                if (currentUser != null) {
                  await _scheduleService.deleteSubject(
                    subject: subject,
                    remover: currentUser,
                  );
                  await _loadSchedulesForGroup(_selectedGroupId);
                  if (!mounted) return;
                  await DialogUtils.showSuccess(
                    context: context,
                    title: 'Exito',
                    message: 'Materia eliminada.',
                  );
                }
              } catch (e) {
                if (!mounted) return;
                await DialogUtils.showError(
                  context: context,
                  title: 'Error',
                  message: 'Error al eliminar la materia. ($e)',
                );
              } finally {
                _setBlocking(false);
              }
            },
            child: const Text('Si'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeTenant({
    required String institutionId,
    required String campusId,
  }) async {
    setState(() {
      _selectedInstitution = institutionId;
      _selectedCampus = campusId;
      _selectedGroupId = null;
      _allSchedules = {};
      _isLoading = true;
    });
    _teachers = await _scheduleService.getTeachers(
      institutionId: institutionId,
      campusId: campusId,
    );
    _availableGroups = await _groupService.list(
      institutionId: institutionId,
      campusId: campusId,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  InstitutionOption? get _selectedInstitutionOption {
    for (final institution in _institutions) {
      if (institution.id == _selectedInstitution) return institution;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<UserProviderV2>().user;
    if (currentUser == null) {
      return const Center(child: Text('Error: No se encontro el usuario.'));
    }

    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentUser.isSuperadmin && _institutions.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedInstitution,
                      decoration: const InputDecoration(
                        labelText: 'Institución',
                        border: OutlineInputBorder(),
                      ),
                      items: _institutions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        final institution = _institutions.firstWhere(
                          (item) => item.id == value,
                        );
                        final campus = institution.campuses.isEmpty
                            ? ''
                            : institution.campuses.first;
                        if (campus.isNotEmpty) {
                          _changeTenant(institutionId: value, campusId: campus);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        '${_selectedInstitution ?? ''}:${_selectedCampus ?? ''}',
                      ),
                      initialValue: _selectedCampus,
                      decoration: const InputDecoration(
                        labelText: 'Sede',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          (_selectedInstitutionOption?.campuses ??
                                  const <String>[])
                              .map(
                                (campus) => DropdownMenuItem(
                                  value: campus,
                                  child: Text(campus),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value == null || _selectedInstitution == null) {
                          return;
                        }
                        _changeTenant(
                          institutionId: _selectedInstitution!,
                          campusId: value,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            AdminGradeDropdown(
              selectedGroupId: _selectedGroupId,
              onChanged: _loadSchedulesForGroup,
              availableGroups: _availableGroups,
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppPalette.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  _loadError!,
                  style: TextStyle(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_selectedGroupId == null)
              const Expanded(
                child: Center(
                  child: Text('Selecciona un grado para ver el horario'),
                ),
              )
            else if (isDesktop)
              _buildWebLayout()
            else
              _buildMobileLayout(),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        title: const Text('Schedule management'),
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.primary,
        centerTitle: true,
        leading: const BackToDashboardButton(),
      ),
      body: Stack(
        children: [
          // bloquea interacciones cuando _blocking == true
          IgnorePointer(ignoring: _blocking, child: content),

          // overlay con spinner
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: _blocking
                ? Container(
                    key: const ValueKey('overlay'),
                    color: AppPalette.onSurface.withValues(alpha: 0.35),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.onSurface.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _blockingText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildWebLayout() {
    return Expanded(
      child: Scrollbar(
        controller: _webScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _webScrollController,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _daysOfWeek
                .map((day) => Expanded(child: _buildDayColumn(day)))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Expanded(
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _daysOfWeek.map((day) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: AppPalette.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => setState(() => _selectedDay = day),
                    child: Text(StringExtension(day).capitalize()),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [_buildDayColumn(_selectedDay)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(String day) {
    final subjects = List<SubjectModel>.from(_allSchedules[day] ?? [])
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return AdminDayColumn(
      day: day,
      subjects: subjects,
      canCreate: _selectedGroupId != null && _permite('horarios.crear'),
      canEdit: _permite('horarios.editar'),
      canDelete: _permite('horarios.eliminar'),
      onAddSubject: () => _showCreateDialog(day),
      onEditSubject: _showEditDialog,
      onDeleteSubject: _showDeleteConfirmationDialog,
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
