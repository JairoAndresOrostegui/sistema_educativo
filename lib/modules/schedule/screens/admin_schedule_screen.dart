import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/schedule/subject_model.dart';
import '../../../models/user/userModelV2.dart';
import '../../../providers/user_provider_V2.dart';
import '../services/schedule_service.dart';
import '../../../utils/parameters_service.dart';
import '../widgets/subject_form_dialog.dart';

class GradeDropdown extends StatelessWidget {
  final String? selectedGrade;
  final Function(String?) onChanged;
  final List<String> availableGrades;

  const GradeDropdown({
    Key? key,
    required this.selectedGrade,
    required this.onChanged,
    required this.availableGrades,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.red.withOpacity(.15)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.red.withOpacity(.06), Colors.white],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedGrade,
          hint: const Text('Selecciona un grado'),
          isExpanded: true,
          items:
              availableGrades
                  .map(
                    (String grade) => DropdownMenuItem<String>(
                      value: grade,
                      child: Text(grade),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class SubjectItem extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showEdit;
  final bool showDelete;

  const SubjectItem({
    Key? key,
    required this.subject,
    required this.onEdit,
    required this.onDelete,
    this.showEdit = true,
    this.showDelete = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(.15)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.red.withOpacity(.06), Colors.white],
        ),
      ),
      child: ListTile(
        title: Text(
          subject.subject,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${TimeOfDay.fromDateTime(subject.startTime.toDate()).format(context)} '
          'to ${TimeOfDay.fromDateTime(subject.endTime.toDate()).format(context)} • ${subject.teacherName}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showEdit)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: onEdit,
              ),
            if (showDelete)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class ScheduleAdminScreen extends StatefulWidget {
  const ScheduleAdminScreen({Key? key}) : super(key: key);

  @override
  State<ScheduleAdminScreen> createState() => _ScheduleAdminScreenState();
}

class _ScheduleAdminScreenState extends State<ScheduleAdminScreen> {
  final ParametersService _parametersService = ParametersService();
  final ScheduleService _scheduleService = ScheduleService();

  String? _selectedGrade;
  String _selectedDay = 'lunes';
  bool _isLoading = false;
  List<UserModelV2> _teachers = [];
  Map<String, List<SubjectModel>> _allSchedules = {};
  List<String> _availableGrades = [];
  final ScrollController _webScrollController = ScrollController();

  // Overlay bloqueante
  bool _blocking = false;
  String _blockingText = 'Procesando...';

  final List<String> _daysOfWeek = const [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
  ];

  bool _permite(String clave) {
    final u = context.read<UserProviderV2>().user;
    if (u == null) return false;
    if (u.isSuperadmin == true) return true;
    final funcs = u.permissions ?? <String>[];
    return funcs.contains(clave);
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadAvailableGradesFromParametersService();
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

  Future<void> _loadAvailableGradesFromParametersService() async {
    setState(() => _isLoading = true);
    try {
      final parameters = await _parametersService.getGrades();
      final grades =
          parameters
              .map((p) => p.valor.trim())
              .where((g) => g.toLowerCase() != 'no aplica')
              .toList();
      setState(() => _availableGrades = grades);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = context.read<UserProviderV2>().user;
      if (currentUser != null) {
        _teachers = await _scheduleService.getTeachers(
          institutionId: currentUser.institution,
          campusId: currentUser.campus,
        );
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _loadSchedulesForGrade(String? grade) async {
    if (grade == null) {
      setState(() {
        _selectedGrade = null;
        _allSchedules = {};
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedGrade = grade;
    });

    try {
      final currentUser = context.read<UserProviderV2>().user;
      if (currentUser != null) {
        _allSchedules = await _scheduleService.getSchedulesForGrade(
          institutionId: currentUser.institution,
          campusId: currentUser.campus,
          grade: grade,
        );
      }
    } catch (_) {}

    setState(() => _isLoading = false);
  }

  void _showCreateDialog(String day) {
    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona un grado primero.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!_permite('horarios.crear')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para crear.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false, // bloquea cierre accidental
      builder: (context) {
        return SubjectFormDialog(
          teachers: _teachers,
          daysOfWeek: [day],
          onSave: (SubjectModel newSubject) async {
            _setBlocking(true, text: 'Guardando materia...');
            try {
              final currentUser = context.read<UserProviderV2>().user;
              if (currentUser != null) {
                final subjectToSave = newSubject.copyWith(
                  institutionId: currentUser.institution,
                  campusId: currentUser.campus,
                  grade: _selectedGrade!,
                  day: day,
                );

                await _scheduleService.createSubject(
                  subject: subjectToSave,
                  creator: currentUser,
                );
                await _loadSchedulesForGrade(_selectedGrade);
                if (context.mounted)
                  Navigator.of(context).pop(); // cierra diálogo
              }
            } catch (e) {
              // muestra error y relanza para que el diálogo quite su spinner
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error al guardar la materia. Inténtalo de nuevo. ($e)',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para editar.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
                await _loadSchedulesForGrade(_selectedGrade);
                if (context.mounted) Navigator.of(context).pop();
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error al editar la materia. ($e)')),
              );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para eliminar.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            title: const Text('Confirmar Eliminación'),
            content: Text(
              '¿Estás seguro de que deseas eliminar la materia "${subject.subject}"?',
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
                      await _loadSchedulesForGrade(_selectedGrade);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Materia eliminada.')),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al eliminar la materia. ($e)'),
                      ),
                    );
                  } finally {
                    _setBlocking(false);
                  }
                },
                child: const Text('Sí'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<UserProviderV2>().user;
    if (currentUser == null) {
      return const Center(child: Text('Error: No se encontró el usuario.'));
    }

    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradeDropdown(
              selectedGrade: _selectedGrade,
              onChanged: (String? newGrade) => _loadSchedulesForGrade(newGrade),
              availableGrades: _availableGrades,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_selectedGrade == null)
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Schedule management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // bloquea interacciones cuando _blocking == true
          IgnorePointer(ignoring: _blocking, child: content),

          // overlay con spinner
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child:
                _blocking
                    ? Container(
                      key: const ValueKey('overlay'),
                      color: Colors.black.withOpacity(0.35),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
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
            children:
                _daysOfWeek
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
              children:
                  _daysOfWeek.map((day) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
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
    final subjects = _allSchedules[day] ?? [];
    subjects.sort((a, b) => a.startTime.compareTo(b.startTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              StringExtension(day).capitalize(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withOpacity(.15)),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.red.withOpacity(.06), Colors.white],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child:
                subjects.isEmpty
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No hay materias para este día.'),
                      ),
                    )
                    : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: subjects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder:
                          (_, i) => SubjectItem(
                            subject: subjects[i],
                            onEdit: () => _showEditDialog(subjects[i]),
                            onDelete:
                                () =>
                                    _showDeleteConfirmationDialog(subjects[i]),
                            showEdit: _permite('horarios.editar'),
                            showDelete: _permite('horarios.eliminar'),
                          ),
                    ),
          ),
        ),
        if (_selectedGrade != null && _permite('horarios.crear'))
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () => _showCreateDialog(day),
              child: const Text('Agregar materia'),
            ),
          ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
