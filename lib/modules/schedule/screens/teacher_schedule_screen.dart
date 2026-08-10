import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';
import 'package:provider/provider.dart';

import '../../../models/schedule/subject_model.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/format_utils.dart';
import '../services/schedule_service.dart';
import '../../../utils/navigation_utils.dart';

extension _Cap on String {
  String cap() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

String _displayDay(String day) {
  if (day.toLowerCase() == 'miercoles') return 'miércoles';
  return day.cap();
}

class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  final _schedule = ScheduleService();
  bool _loading = false;
  String? _selectedKey;
  List<String> _grades = [];
  final Map<String, String> _groupLabels = {};
  Map<String, List<SubjectModel>> _byDay = {};
  String _selectedDay = 'lunes';

  final List<String> _daysOfWeek = const [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
  ];

  final ScrollController _webScrollController = ScrollController();

  bool get _isDesktop => MediaQuery.of(context).size.width > 600;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _webScrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final user = context.read<UserProviderV2>().user;
      final assignedGroupId = user?.groupId?.trim() ?? '';
      final assignedGroupName = user?.groupName?.trim() ?? '';
      _grades = assignedGroupId.isEmpty ? [] : [assignedGroupId];
      if (assignedGroupId.isNotEmpty) {
        _groupLabels[assignedGroupId] = assignedGroupName;
      }

      _selectedKey = 'My schedule';
      await _loadSchedulesForSelection(_selectedKey!);
    } catch (_) {
      // Capturar error.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSchedulesForSelection(String key) async {
    final user = context.read<UserProviderV2>().user;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      if (key == 'My schedule') {
        _byDay = await _schedule.getSchedulesForTeacher(
          institutionId: user.institution,
          campusId: user.campus,
          teacherId: user.id,
        );
      } else {
        _byDay = await _schedule.getSchedulesForGroup(
          institutionId: user.institution,
          campusId: user.campus,
          groupId: key,
        );
      }
      if (!_daysOfWeek.contains(_selectedDay)) _selectedDay = 'lunes';
    } catch (_) {
      _byDay = {};
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProviderV2>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No hay sesión activa.')));
    }

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        title: const Text('Horario docente'),
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.primary,
        centerTitle: true,
        leading: const BackToDashboardButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _FilterBar(
                grades: _grades,
                groupLabels: _groupLabels,
                selected: _selectedKey,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedKey = v);
                  _loadSchedulesForSelection(v);
                },
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_isDesktop)
                _buildWebLayout()
              else
                _buildMobileLayout(),
            ],
          ),
        ),
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
                .map(
                  (day) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: _DayColumn(
                        day: day,
                        subjects: _byDay[day] ?? const [],
                      ),
                    ),
                  ),
                )
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
                final sel = _selectedDay == day;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Semantics(
                    label: 'Día ${_displayDay(day)}',
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
                      onPressed: () => setState(() => _selectedDay = day),
                      child: Text(_displayDay(day)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: _DayColumn(
                day: _selectedDay,
                subjects: _byDay[_selectedDay] ?? const [],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<String> grades;
  final Map<String, String> groupLabels;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _FilterBar({
    required this.grades,
    required this.groupLabels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = ['My schedule', ...grades];
    return Semantics(
      label: 'Seleccionar grado o ver mi horario',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.primary.withValues(alpha: .15)),
          color: AppPalette.surfaceContainer,
          boxShadow: [
            BoxShadow(
              color: AppPalette.onSurface.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected,
            hint: const Text('Selecciona un grado'),
            isExpanded: true,
            items: items
                .map(
                  (g) => DropdownMenuItem(
                    value: g,
                    child: Text(groupLabels[g] ?? g),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
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
              child: Text('No hay materias para este día.'),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: subjects.length,
              separatorBuilder: (context, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _TeacherSubjectItem(subject: subjects[i]),
            ),
        ],
      ),
    );
  }
}

class _TeacherSubjectItem extends StatelessWidget {
  final SubjectModel subject;
  const _TeacherSubjectItem({required this.subject});

  @override
  Widget build(BuildContext context) {
    final rango = FormatUtils.formatHourRange(
      subject.startTime,
      subject.endTime,
    );
    final grado = subject.groupName;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.primary.withValues(alpha: .15)),
        color: AppPalette.surfaceContainer,
      ),
      child: Semantics(
        container: true,
        readOnly: true,
        label: 'Materia: ${subject.subject}. Grado: $grado. Horario: $rango.',
        child: ExcludeSemantics(
          child: ListTile(
            leading: _GradeBadge(text: grado),
            title: Text(
              subject.subject,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(rango),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  final String text;
  const _GradeBadge({required this.text});

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
