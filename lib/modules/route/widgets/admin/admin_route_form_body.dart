import 'package:flutter/material.dart';
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

  final List<Map<String, dynamic>> availableStudents;
  final List<Map<String, dynamic>> availableManagers;
  final void Function(Map<String, dynamic>) onSelectManager;

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

  InputDecoration _input(BuildContext context, String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.4,
      ),
    ),
    isDense: true,
  );

  BoxDecoration _box(BuildContext context) => BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    boxShadow: [
      BoxShadow(
        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: Offset(0, 6),
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
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Semantics(
              label: 'Nombre de la ruta',
              textField: true,
              child: TextFormField(
                controller: widget.nameController,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obligatorio'
                    : null,
                decoration: _input(context, 'Nombre de la ruta'),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Semantics(
              label: 'Dirección de inicio',
              textField: true,
              child: TextFormField(
                controller: widget.startAddressController,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obligatorio'
                    : null,
                decoration: _input(context, 'Dirección de inicio'),
              ),
            ),
          ),
          SizedBox(height: 12),

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

          SizedBox(height: 16),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Estudiantes asignados (orden de recogida)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: 8),
          _typeAheadStudents(context),
          SizedBox(height: 8),
          _studentList(context),

          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Gestionador asignado',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: 8),
          _typeAheadManager(context),
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
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _box(context),
      child: Row(
        children: [
          Expanded(child: Text('$label: ${FormatUtils.formatearFecha(fecha)}')),
          IconButton(
            icon: Icon(
              Icons.calendar_today,
              color: Theme.of(context).colorScheme.primary,
            ),
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
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _box(context),
      child: Row(
        children: [
          Expanded(child: Text('$label: ${FormatUtils.formatearHora(hora)}')),
          IconButton(
            icon: Icon(
              Icons.access_time,
              color: Theme.of(context).colorScheme.primary,
            ),
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

  Widget _typeAheadStudents(BuildContext context) {
    return Container(
      decoration: _box(context),
      padding: EdgeInsets.all(8),
      child: TypeAheadField<Map<String, dynamic>>(
        builder: (context, controller, focusNode) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: _input(context, 'Buscar estudiante'),
          );
        },
        suggestionsCallback: (pattern) {
          final q = pattern.toLowerCase();
          return widget.availableStudents.where((e) {
            final data = e;
            final name =
                '${(data['firstName'] ?? '').toString()} ${(data['lastName'] ?? '').toString()}'
                    .toLowerCase();
            final id = e['id'];
            final already = widget.orderedStudents.any((s) => s['id'] == id);
            return name.contains(q) && !already;
          }).toList();
        },
        itemBuilder: (context, suggestion) {
          final d = suggestion;
          return ListTile(
            title: Text('${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'),
          );
        },
        onSelected: (sel) {
          final id = sel['id'];
          final d = sel;
          widget.onAddStudent({
            'id': id,
            'nombre': '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}',
          });
        },
      ),
    );
  }

  Widget _studentList(BuildContext context) {
    return Container(
      height: 220,
      decoration: _box(context),
      child: ReorderableListView(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        onReorderItem: widget.onReorderStudent,
        children: widget.orderedStudents
            .map(
              (e) => ListTile(
                key: ValueKey(e['id']),
                title: Text(e['nombre']),
                trailing: IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => widget.onRemoveStudent(e['id']),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _typeAheadManager(BuildContext context) {
    return Container(
      decoration: _box(context),
      padding: EdgeInsets.all(8),
      child: TypeAheadField<Map<String, dynamic>>(
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
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            decoration: _input(context, 'Buscar gestionador'),
          );
        },
        suggestionsCallback: (pattern) {
          final q = pattern.toLowerCase();
          return widget.availableManagers.where((u) {
            final d = u;
            final name =
                '${(d['firstName'] ?? '').toString()} ${(d['lastName'] ?? '').toString()}'
                    .toLowerCase();
            return name.contains(q);
          }).toList();
        },
        itemBuilder: (context, suggestion) {
          final d = suggestion;
          final name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}';
          return ListTile(title: Text(name));
        },
        onSelected: (suggestion) {
          final d = suggestion;
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
