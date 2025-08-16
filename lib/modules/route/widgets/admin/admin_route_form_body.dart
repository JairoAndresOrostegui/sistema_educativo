import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../../../utils/format_utils.dart';

class AdminRouteFormBody extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController startAddressController;
  final TextEditingController managerController;
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  final void Function(DateTime) onStartDateChanged;
  final void Function(DateTime) onEndDateChanged;
  final void Function(TimeOfDay) onStartTimeChanged;
  final void Function(TimeOfDay) onEndTimeChanged;

  final List<Map<String, dynamic>> orderedStudents;
  final void Function(Map<String, dynamic>) onAddStudent;
  final void Function(int, int) onReorderStudent;
  final void Function(String) onRemoveStudent;

  final List<DocumentSnapshot<Map<String, dynamic>>> availableStudents;
  final List<DocumentSnapshot<Map<String, dynamic>>> availableManagers;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onSelectManager;

  const AdminRouteFormBody({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.startAddressController,
    required this.managerController,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.orderedStudents,
    required this.onAddStudent,
    required this.onReorderStudent,
    required this.onRemoveStudent,
    required this.availableStudents,
    required this.availableManagers,
    required this.onSelectManager,
  });

  @override
  State<AdminRouteFormBody> createState() => _AdminRouteFormBodyState();
}

class _AdminRouteFormBodyState extends State<AdminRouteFormBody> {
  // Controller que entrega TypeAheadField para el campo de gestionador (solo UI)
  TextEditingController? _managerFieldCtrl;

  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red.withOpacity(.25)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Colors.redAccent, width: 1.4),
    ),
    isDense: true,
  );

  BoxDecoration _box() => BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.red.withOpacity(.15)),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.red.withOpacity(.06), Colors.white],
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Semantics(
              label: 'Nombre de la ruta',
              textField: true,
              child: TextFormField(
                controller: widget.nameController,
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Campo obligatorio'
                            : null,
                decoration: _input('Nombre de la ruta'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Semantics(
              label: 'Dirección de inicio',
              textField: true,
              child: TextFormField(
                controller: widget.startAddressController,
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Campo obligatorio'
                            : null,
                decoration: _input('Dirección de inicio'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          _fechaRow(
            context,
            'Fecha inicio',
            widget.startDate,
            widget.onStartDateChanged,
          ),
          _fechaRow(
            context,
            'Fecha fin',
            widget.endDate,
            widget.onEndDateChanged,
          ),
          _horaRow(
            context,
            'Hora inicio',
            widget.startTime,
            widget.onStartTimeChanged,
          ),
          _horaRow(
            context,
            'Hora fin',
            widget.endTime,
            widget.onEndTimeChanged,
          ),

          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Estudiantes asignados (orden de recogida)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.redAccent.shade200,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _typeAheadStudents(),
          const SizedBox(height: 8),
          _studentList(),

          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Gestionador asignado',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.redAccent.shade200,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _typeAheadManager(),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (widget.formKey.currentState?.validate() ?? false) {
                final missing = <String>[];
                if (widget.startDate == null) missing.add('Fecha inicio');
                if (widget.endDate == null) missing.add('Fecha fin');
                if (widget.startTime == null) missing.add('Hora inicio');
                if (widget.endTime == null) missing.add('Hora fin');
                if (widget.orderedStudents.isEmpty) {
                  missing.add('Estudiantes asignados');
                }
                if (widget.managerController.text.trim().isEmpty) {
                  missing.add('Gestionador');
                }

                if (missing.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Faltan campos obligatorios: ${missing.join(', ')}',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Formulario completo y válido'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Validar formulario'),
          ),
        ],
      ),
    );
  }

  Widget _fechaRow(
    BuildContext context,
    String label,
    DateTime? fecha,
    void Function(DateTime) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _box(),
      child: Row(
        children: [
          Expanded(child: Text('$label: ${FormatUtils.formatearFecha(fecha)}')),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.redAccent),
            onPressed: () async {
              final sel = await showDatePicker(
                context: context,
                initialDate: fecha ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (sel != null) onChanged(sel);
            },
          ),
        ],
      ),
    );
  }

  Widget _horaRow(
    BuildContext context,
    String label,
    TimeOfDay? hora,
    void Function(TimeOfDay) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _box(),
      child: Row(
        children: [
          Expanded(child: Text('$label: ${FormatUtils.formatearHora(hora)}')),
          IconButton(
            icon: const Icon(Icons.access_time, color: Colors.redAccent),
            onPressed: () async {
              final sel = await showTimePicker(
                context: context,
                initialTime: hora ?? TimeOfDay.now(),
              );
              if (sel != null) onChanged(sel);
            },
          ),
        ],
      ),
    );
  }

  Widget _typeAheadStudents() {
    return Container(
      decoration: _box(),
      padding: const EdgeInsets.all(8),
      child: TypeAheadField<DocumentSnapshot<Map<String, dynamic>>>(
        builder: (context, controller, focusNode) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: _input('Buscar estudiante'),
          );
        },
        suggestionsCallback: (pattern) {
          final q = pattern.toLowerCase();
          return widget.availableStudents.where((e) {
            final data = e.data() ?? {};
            final name =
                '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                    .toLowerCase();
            final id = e.id;
            final already = widget.orderedStudents.any((s) => s['id'] == id);
            return name.contains(q) && !already;
          }).toList();
        },
        itemBuilder: (context, suggestion) {
          final d = suggestion.data() ?? {};
          return ListTile(
            title: Text('${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'),
          );
        },
        onSelected: (sel) {
          final id = sel.id;
          final d = sel.data() ?? {};
          widget.onAddStudent({
            'id': id,
            'nombre': '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}',
          });
        },
      ),
    );
  }

  Widget _studentList() {
    return Container(
      height: 220,
      decoration: _box(),
      child: ReorderableListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        onReorder: widget.onReorderStudent,
        children:
            widget.orderedStudents
                .map(
                  (e) => ListTile(
                    key: ValueKey(e['id']),
                    title: Text(e['nombre']),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => widget.onRemoveStudent(e['id']),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _typeAheadManager() {
    return Container(
      decoration: _box(),
      padding: const EdgeInsets.all(8),
      child: TypeAheadField<DocumentSnapshot<Map<String, dynamic>>>(
        builder: (context, controller, focusNode) {
          // guardo referencia al controller interno para poder actualizar el texto
          _managerFieldCtrl ??= controller;

          // si venimos a EDITAR y ya hay un nombre cargado en managerController,
          // lo reflejo en el campo visible
          if (controller.text != widget.managerController.text) {
            controller.text = widget.managerController.text;
          }

          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Campo obligatorio'
                        : null,
            decoration: _input('Buscar gestionador'),
          );
        },
        suggestionsCallback: (pattern) {
          final q = pattern.toLowerCase();
          return widget.availableManagers.where((u) {
            final d = u.data() ?? {};
            final name =
                '${(d['firstName'] ?? '').toString()} ${(d['lastName'] ?? '').toString()}'
                    .toLowerCase();
            return name.contains(q);
          }).toList();
        },
        itemBuilder: (context, suggestion) {
          final d = suggestion.data() ?? {};
          final name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}';
          return ListTile(title: Text(name));
        },
        onSelected: (suggestion) {
          final d = suggestion.data() ?? {};
          final fullName = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}';

          // actualizo el texto visible
          _managerFieldCtrl?.text = fullName;

          // y el controller que usas para guardar/validar
          widget.managerController.text = fullName;

          // callback externo (id del manager seleccionado)
          widget.onSelectManager(suggestion);
        },
      ),
    );
  }
}
