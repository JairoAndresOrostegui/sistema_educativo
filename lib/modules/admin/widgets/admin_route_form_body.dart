import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../../utils/format_utils.dart';

class AdminRouteFormBody extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nombreController;
  final TextEditingController direccionInicioController;
  final TextEditingController gestionadorController;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final TimeOfDay? horaInicio;
  final TimeOfDay? horaFin;

  final void Function(DateTime) onFechaInicioChanged;
  final void Function(DateTime) onFechaFinChanged;
  final void Function(TimeOfDay) onHoraInicioChanged;
  final void Function(TimeOfDay) onHoraFinChanged;

  final List<Map<String, dynamic>> estudiantesOrdenados;
  final void Function(Map<String, dynamic>) onAgregarEstudiante;
  final void Function(int, int) onReordenarEstudiante;
  final void Function(String) onEliminarEstudiante;

  final List<DocumentSnapshot> estudiantesDisponibles;
  final List<DocumentSnapshot> gestionadoresDisponibles;
  final void Function(DocumentSnapshot) onSeleccionarGestionador;

  const AdminRouteFormBody({
    super.key,
    required this.formKey,
    required this.nombreController,
    required this.direccionInicioController,
    required this.gestionadorController,
    required this.fechaInicio,
    required this.fechaFin,
    required this.horaInicio,
    required this.horaFin,
    required this.onFechaInicioChanged,
    required this.onFechaFinChanged,
    required this.onHoraInicioChanged,
    required this.onHoraFinChanged,
    required this.estudiantesOrdenados,
    required this.onAgregarEstudiante,
    required this.onReordenarEstudiante,
    required this.onEliminarEstudiante,
    required this.estudiantesDisponibles,
    required this.gestionadoresDisponibles,
    required this.onSeleccionarGestionador,
  });

  @override
  State<AdminRouteFormBody> createState() => _AdminRouteFormBodyState();
}

class _AdminRouteFormBodyState extends State<AdminRouteFormBody> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        children: [
          _buildField(widget.nombreController, 'Nombre de la ruta'),
          _buildField(widget.direccionInicioController, 'Dirección de inicio'),
          const SizedBox(height: 12),
          _buildFecha(
            context,
            'Fecha inicio',
            widget.fechaInicio,
            widget.onFechaInicioChanged,
          ),
          _buildFecha(
            context,
            'Fecha fin',
            widget.fechaFin,
            widget.onFechaFinChanged,
          ),
          _buildHora(
            context,
            'Hora inicio',
            widget.horaInicio,
            widget.onHoraInicioChanged,
          ),
          _buildHora(
            context,
            'Hora fin',
            widget.horaFin,
            widget.onHoraFinChanged,
          ),

          const SizedBox(height: 20),
          const Text(
            'Estudiantes asignados (orden de recogida)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTypeAheadEstudiantes(),
          const SizedBox(height: 8),
          _buildListaEstudiantes(),

          const SizedBox(height: 20),
          const Text(
            'Gestionador asignado',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTypeAheadGestionador(),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (widget.formKey.currentState?.validate() ?? false) {
                final errores = <String>[];

                if (widget.fechaInicio == null) errores.add('Fecha inicio');
                if (widget.fechaFin == null) errores.add('Fecha fin');
                if (widget.horaInicio == null) errores.add('Hora inicio');
                if (widget.horaFin == null) errores.add('Hora fin');
                if (widget.estudiantesOrdenados.isEmpty)
                  errores.add('Estudiantes asignados');
                if (widget.gestionadorController.text.trim().isEmpty)
                  errores.add('Gestionador');

                if (errores.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Faltan campos obligatorios: ${errores.join(', ')}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  Navigator.of(context).pop(true); // Marca validación exitosa
                }
              }
            },
            child: const Text('Validar formulario'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        label: label,
        hint: 'Campo de texto obligatorio',
        textField: true,
        child: TextFormField(
          controller: controller,
          validator:
              (value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Campo obligatorio'
                      : null,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFecha(
    BuildContext context,
    String label,
    DateTime? fecha,
    void Function(DateTime) onChanged,
  ) {
    return Row(
      children: [
        Expanded(child: Text('$label: ${FormatUtils.formatearFecha(fecha)}')),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () async {
            final seleccionada = await showDatePicker(
              context: context,
              initialDate: fecha ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (seleccionada != null) onChanged(seleccionada);
          },
        ),
      ],
    );
  }

  Widget _buildHora(
    BuildContext context,
    String label,
    TimeOfDay? hora,
    void Function(TimeOfDay) onChanged,
  ) {
    return Row(
      children: [
        Expanded(child: Text('$label: ${FormatUtils.formatearHora(hora)}')),
        IconButton(
          icon: const Icon(Icons.access_time),
          onPressed: () async {
            final seleccionada = await showTimePicker(
              context: context,
              initialTime: hora ?? TimeOfDay.now(),
            );
            if (seleccionada != null) onChanged(seleccionada);
          },
        ),
      ],
    );
  }

  Widget _buildTypeAheadEstudiantes() {
    return TypeAheadField<DocumentSnapshot>(
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Buscar estudiante',
            border: OutlineInputBorder(),
          ),
        );
      },
      suggestionsCallback: (pattern) {
        final texto = pattern.toLowerCase();
        return widget.estudiantesDisponibles.where((e) {
          final nombre = '${e['nombres']} ${e['apellidos']}'.toLowerCase();
          return nombre.contains(texto) &&
              !widget.estudiantesOrdenados.any((eo) => eo['id'] == e.id);
        }).toList();
      },
      itemBuilder: (context, suggestion) {
        return ListTile(
          title: Text('${suggestion['nombres']} ${suggestion['apellidos']}'),
        );
      },
      onSelected: (seleccionado) {
        final id = seleccionado.id;
        final yaExiste = widget.estudiantesOrdenados.any((e) => e['id'] == id);
        if (!yaExiste) {
          widget.onAgregarEstudiante({
            'id': id,
            'nombre': '${seleccionado['nombres']} ${seleccionado['apellidos']}',
          });
        }
      },
    );
  }

  Widget _buildListaEstudiantes() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ReorderableListView(
        onReorder: widget.onReordenarEstudiante,
        children:
            widget.estudiantesOrdenados.map((e) {
              return ListTile(
                key: ValueKey(e['id']),
                title: Text(e['nombre']),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => widget.onEliminarEstudiante(e['id']),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildTypeAheadGestionador() {
    return TypeAheadField<DocumentSnapshot>(
      controller: widget.gestionadorController,
      builder: (context, controller, focusNode) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          validator:
              (value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Campo obligatorio'
                      : null,
          decoration: const InputDecoration(
            labelText: 'Buscar gestionador',
            border: OutlineInputBorder(),
          ),
        );
      },
      suggestionsCallback: (pattern) {
        final texto = pattern.toLowerCase();
        return widget.gestionadoresDisponibles.where((u) {
          final nombre = '${u['nombres']} ${u['apellidos']}'.toLowerCase();
          return nombre.contains(texto);
        }).toList();
      },
      itemBuilder: (context, suggestion) {
        final nombre = '${suggestion['nombres']} ${suggestion['apellidos']}';
        return ListTile(title: Text(nombre));
      },
      onSelected: (suggestion) {
        final fullName = '${suggestion['nombres']} ${suggestion['apellidos']}';
        widget.gestionadorController.text = fullName;
        widget.onSeleccionarGestionador(suggestion);
      },
    );
  }
}
