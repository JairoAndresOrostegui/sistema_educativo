// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sistema_educativo/services/schedule/schedule_service.dart';
import 'package:sistema_educativo/utils/format_utils.dart';
import 'package:sistema_educativo/models/user/user_model.dart';

import '../../../models/schedule/subject_model.dart';
import '../../../utils/grades_utils.dart';
import '../widget/admin/admin_subject_form_dialog.dart';
import '../widget/subject_tile.dart';

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
  String? gradoSeleccionado;
  bool cargando = false;

  final currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool esSuperadminActual = false;
  List<String> funcionalidadesActual = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _dias.length, vsync: this);
    _verificarPermisos();
  }

  Future<void> _verificarPermisos() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(currentUid)
            .get();
    if (!doc.exists) return;
    final user = UsuarioModel.fromFirestore(doc.data()!, doc.id);
    esSuperadminActual = user.esSuperadmin;
    funcionalidadesActual = user.funcionalidades;
    setState(() {});
  }

  Future<void> _cargarHorario(String grado) async {
    setState(() => cargando = true);
    final h = await _horarioService.obtenerHorario(grado);
    setState(() {
      gradoSeleccionado = grado;
      horario = h;
      cargando = false;
    });
  }

  Future<void> _eliminar(String dia, int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text('¿Deseas eliminar esta materia?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
    if (confirmar == true && gradoSeleccionado != null) {
      await _horarioService.eliminarMateria(
        grado: gradoSeleccionado!,
        dia: dia,
        index: index,
      );
      _cargarHorario(gradoSeleccionado!);
    }
  }

  bool get puedeCrear =>
      esSuperadminActual || funcionalidadesActual.contains('horarios.crear');

  bool get puedeEditar =>
      esSuperadminActual || funcionalidadesActual.contains('horarios.editar');

  bool get puedeEliminar =>
      esSuperadminActual || funcionalidadesActual.contains('horarios.eliminar');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Semantics(
          label: 'Pantalla de gestión del horario escolar',
          enabled: true,
          focusable: true,
          child: const Text('School schedule'),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.redAccent),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Semantics(
            label: 'Selector de grado',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                value: gradoSeleccionado,
                items:
                    gradosColombia
                        .where((g) => g != 'No aplica')
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                decoration: const InputDecoration(
                  labelText: 'Seleccionar grado',
                  border: OutlineInputBorder(),
                ),
                onChanged: (valor) {
                  if (valor != null) {
                    _cargarHorario(valor);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (gradoSeleccionado != null)
            Semantics(
              label: 'Navegación por días de la semana',
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: _dias.map((d) => Tab(text: d.toUpperCase())).toList(),
              ),
            ),
          Expanded(
            child:
                gradoSeleccionado == null
                    ? const Center(child: Text('Seleccione un grado'))
                    : cargando
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                      controller: _tabController,
                      children:
                          _dias.map((dia) {
                            final materias = [...(horario[dia] ?? [])]..sort(
                              (a, b) => a.horaInicio.compareTo(b.horaInicio),
                            );
                            return Column(
                              children: [
                                const SizedBox(height: 20),
                                if (puedeCrear)
                                  Semantics(
                                    label:
                                        'Botón para agregar materia el día $dia',
                                    button: true,
                                    focusable: true,
                                    enabled: true,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          () => showSubjectFormDialog(
                                            context,
                                            dia: dia,
                                            grado: gradoSeleccionado!,
                                            horario: horario,
                                            onSave:
                                                () => _cargarHorario(
                                                  gradoSeleccionado!,
                                                ),
                                          ),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Agregar materia'),
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: materias.length,
                                    itemBuilder: (ctx, i) {
                                      final m = materias[i];
                                      return Semantics(
                                        label:
                                            'Materia ${m.materia} de ${FormatUtils.formatearHora(FormatUtils.timeOfDayDesdeTimestamp(m.horaInicio))} a ${FormatUtils.formatearHora(FormatUtils.timeOfDayDesdeTimestamp(m.horaFin))}',
                                        child: SubjectTile(
                                          materia: m,
                                          index: i,
                                          dia: dia,
                                          onEdit:
                                              puedeEditar
                                                  ? () => showSubjectFormDialog(
                                                    context,
                                                    dia: dia,
                                                    index: i,
                                                    grado: gradoSeleccionado!,
                                                    horario: horario,
                                                    onSave:
                                                        () => _cargarHorario(
                                                          gradoSeleccionado!,
                                                        ),
                                                  )
                                                  : null,
                                          onDelete:
                                              puedeEliminar
                                                  ? () => _eliminar(dia, i)
                                                  : null,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }
}
