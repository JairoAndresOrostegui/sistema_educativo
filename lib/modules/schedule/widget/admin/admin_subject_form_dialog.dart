import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:sistema_educativo/services/schedule/schedule_service.dart';
import 'package:sistema_educativo/utils/format_utils.dart';
import '../../../../models/schedule/subject_model.dart';
import '../../../../services/notification/notification_service.dart';

Future<void> showSubjectFormDialog(
  BuildContext context, {
  required String dia,
  int? index,
  required Map<String, List<MateriaModel>> horario,
  required String grado,
  required VoidCallback onSave,
}) async {
  final horarioService = HorarioService();
  final formKey = GlobalKey<FormState>();
  final nombreCtrl = TextEditingController();
  TimeOfDay? horaInicio;
  TimeOfDay? horaFin;
  DocumentSnapshot? docenteSeleccionado;
  int? indexReal;

  if (index != null) {
    final materiasOriginal = horario[dia]!;
    final materiasOrdenadas = [...materiasOriginal]
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    final materiaOrdenada = materiasOrdenadas[index];
    indexReal = materiasOriginal.indexOf(materiaOrdenada);

    final materia = materiasOriginal[indexReal];
    nombreCtrl.text = materia.materia;
    horaInicio = FormatUtils.timeOfDayDesdeTimestamp(materia.horaInicio);
    horaFin = FormatUtils.timeOfDayDesdeTimestamp(materia.horaFin);
    docenteSeleccionado = await horarioService.obtenerDocentePorId(
      materia.docenteId,
    );
  }

  final docentes = await horarioService.obtenerDocentesActivos();

  final docenteTextController = TextEditingController(
    text:
        docenteSeleccionado != null
            ? '${docenteSeleccionado['nombres']} ${docenteSeleccionado['apellidos']}'
            : '',
  );

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Semantics(
              label:
                  index == null
                      ? 'Agregar materia al horario'
                      : 'Editar materia del horario',
              enabled: true,
              focusable: true,
              child: Text(index == null ? 'Agregar materia' : 'Editar materia'),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: 'Campo para escribir el nombre de la materia',
                      enabled: true,
                      focusable: true,
                      child: TextFormField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(labelText: 'Materia'),
                        validator:
                            (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildHora(
                      context,
                      setModalState,
                      'Hora de inicio',
                      horaInicio,
                      (h) => horaInicio = h,
                    ),
                    _buildHora(
                      context,
                      setModalState,
                      'Hora de fin',
                      horaFin,
                      (h) => horaFin = h,
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: 'Buscar y seleccionar docente',
                      enabled: true,
                      focusable: true,
                      child: FormField<DocumentSnapshot>(
                        initialValue: docenteSeleccionado,
                        validator:
                            (doc) =>
                                doc == null ? 'Seleccione un docente' : null,
                        builder: (FormFieldState<DocumentSnapshot> field) {
                          return TypeAheadField<DocumentSnapshot>(
                            builder: (context, controller, focusNode) {
                              return TextField(
                                controller: docenteTextController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Buscar docente',
                                  border: const OutlineInputBorder(),
                                  errorText: field.errorText,
                                ),
                                onChanged: (value) {
                                  if (docenteSeleccionado != null &&
                                      '${docenteSeleccionado?['nombres']} ${docenteSeleccionado?['apellidos']}'
                                              .toLowerCase() !=
                                          value.toLowerCase()) {
                                    setModalState(() {
                                      docenteSeleccionado = null;
                                      field.didChange(null);
                                    });
                                  } else if (value.isEmpty) {
                                    setModalState(() {
                                      docenteSeleccionado = null;
                                      field.didChange(null);
                                    });
                                  }
                                },
                              );
                            },
                            suggestionsCallback: (pattern) {
                              final texto = pattern.toLowerCase();
                              return docentes.where((u) {
                                final nombre =
                                    '${u['nombres']} ${u['apellidos']}'
                                        .toLowerCase();
                                return nombre.contains(texto);
                              }).toList();
                            },
                            itemBuilder:
                                (context, doc) => Semantics(
                                  label:
                                      'Docente: ${doc['nombres']} ${doc['apellidos']}',
                                  child: ListTile(
                                    title: Text(
                                      '${doc['nombres']} ${doc['apellidos']}',
                                    ),
                                  ),
                                ),
                            onSelected: (doc) {
                              setModalState(() {
                                docenteSeleccionado = doc;
                                docenteTextController.text =
                                    '${doc['nombres']} ${doc['apellidos']}';
                                field.didChange(doc);
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Semantics(
                label: 'Cancelar sin guardar cambios',
                enabled: true,
                focusable: true,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
              ),
              Semantics(
                label: 'Guardar cambios en el horario',
                enabled: true,
                focusable: true,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final materia = MateriaModel(
                      materia: nombreCtrl.text,
                      horaInicio: FormatUtils.timestampDesdeHora(horaInicio)!,
                      horaFin: FormatUtils.timestampDesdeHora(horaFin)!,
                      docenteId: docenteSeleccionado!.id,
                    );

                    if (index == null) {
                      await horarioService.guardarMateria(
                        grado: grado,
                        dia: dia,
                        materia: materia,
                      );
                    } else {
                      await horarioService.editarMateria(
                        grado: grado,
                        dia: dia,
                        index: indexReal!,
                        nuevaMateria: materia,
                      );
                    }

                    try {
                      final snap =
                          await FirebaseFirestore.instance
                              .collection('usuarios')
                              .where('grado', isEqualTo: grado)
                              .where('rol', isEqualTo: 'estudiante')
                              .where('estado', isEqualTo: 'activo')
                              .get();

                      print('📦 Usuarios encontrados: ${snap.docs.length}');

                      final tokens =
                          snap.docs
                              .map((d) => d.data()['fcmTokens'])
                              .whereType<List>()
                              .expand((list) => list)
                              .whereType<String>()
                              .where((token) => token.trim().isNotEmpty)
                              .toList();

                      print('📬 Tokens válidos: $tokens');

                      if (tokens.isNotEmpty) {
                        await enviarNotificacion(
                          tokens: tokens,
                          grado: grado,
                          titulo: '📚 Horario actualizado',
                          cuerpo:
                              'Se ha actualizado el horario del grado $grado.',
                        );
                        print('✅ Notificación enviada');
                      } else {
                        print(
                          '! No hay tokens válidos, no se envía notificación',
                        );
                      }
                    } catch (e) {
                      print('❌ Error al enviar notificación: $e');
                    }

                    Navigator.pop(ctx);
                    onSave();
                  },
                  child: const Text('Guardar'),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildHora(
  BuildContext context,
  StateSetter setModalState,
  String label,
  TimeOfDay? hora,
  Function(TimeOfDay) onChanged,
) {
  return Semantics(
    label: '$label: ${FormatUtils.formatearHora(hora)}',
    enabled: true,
    focusable: true,
    child: Row(
      children: [
        Expanded(child: Text('$label: ${FormatUtils.formatearHora(hora)}')),
        IconButton(
          icon: const Icon(Icons.access_time),
          onPressed: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: hora ?? TimeOfDay.now(),
            );
            if (t != null) setModalState(() => onChanged(t));
          },
        ),
      ],
    ),
  );
}
