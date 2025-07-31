import 'package:flutter/material.dart';

import '../../../../models/route/daily_route_model.dart';
import '../../../../models/route/route_model.dart';
import '../../../../models/route/student_route_model.dart';
import 'teacher_route_day_view.dart';

class ManageRouteBody extends StatelessWidget {
  final List<RutaModel> rutasAsignadas;
  final RutaModel? rutaSeleccionada;
  final RutaDiaria? rutaDiaActual;
  final List<EstudianteRutaDiaria> estudiantesDia;
  final Function(RutaModel) onRutaSelected;
  final Function(String, Map<String, dynamic>) onUpdateEstudiante;
  final Function(String, String) onUpdateStudentAddress;
  final VoidCallback onStartRuta;
  final VoidCallback onFinalizeRuta;
  final Function(EstudianteRutaDiaria) onToggleRecogido;
  final Function(EstudianteRutaDiaria) onSendArrivalNotice;
  final Function(EstudianteRutaDiaria) onToggleAnulado;

  const ManageRouteBody({
    super.key,
    required this.rutasAsignadas,
    required this.rutaSeleccionada,
    required this.rutaDiaActual,
    required this.estudiantesDia,
    required this.onRutaSelected,
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButtonFormField<RutaModel>(
            decoration: const InputDecoration(
              labelText: 'Selecciona una ruta',
              border: OutlineInputBorder(),
            ),
            value: rutaSeleccionada,
            items: rutasAsignadas.map((r) {
              return DropdownMenuItem(
                value: r,
                child: Text(r.nombre),
              );
            }).toList(),
            onChanged: (nuevaRuta) {
              if (nuevaRuta != null) {
                onRutaSelected(nuevaRuta);
              }
            },
          ),
          const SizedBox(height: 16),
          if (rutaDiaActual != null)
            Expanded(
              child: RutaDiaView(
                rutaDiaActual: rutaDiaActual!,
                estudiantesDia: estudiantesDia,
                onUpdateEstudiante: onUpdateEstudiante,
                onUpdateStudentAddress: onUpdateStudentAddress,
                onStartRuta: onStartRuta,
                onFinalizeRuta: onFinalizeRuta,
                onToggleRecogido: onToggleRecogido,
                onSendArrivalNotice: onSendArrivalNotice,
                onToggleAnulado: onToggleAnulado,
              ),
            ),
        ],
      ),
    );
  }
}