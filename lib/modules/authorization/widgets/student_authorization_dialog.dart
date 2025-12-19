import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentChoice {
  final String id;
  final String fullName;
  final String grade;
  const StudentChoice({
    required this.id,
    required this.fullName,
    required this.grade,
  });
}

class CreateAuthorizationResult {
  final String studentId;
  final bool allDay;
  final bool multiDay;
  final DateTime dateFrom;
  final DateTime? dateTo;
  final DateTime? startTime;
  final DateTime? endTime;
  final String reason;
  const CreateAuthorizationResult({
    required this.studentId,
    required this.allDay,
    required this.multiDay,
    required this.dateFrom,
    this.dateTo,
    this.startTime,
    this.endTime,
    required this.reason,
  });
}

class AuthorizationCreateDialog extends StatefulWidget {
  final List<StudentChoice> children;
  final String? initialStudentId;
  const AuthorizationCreateDialog({
    super.key,
    required this.children,
    this.initialStudentId,
  });

  @override
  State<AuthorizationCreateDialog> createState() =>
      _AuthorizationCreateDialogState();
}

class _AuthorizationCreateDialogState extends State<AuthorizationCreateDialog> {
  String? _studentId;
  bool _allDay = true;
  bool _multiDay = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  TimeOfDay? _startTod;
  TimeOfDay? _endTod;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.children.isNotEmpty) {
      final exists = widget.children.any(
        (c) => c.id == widget.initialStudentId,
      );
      _studentId = exists ? widget.initialStudentId : widget.children.first.id;
    }
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext ctx, bool from) async {
    final now = DateTime.now();
    final initial = from ? (_dateFrom ?? now) : (_dateTo ?? _dateFrom ?? now);
    final picked = await showDatePicker(
      context: ctx,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime(now.year + 1),
      initialDate: initial,
    );
    if (picked != null) {
      setState(() {
        if (from) {
          _dateFrom = DateTime(picked.year, picked.month, picked.day);
          if (_multiDay && (_dateTo == null || _dateTo!.isBefore(_dateFrom!))) {
            _dateTo = _dateFrom;
          }
        } else {
          _dateTo = DateTime(picked.year, picked.month, picked.day);
        }
      });
    }
  }

  Future<void> _pickTime(BuildContext ctx, bool start) async {
    final nowTod = TimeOfDay.now();
    final initial = start ? (_startTod ?? nowTod) : (_endTod ?? nowTod);
    final picked = await showTimePicker(context: ctx, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (start) {
          _startTod = picked;
        } else {
          _endTod = picked;
        }
      });
    }
  }

  DateTime? _toDateTime(DateTime base, TimeOfDay? tod) {
    if (tod == null) return null;
    return DateTime(base.year, base.month, base.day, tod.hour, tod.minute);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final tf = DateFormat('HH:mm');
    final fromText = _dateFrom == null ? '' : df.format(_dateFrom!);
    final toText = _dateTo == null ? '' : df.format(_dateTo!);
    final startText =
        _startTod == null
            ? ''
            : tf.format(_toDateTime(_dateFrom ?? DateTime.now(), _startTod)!);
    final endText =
        _endTod == null
            ? ''
            : tf.format(_toDateTime(_dateFrom ?? DateTime.now(), _endTod)!);

    final themed = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: Colors.redAccent,
        secondary: Colors.redAccent,
      ),
    );

    return Theme(
      data: themed,
      child: AlertDialog(
        title: const Center(
          child: Text(
            'Nueva solicitud de autorización',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _studentId,
                decoration: const InputDecoration(
                  labelText: 'Estudiante',
                  border: OutlineInputBorder(),
                ),
                items:
                    widget.children
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.fullName} • ${c.grade}'),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _studentId = v),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      value: _allDay,
                      activeThumbColor: Colors.redAccent,
                      onChanged: (v) => setState(() => _allDay = v),
                      title: const Text('Todo el día'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      value: _multiDay,
                      activeThumbColor: Colors.redAccent,
                      onChanged:
                          (v) => setState(() {
                            _multiDay = v;
                            if (!v) _dateTo = null;
                          }),
                      title: const Text('Varios días'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Desde',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: fromText),
                      onTap: () => _pickDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      enabled: _multiDay,
                      decoration: const InputDecoration(
                        labelText: 'Hasta',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: toText),
                      onTap: _multiDay ? () => _pickDate(context, false) : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      enabled: !_allDay,
                      decoration: const InputDecoration(
                        labelText: 'Hora inicio',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: startText),
                      onTap: _allDay ? null : () => _pickTime(context, true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      enabled: !_allDay,
                      decoration: const InputDecoration(
                        labelText: 'Hora fin',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: endText),
                      onTap: _allDay ? null : () => _pickTime(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _reasonCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: .15)),
                  color: Colors.red.withValues(alpha: .06),
                ),
                child: const Text(
                  'Debes enviar la evidencia del motivo por los canales oficiales (WhatsApp y correo institucional).',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () {
              if (_studentId == null ||
                  _dateFrom == null ||
                  _reasonCtrl.text.trim().isEmpty) {
                return;
              }
              final startDt =
                  _allDay ? null : _toDateTime(_dateFrom!, _startTod);
              final endDt = _allDay ? null : _toDateTime(_dateFrom!, _endTod);
              final res = CreateAuthorizationResult(
                studentId: _studentId!,
                allDay: _allDay,
                multiDay: _multiDay,
                dateFrom: _dateFrom!,
                dateTo: _multiDay ? _dateTo ?? _dateFrom! : null,
                startTime: startDt,
                endTime: endDt,
                reason: _reasonCtrl.text.trim(),
              );
              Navigator.pop(context, res);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}
