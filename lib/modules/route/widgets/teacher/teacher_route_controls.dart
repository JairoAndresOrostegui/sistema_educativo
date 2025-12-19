import 'package:flutter/material.dart';

import '../../../../models/route/daily_route_model.dart';

class TeacherRouteControls extends StatelessWidget {
  final RutaDiaria? dailyRoute;
  final VoidCallback onStart;
  final VoidCallback onFinalize;

  const TeacherRouteControls({
    super.key,
    required this.dailyRoute,
    required this.onStart,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    final estado = dailyRoute?.estado;

    return Column(
      children: [
        if (estado == EstadoRuta.pendiente)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar ruta'),
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        if (estado == EstadoRuta.activa) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Finalizar ruta'),
              onPressed: onFinalize,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
