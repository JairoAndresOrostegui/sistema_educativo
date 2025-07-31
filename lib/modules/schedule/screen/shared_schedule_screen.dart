import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/schedule/subject_model.dart';
import 'package:sistema_educativo/services/schedule/schedule_service.dart';
import 'package:sistema_educativo/utils/format_utils.dart';
import '../../../utils/grades_utils.dart';
import '../../auth/providers/user_provider.dart';

class SharedScheduleScreen extends StatefulWidget {
  const SharedScheduleScreen({super.key});

  @override
  State<SharedScheduleScreen> createState() => _SharedScheduleScreenState();
}

class _SharedScheduleScreenState extends State<SharedScheduleScreen>
    with TickerProviderStateMixin {
  final HorarioService _horarioService = HorarioService();
  String? gradoSeleccionado;
  Map<String, List<MateriaModel>> horario = {};
  final _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes'];
  late TabController _tabController;
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _dias.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UsuarioProvider>(context, listen: false).usuario;
      if (user?.rol == 'estudiante') {
        setState(() {
          gradoSeleccionado = user?.grado;
        });
        _cargarHorario(user?.grado ?? '');
      }
    });
  }

  Future<void> _cargarHorario(String grado) async {
    setState(() => cargando = true);
    Map<String, List<MateriaModel>> h;

    if (grado == 'myschedule') {
      final uid =
          Provider.of<UsuarioProvider>(context, listen: false).usuario?.id;
      if (uid != null) {
        h = await _horarioService.obtenerHorarioDocente(uid);
      } else {
        h = {};
      }
    } else {
      h = await _horarioService.obtenerHorario(grado);
    }

    setState(() {
      gradoSeleccionado = grado;
      horario = h;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<UsuarioProvider>(context).usuario;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        title: Semantics(
          label: 'Pantalla de horario escolar',
          enabled: true,
          focusable: true,
          child: const Text('School schedule'),
        ),
        iconTheme: const IconThemeData(color: Colors.redAccent),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          if (usuario?.rol == 'docente')
            Semantics(
              label: 'Selector de grado',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  value: gradoSeleccionado,
                  items: [
                    const DropdownMenuItem(
                      value: 'myschedule',
                      child: Text('My schedule'),
                    ),
                    ...gradosColombia
                        .where((g) => g != 'No aplica')
                        .map((g) => DropdownMenuItem(value: g, child: Text(g))),
                  ],
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
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: ListView.builder(
                                itemCount: materias.length,
                                itemBuilder: (ctx, i) {
                                  final m = materias[i];
                                  return Semantics(
                                    label:
                                        'Materia ${m.materia} de ${FormatUtils.formatearHora(FormatUtils.timeOfDayDesdeTimestamp(m.horaInicio))} a ${FormatUtils.formatearHora(FormatUtils.timeOfDayDesdeTimestamp(m.horaFin))}',
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: ListTile(
                                        title: Text(m.materia),
                                        subtitle: Text(
                                          '${FormatUtils.formatearHora(FormatUtils.timeOfDayDesdeTimestamp(m.horaInicio))} - '
                                          '${FormatUtils.formatearHora(FormatUtils.timeOfDayDesdeTimestamp(m.horaFin))}',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }
}
