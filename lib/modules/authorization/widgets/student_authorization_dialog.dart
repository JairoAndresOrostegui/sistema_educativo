import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final CreateAuthorizationResult? initialValue;
  const AuthorizationCreateDialog({
    super.key,
    required this.children,
    this.initialStudentId,
    this.initialValue,
  });

  @override
  State<AuthorizationCreateDialog> createState() =>
      _AuthorizationCreateDialogState();
}

class _AuthorizationCreateDialogState extends State<AuthorizationCreateDialog> {
  static const String _supportEmail =
      'liceobilinguerodolfollinaspd@gmail.com';
  static const String _supportPhoneDigits = '573168706758';

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
    final initial = widget.initialValue;
    if (initial != null) {
      _studentId = initial.studentId;
      _allDay = initial.allDay;
      _multiDay = initial.multiDay;
      _dateFrom = initial.dateFrom;
      _dateTo = initial.dateTo;
      if (initial.startTime != null) {
        _startTod = TimeOfDay.fromDateTime(initial.startTime!);
      }
      if (initial.endTime != null) {
        _endTod = TimeOfDay.fromDateTime(initial.endTime!);
      }
      _reasonCtrl.text = initial.reason;
    } else {
      final now = DateTime.now();
      _dateFrom = DateTime(now.year, now.month, now.day);
    }
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

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$_supportPhoneDigits');
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  Future<void> _openEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
    );
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  String _studentLabel(StudentChoice student) {
    return '${student.fullName} - ${student.grade}';
  }

  Widget _buildDateField({
    required String label,
    required String text,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return TextFormField(
      readOnly: true,
      enabled: enabled,
      controller: TextEditingController(text: text),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 560;
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
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Dialog(
          insetPadding: EdgeInsets.fromLTRB(
            16,
            24,
            16,
            16 + media.padding.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight:
                  media.size.height -
                  media.viewInsets.bottom -
                  media.padding.top -
                  media.padding.bottom -
                  40,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Column(
                children: [
                  const Text(
                    'Nueva solicitud de autorizacion',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(bottom: 8 + media.padding.bottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _studentId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Estudiante',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                widget.children
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(
                                          _studentLabel(c),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            selectedItemBuilder:
                                (context) =>
                                    widget.children
                                        .map(
                                          (c) => Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _studentLabel(c),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                            onChanged: (v) => setState(() => _studentId = v),
                          ),
                          const SizedBox(height: 10),
                          if (isCompact) ...[
                            SwitchListTile(
                              value: _allDay,
                              activeThumbColor: Colors.redAccent,
                              onChanged: (v) => setState(() => _allDay = v),
                              title: const Text('Todo el dia'),
                              contentPadding: EdgeInsets.zero,
                            ),
                            SwitchListTile(
                              value: _multiDay,
                              activeThumbColor: Colors.redAccent,
                              onChanged:
                                  (v) => setState(() {
                                    _multiDay = v;
                                    if (!v) _dateTo = null;
                                  }),
                              title: const Text('Varios dias'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: SwitchListTile(
                                    value: _allDay,
                                    activeThumbColor: Colors.redAccent,
                                    onChanged:
                                        (v) => setState(() => _allDay = v),
                                    title: const Text('Todo el dia'),
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
                                    title: const Text('Varios dias'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),
                          if (isCompact) ...[
                            _buildDateField(
                              label: 'Desde',
                              text: fromText,
                              enabled: true,
                              onTap: () => _pickDate(context, true),
                            ),
                            const SizedBox(height: 10),
                            _buildDateField(
                              label: 'Hasta',
                              text: toText,
                              enabled: _multiDay,
                              onTap:
                                  _multiDay
                                      ? () => _pickDate(context, false)
                                      : null,
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    label: 'Desde',
                                    text: fromText,
                                    enabled: true,
                                    onTap: () => _pickDate(context, true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildDateField(
                                    label: 'Hasta',
                                    text: toText,
                                    enabled: _multiDay,
                                    onTap:
                                        _multiDay
                                            ? () => _pickDate(context, false)
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),
                          if (isCompact) ...[
                            _buildDateField(
                              label: 'Hora inicio',
                              text: startText,
                              enabled: !_allDay,
                              onTap:
                                  _allDay ? null : () => _pickTime(context, true),
                            ),
                            const SizedBox(height: 10),
                            _buildDateField(
                              label: 'Hora fin',
                              text: endText,
                              enabled: !_allDay,
                              onTap:
                                  _allDay ? null : () => _pickTime(context, false),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    label: 'Hora inicio',
                                    text: startText,
                                    enabled: !_allDay,
                                    onTap:
                                        _allDay
                                            ? null
                                            : () => _pickTime(context, true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildDateField(
                                    label: 'Hora fin',
                                    text: endText,
                                    enabled: !_allDay,
                                    onTap:
                                        _allDay
                                            ? null
                                            : () => _pickTime(context, false),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _reasonCtrl,
                            minLines: 3,
                            maxLines: 6,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              labelText: 'Motivo',
                              alignLabelWithHint: true,
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
                              border: Border.all(
                                color: Colors.red.withValues(alpha: .15),
                              ),
                              color: Colors.red.withValues(alpha: .06),
                            ),
                            child: const Text(
                              'Debes enviar la evidencia del motivo por los canales oficiales. WhatsApp: +573168706758. Correo institucional: liceobilinguerodolfollinaspd@gmail.com.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (isCompact) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openWhatsApp,
                                icon: const Icon(Icons.chat),
                                label: const Text('Abrir WhatsApp'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openEmail,
                                icon: const Icon(Icons.email_outlined),
                                label: const Text('Abrir correo'),
                              ),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _openWhatsApp,
                                    icon: const Icon(Icons.chat),
                                    label: const Text('Abrir WhatsApp'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _openEmail,
                                    icon: const Icon(Icons.email_outlined),
                                    label: const Text('Abrir correo'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          onPressed: () {
                            if (_studentId == null ||
                                _dateFrom == null ||
                                _reasonCtrl.text.trim().isEmpty) {
                              return;
                            }
                            final startDt =
                                _allDay ? null : _toDateTime(_dateFrom!, _startTod);
                            final endDt =
                                _allDay ? null : _toDateTime(_dateFrom!, _endTod);
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
