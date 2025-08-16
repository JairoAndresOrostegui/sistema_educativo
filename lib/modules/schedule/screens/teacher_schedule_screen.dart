import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/schedule/subject_model.dart';
import '../../../providers/user_provider_V2.dart';
import '../../../utils/format_utils.dart';
import '../services/schedule_service.dart';
import '../../../utils/parameters_service.dart';

extension _Cap on String {
  String cap() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  final _schedule = ScheduleService();
  final _params = ParametersService();

  bool _loading = false;
  String? _selectedKey;
  List<String> _grades = [];
  Map<String, List<SubjectModel>> _byDay = {};
  String _selectedDay = 'lunes';

  final List<String> _daysOfWeek = const [
    'lunes',
    'martes',
    'miércoles',
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
      final params = await _params.getGrades();
      _grades =
          params
              .map((e) => e.valor.trim())
              .where((g) => g.toLowerCase() != 'no aplica')
              .toList();

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
        _byDay = await _schedule.getSchedulesForGrade(
          institutionId: user.institution,
          campusId: user.campus,
          grade: key,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Horario docente'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _FilterBar(
                grades: _grades,
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
            children:
                _daysOfWeek
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
              children:
                  _daysOfWeek.map((day) {
                    final sel = _selectedDay == day;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                        label: 'Día ${day.cap()}',
                        button: true,
                        selected: sel,
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
                          child: Text(day.cap()),
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
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _FilterBar({
    required this.grades,
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
            value: selected,
            hint: const Text('Selecciona un grado'),
            isExpanded: true,
            items:
                items
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
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
            decoration: BoxDecoration(color: Colors.red.withOpacity(.08)),
            child: Semantics(
              header: true,
              label: 'Horario de ${day.cap()}',
              child: Center(
                child: Text(
                  day.cap(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.redAccent,
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
              separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    final grado = subject.grade ?? '-';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(.15)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.redAccent.withOpacity(.06),
            Theme.of(context).colorScheme.surface,
          ],
        ),
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
        color: Colors.redAccent.withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withOpacity(.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.redAccent,
          fontSize: 12,
        ),
      ),
    );
  }
}
