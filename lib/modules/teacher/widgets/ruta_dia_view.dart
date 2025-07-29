import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/daily_route_model.dart';
import '../../../models/student_route_model.dart';
import 'student_route_item.dart';

class RutaDiaView extends StatelessWidget {
  final RutaDiaria rutaDiaActual;
  final List<EstudianteRutaDiaria> estudiantesDia;
  final Function(String, Map<String, dynamic>) onUpdateEstudiante;
  final Function(String, String) onUpdateStudentAddress;
  final VoidCallback onStartRuta;
  final VoidCallback onFinalizeRuta;
  final Function(EstudianteRutaDiaria) onToggleRecogido;
  final Function(EstudianteRutaDiaria) onSendArrivalNotice;
  final Function(EstudianteRutaDiaria) onToggleAnulado;


  const RutaDiaView({
    super.key,
    required this.rutaDiaActual,
    required this.estudiantesDia,
    required this.onUpdateEstudiante,
    required this.onUpdateStudentAddress,
    required this.onStartRuta,
    required this.onFinalizeRuta,
    required this.onToggleRecogido,
    required this.onSendArrivalNotice,
    required this.onToggleAnulado,
  });

  @override
  Widget build(BuildContext context) {
    final estado = rutaDiaActual.estado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ruta del día - ${DateFormat('yyyy-MM-dd').format(rutaDiaActual.fecha.toDate())}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: estudiantesDia.map((estudiante) {
              return EstudianteRutaItem(
                estudiante: estudiante,
                estadoRuta: estado,
                onUpdateEstudiante: onUpdateEstudiante,
                onUpdateStudentAddress: onUpdateStudentAddress,
                onToggleRecogido: onToggleRecogido,
                onSendArrivalNotice: onSendArrivalNotice,
                onToggleAnulado: onToggleAnulado,
              );
            }).toList(),
          ),
        ),
        if (estado == EstadoRuta.pendiente)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar ruta'),
              onPressed: onStartRuta,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        const SizedBox(height: 20),
        if (estado == EstadoRuta.activa)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Finalizar ruta'),
              onPressed: onFinalizeRuta,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}