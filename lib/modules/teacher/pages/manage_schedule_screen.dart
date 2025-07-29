// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import '../../../models/materia_model.dart';
import '../../../services/schedule_service.dart';

class ManageScheduleScreen extends StatefulWidget {
  const ManageScheduleScreen({super.key});

  @override
  State<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends State<ManageScheduleScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes'];
  final _horarioService = HorarioService();

  Map<String, List<MateriaModel>> horario = {};
  String? grado;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _dias.length, vsync: this);
    _cargarHorario();
  }

  Future<void> _cargarHorario() async {
    final g = await _horarioService.obtenerGradoDelUsuario();
    if (g == null) return;
    final h = await _horarioService.obtenerHorario(g);
    setState(() {
      grado = g;
      horario = h;
      cargando = false;
    });
  }

  void _abrirFormulario({required String dia, int? index}) async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    TimeOfDay? horaInicio;
    TimeOfDay? horaFin;
    DocumentSnapshot? docenteSeleccionado;
    List<DocumentSnapshot> docentes = [];

    if (index != null) {
      final materia = horario[dia]![index];
      nombreCtrl.text = materia.materia;
      final inicio = materia.horaInicio.toDate();
      final fin = materia.horaFin.toDate();
      horaInicio = TimeOfDay.fromDateTime(inicio);
      horaFin = TimeOfDay.fromDateTime(fin);

      final docSnap = await FirebaseFirestore.instance.collection('usuarios').doc(materia.docenteId).get();
      docenteSeleccionado = docSnap.exists ? docSnap : null;
    }

    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('rol', isEqualTo: 'docente')
        .where('activo', isEqualTo: true)
        .get();
    docentes = snap.docs;

    final docenteTextController = TextEditingController(
      text: docenteSeleccionado != null
          ? '${docenteSeleccionado['nombres']} ${docenteSeleccionado['apellidos']}'
          : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(index == null ? 'Agregar materia' : 'Editar materia'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(labelText: 'Materia'),
                        validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildHora(setModalState, 'Hora de inicio', horaInicio, (h) => horaInicio = h),
                      _buildHora(setModalState, 'Hora de fin', horaFin, (h) => horaFin = h),
                      const SizedBox(height: 12),
                      // <----------------- INICIO DEL CAMBIO CLAVE ----------------->
                      // Se envuelve TypeAheadField en un FormField para habilitar la validación.
                      FormField<DocumentSnapshot>(
                        initialValue: docenteSeleccionado,
                        validator: (doc) => doc == null ? 'Seleccione un docente' : null,
                        builder: (FormFieldState<DocumentSnapshot> field) {
                          return TypeAheadField<DocumentSnapshot>(
                            builder: (context, controller, focusNode) {
                              return TextField(
                                controller: docenteTextController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Buscar docente',
                                  border: const OutlineInputBorder(),
                                  // Muestra el mensaje de error del FormField.
                                  errorText: field.errorText,
                                ),
                                onChanged: (value) {
                                  // Limpia la selección del docente si el texto cambia y no coincide con un docente seleccionado.
                                  // Esto es importante para que la validación funcione si el usuario borra el texto.
                                  if (docenteSeleccionado != null &&
                                      '${docenteSeleccionado?['nombres']} ${docenteSeleccionado?['apellidos']}'.toLowerCase() != value.toLowerCase()) {
                                    setModalState(() {
                                      docenteSeleccionado = null;
                                      field.didChange(null); // Notifica al FormField que el valor ha cambiado a nulo
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
                                final nombre = '${u['nombres']} ${u['apellidos']}'.toLowerCase();
                                return nombre.contains(texto);
                              }).toList();
                            },
                            itemBuilder: (context, doc) => ListTile(
                              title: Text('${doc['nombres']} ${doc['apellidos']}'),
                            ),
                            onSelected: (doc) {
                              setModalState(() {
                                docenteSeleccionado = doc;
                                docenteTextController.text =
                                    '${doc['nombres']} ${doc['apellidos']}';
                                field.didChange(doc); // ¡CRÍTICO! Notifica al FormField que el valor ha cambiado.
                              });
                            },
                          );
                        },
                      ),
                      // <------------------ FIN DEL CAMBIO CLAVE ------------------>
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final materia = MateriaModel(
                      materia: nombreCtrl.text,
                      horaInicio: Timestamp.fromDate(DateTime(2000, 1, 1, horaInicio!.hour, horaInicio!.minute)),
                      horaFin: Timestamp.fromDate(DateTime(2000, 1, 1, horaFin!.hour, horaFin!.minute)),
                      docenteId: docenteSeleccionado!.id,
                    );

                    if (index == null) {
                      await _horarioService.guardarMateria(grado: grado!, dia: dia, materia: materia);
                    } else {
                      await _horarioService.editarMateria(grado: grado!, dia: dia, index: index, nuevaMateria: materia);
                    }

                    Navigator.pop(ctx);
                    _cargarHorario();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHora(StateSetter setModalState, String label, TimeOfDay? hora, Function(TimeOfDay) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text('$label: ${hora != null ? hora.format(context) : 'No seleccionada'}'),
        ),
        IconButton(
          icon: const Icon(Icons.access_time),
          onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: hora ?? TimeOfDay.now());
            if (t != null) setModalState(() => onChanged(t));
          },
        ),
      ],
    );
  }

  Future<void> _eliminar(String dia, int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Deseas eliminar esta materia?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar == true) {
      await _horarioService.eliminarMateria(grado: grado!, dia: dia, index: index);
      _cargarHorario();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Horario Escolar', style: TextStyle(color: Colors.red)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _dias.map((d) => Tab(text: d.toUpperCase())).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _dias.map((dia) {
          final materias = [...(horario[dia] ?? [])]
            ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
          return Column(
            children: [
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _abrirFormulario(dia: dia),
                icon: const Icon(Icons.add),
                label: const Text('Agregar materia'),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: materias.length,
                  itemBuilder: (ctx, i) {
                    final m = materias[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.book),
                        title: Text(m.materia),
                        subtitle: Text(
                          '${DateFormat('HH:mm').format(m.horaInicio.toDate())} - ${DateFormat('HH:mm').format(m.horaFin.toDate())}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.green),
                              onPressed: () => _abrirFormulario(dia: dia, index: i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _eliminar(dia, i),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}