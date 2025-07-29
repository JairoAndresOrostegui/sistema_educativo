// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/materia_model.dart';
import '../../../services/schedule_service.dart';

class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  final _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes'];
  final _horarioService = HorarioService();

  Map<String, List<MateriaModel>> horario = {};
  String? grado;
  bool cargando = true;
  String diaSeleccionado = 'lunes'; // Initialize with a default day

  @override
  void initState() {
    super.initState();
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
      // Ensure diaSeleccionado is a valid day from the loaded schedule,
      // or default to 'lunes' if the schedule for 'lunes' is empty
      if (!horario.containsKey(diaSeleccionado) || horario[diaSeleccionado]!.isEmpty) {
        diaSeleccionado = _dias.firstWhere((day) => horario.containsKey(day) && horario[day]!.isNotEmpty, orElse: () => 'lunes');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine if it's a web platform or a large screen for desktop view
    final esWeb = kIsWeb || MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'Mi horario escolar',
              style: TextStyle(color: Colors.red),
            ),
            // Show Dropdown for mobile (not web and small screens)
            if (!esWeb)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: DropdownButton<String>(
                  value: diaSeleccionado,
                  isDense: true,
                  underline: Container(height: 1, color: Colors.grey),
                  items: _dias.map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text(d.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (nuevoDia) {
                    setState(() => diaSeleccionado = nuevoDia!);
                  },
                ),
              ),
          ],
        ),
      ),
      body: esWeb
          // Web layout: show all days in a row
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  _dias.map((dia) => Expanded(child: _buildDia(dia))).toList(),
            )
          // Mobile layout: show only the selected day
          
          : _buildDia(diaSeleccionado),
    );
  }

  Widget _buildDia(String dia) {
    final materias = [...(horario[dia] ?? [])]
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            dia.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: materias.isEmpty
                ? const Center(child: Text('Sin materias para este día')) // Center text when no subjects
                : ListView.builder(
                    itemCount: materias.length,
                    itemBuilder: (ctx, i) {
                      final m = materias[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0), // Add vertical margin for better spacing
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const Icon(Icons.book, size: 24, color: Colors.blueAccent), // Added color to icon
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.materia,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16, // Slightly larger font for subject
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormat('HH:mm').format(m.horaInicio.toDate())} - ${DateFormat('HH:mm').format(m.horaFin.toDate())}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14, // Slightly larger font for time
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}