import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/schedule/subject_model.dart';
import '../../../models/user/userModelV2.dart';

// Extensión para capitalizar el texto de los días
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class SubjectFormDialog extends StatefulWidget {
  final SubjectModel? subjectToEdit;

  /// Ahora onSave devuelve Future<void> para poder esperar y bloquear el botón
  final Future<void> Function(SubjectModel subject) onSave;
  final List<UserModelV2> teachers;
  final List<String> daysOfWeek;

  const SubjectFormDialog({
    Key? key,
    this.subjectToEdit,
    required this.onSave,
    required this.teachers,
    required this.daysOfWeek,
  }) : super(key: key);

  @override
  _SubjectFormDialogState createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends State<SubjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _subjectNameController;
  String? _selectedTeacherId;
  String? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _errorMessage;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _subjectNameController = TextEditingController();

    if (widget.subjectToEdit != null) {
      _subjectNameController.text = widget.subjectToEdit!.subject;
      _selectedTeacherId = widget.subjectToEdit!.teacherId;
      _selectedDay = widget.subjectToEdit!.day;
      _startTime = TimeOfDay.fromDateTime(
        widget.subjectToEdit!.startTime.toDate(),
      );
      _endTime = TimeOfDay.fromDateTime(widget.subjectToEdit!.endTime.toDate());
    } else {
      _selectedDay = widget.daysOfWeek.first;
    }
  }

  @override
  void dispose() {
    _subjectNameController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveSubject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startTime == null ||
        _endTime == null ||
        _selectedTeacherId == null ||
        _selectedDay!.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, completa todos los campos.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _submitting = true;
    });

    final now = DateTime.now();
    final startTimeDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    final endTimeDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    final selectedTeacher = widget.teachers.firstWhere(
      (t) => t.id == _selectedTeacherId,
    );
    final teacherFullName =
        '${selectedTeacher.firstName} ${selectedTeacher.lastName}';

    final newSubject = SubjectModel(
      subject: _subjectNameController.text.trim(),
      day: _selectedDay,
      teacherId: _selectedTeacherId!,
      teacherName: teacherFullName,
      startTime: Timestamp.fromDate(startTimeDateTime),
      endTime: Timestamp.fromDate(endTimeDateTime),
      id: widget.subjectToEdit?.id ?? '',
      campusId: widget.subjectToEdit?.campusId ?? '',
      grade: widget.subjectToEdit?.grade ?? '',
      institutionId: widget.subjectToEdit?.institutionId ?? '',
    );

    try {
      await widget.onSave(newSubject);
      // el diálogo se cierra desde el padre si todo sale bien
    } catch (e) {
      // hubo error en el guardado (padre relanzó la excepción)
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'No se pudo guardar. Intenta nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bloquear cierre por back mientras se guarda
    return WillPopScope(
      onWillPop: () async => !_submitting,
      child: AlertDialog(
        title: Text(
          widget.subjectToEdit == null ? 'Crear materia' : 'Editar materia',
        ),
        content: SingleChildScrollView(
          child: AbsorbPointer(
            absorbing: _submitting, // evita editar durante el guardado
            child: Opacity(
              opacity: _submitting ? 0.6 : 1,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _subjectNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la materia',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa el nombre de la materia';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedTeacherId,
                      decoration: const InputDecoration(labelText: 'Profesor'),
                      items:
                          widget.teachers.map((teacher) {
                            return DropdownMenuItem<String>(
                              value: teacher.id,
                              child: Text(
                                '${teacher.firstName} ${teacher.lastName}',
                              ),
                            );
                          }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedTeacherId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor, selecciona un profesor';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (widget.daysOfWeek.length == 1) ...[
                      Builder(
                        builder: (_) {
                          _selectedDay ??= widget.daysOfWeek.first;
                          return TextFormField(
                            enabled: false,
                            initialValue: widget.daysOfWeek.first.capitalize(),
                            decoration: const InputDecoration(
                              labelText: 'Día de la semana',
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        value: _selectedDay,
                        decoration: const InputDecoration(
                          labelText: 'Día de la semana',
                        ),
                        items:
                            widget.daysOfWeek.map((day) {
                              return DropdownMenuItem<String>(
                                value: day,
                                child: Text(day.capitalize()),
                              );
                            }).toList(),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _selectedDay = value;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, selecciona un día';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _submitting ? null : () => _selectTime(true),
                            child: Text(
                              _startTime == null
                                  ? 'Hora de inicio'
                                  : _startTime!.format(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _submitting ? null : () => _selectTime(false),
                            child: Text(
                              _endTime == null
                                  ? 'Hora de fin'
                                  : _endTime!.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: _submitting ? null : _saveSubject,
            icon:
                _submitting
                    ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save),
            label: Text(_submitting ? 'Guardando...' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
