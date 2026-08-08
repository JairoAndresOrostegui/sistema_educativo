import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';
import 'package:provider/provider.dart';

import '../../../models/schedule/subject_model.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/format_utils.dart';
import '../services/schedule_service.dart';
import '../../../utils/navigation_utils.dart';
import '../../user/services/active_student_service.dart';

extension _Cap on String {
  String cap() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

String _displayDay(String day) {
  if (day.toLowerCase() == 'miercoles') return 'miércoles';
  return day.cap();
}

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  final _service = ScheduleService();

  bool _loading = false;
  Map<String, List<SubjectModel>> _byDay = {};
  String? _selectedDay;

  // Para rol Familiar
  List<userModelv2> _children = [];
  String? _activeStudentId;

  // Días usados en BD y en ScheduleService.getSchedulesForGrade
  final List<String> _days = const [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
  ];

  // Scroll para vista semanal en web
  final ScrollController _webScrollController = ScrollController();

  bool get _isWide => MediaQuery.of(context).size.width >= 900;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _webScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchedules({
    required String institutionId,
    required String campusId,
    required String groupId,
  }) async {
    final data = await _service.getSchedulesForGroup(
      institutionId: institutionId,
      campusId: campusId,
      groupId: groupId,
    );
    for (final d in data.keys) {
      data[d]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    final todayKey = _todayAsKey();
    if (!mounted) return;
    setState(() {
      _byDay = data;
      _selectedDay = _days.contains(todayKey) ? todayKey : _days.first;
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = context.read<UserProviderV2>().user;

      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Rol Estudiante
      if (user.role == 'Estudiante') {
        if (user.groupId == null || user.groupId!.isEmpty) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        await _fetchSchedules(
          institutionId: user.institution,
          campusId: user.campus,
          groupId: user.groupId!,
        );
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Rol Familiar
      if (user.role == 'Familiar') {
        final ids = user.studentIds ?? const <String>[];
        if (ids.isEmpty) {
          if (mounted) setState(() => _loading = false);
          return;
        }

        final kids = await _service.getUsersByIds(
          userIds: ids,
          institutionId: user.institution,
          campusId: user.campus,
        );

        if (!mounted) return;

        String initialId =
            user.activeStudentId ?? (kids.isNotEmpty ? kids.first.id : '');
        if (initialId.isEmpty || !kids.any((e) => e.id == initialId)) {
          initialId = kids.first.id;
        }

        _children = kids;
        _activeStudentId = initialId;
        await ActiveStudentService().select(
          userProvider: context.read<UserProviderV2>(),
          studentId: initialId,
        );

        final sel = _children.firstWhere((e) => e.id == _activeStudentId);
        final groupId = sel.groupId ?? '';

        if (groupId.isNotEmpty) {
          await _fetchSchedules(
            institutionId: user.institution,
            campusId: user.campus,
            groupId: groupId,
          );
        } else {
          _byDay = {};
          _selectedDay = _days.first;
        }

        if (mounted) setState(() => _loading = false);
        return;
      }

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible cargar el horario.')),
        );
      }
    }
  }

  Future<void> _onStudentChanged(String newId) async {
    if (_activeStudentId == newId) return;
    final previousId = _activeStudentId;
    setState(() {
      _activeStudentId = newId;
      _loading = true;
    });

    final userProv = context.read<UserProviderV2>();
    final u = userProv.user;
    if (u == null) return;
    try {
      await ActiveStudentService().select(
        userProvider: userProv,
        studentId: newId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeStudentId = previousId;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fue posible cambiar de estudiante.')),
      );
      return;
    }

    final sel = _children.firstWhere((e) => e.id == newId);
    final groupId = sel.groupId ?? '';
    if (groupId.isNotEmpty) {
      await _fetchSchedules(
        institutionId: u.institution,
        campusId: u.campus,
        groupId: groupId,
      );
    } else {
      setState(() {
        _byDay = {};
        _selectedDay = _days.first;
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  String _todayAsKey() {
    switch (DateTime.now().weekday) {
      case DateTime.monday:
        return 'lunes';
      case DateTime.tuesday:
        return 'martes';
      case DateTime.wednesday:
        return 'miercoles';
      case DateTime.thursday:
        return 'jueves';
      case DateTime.friday:
        return 'viernes';
      default:
        return 'lunes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProviderV2>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No hay sesión activa.')));
    }
    if (user.role != 'Estudiante' && user.role != 'Familiar') {
      return const Scaffold(
        body: Center(
          child: Text('Vista disponible solo para Estudiante o Familiar.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.primary,
        title: const Text('Mi horario'),
        centerTitle: true,
        leading: const BackToDashboardButton(),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    if (user.role == 'Familiar' && _children.isNotEmpty)
                      Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Semantics(
                            label: 'Seleccionar estudiante',
                            hint: 'Cambia el estudiante para ver su horario',
                            enabled: true,
                            focusable: true,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppPalette.primary.withValues(
                                    alpha: .15,
                                  ),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppPalette.primary.withValues(alpha: .06),
                                    AppPalette.surface,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppPalette.onSurface.withValues(
                                      alpha: 0.03,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _activeStudentId,
                                  isExpanded: true,
                                  hint: const Text('Estudiante'),
                                  items: _children
                                      .map(
                                        (e) => DropdownMenuItem<String>(
                                          value: e.id,
                                          child: Text(
                                            '${e.firstName} ${e.lastName} • ${e.groupName ?? '-'}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) _onStudentChanged(v);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _isWide ? _buildWeeklyGrid() : _buildDailyView(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ===== MOBILE: lista por día =====
  Widget _buildDailyView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _days.map((d) {
              final sel = d == _selectedDay;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  label: 'Día ${_displayDay(d)}',
                  button: true,
                  selected: sel,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: AppPalette.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => setState(() => _selectedDay = d),
                    child: Text(_displayDay(d)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DayList(
                key: ValueKey(_selectedDay),
                day: _selectedDay ?? _days.first,
                subjects: _byDay[_selectedDay] ?? const [],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===== WEB: malla semanal completa =====
  Widget _buildWeeklyGrid() {
    return Scrollbar(
      controller: _webScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _webScrollController,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _days
              .map(
                (d) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: _DayColumn(day: d, subjects: _byDay[d] ?? const []),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ================== SUBWIDGETS ==================

class _DayList extends StatelessWidget {
  final String day;
  final List<SubjectModel> subjects;

  const _DayList({super.key, required this.day, required this.subjects});

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return Center(child: Text('No hay clases el ${_displayDay(day)}.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: subjects.length,
      separatorBuilder: (context, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _SubjectCard(subject: subjects[i]),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final String day;
  final List<SubjectModel> subjects;

  const _DayColumn({required this.day, required this.subjects});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: .08),
            ),
            child: Semantics(
              header: true,
              label: 'Horario de ${_displayDay(day)}',
              child: Center(
                child: Text(
                  _displayDay(day),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.primary,
                  ),
                ),
              ),
            ),
          ),
          if (subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('Sin clases'),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: subjects.length,
              separatorBuilder: (context, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _SubjectCard(subject: subjects[i]),
            ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final SubjectModel subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    final rango = FormatUtils.formatHourRange(
      subject.startTime,
      subject.endTime,
    );
    final inicio = FormatUtils.formatearHoraDesdeTimestamp(subject.startTime);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.primary.withValues(alpha: .15)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppPalette.primary.withValues(alpha: .08),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Semantics(
        container: true,
        enabled: true,
        focusable: true,
        readOnly: true,
        label:
            'Clase: ${subject.subject}. Docente: ${subject.teacherName}. Horario: $rango.',
        child: ExcludeSemantics(
          child: ListTile(
            leading: _Badge(text: inicio),
            title: Text(
              subject.subject,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${subject.teacherName} · $rango'),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.primary.withValues(alpha: .25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppPalette.primary,
          fontSize: 12,
        ),
      ),
    );
  }
}
