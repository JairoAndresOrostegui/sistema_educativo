import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/daily_route_service.dart';

Future<void> showRouteHistory(BuildContext context, {String? studentId}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Historial de recogidas'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: FutureBuilder<Map<String, dynamic>>(
          future: RouteOperations.call('consultarHistorialRuta', {
            'studentId': ?studentId,
          }),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('No se pudo consultar el historial.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = List<Map<String, dynamic>>.from(
              (snapshot.data!['items'] as List).map(
                (v) => Map<String, dynamic>.from(v),
              ),
            );
            if (items.isEmpty) return const Text('Sin registros.');
            const labels = {
              'pickup': 'Recogido',
              'absent': 'No recogido',
              'start': 'Inicio',
              'finish': 'Finalización',
              'address': 'Cambio de dirección',
              'arrival': 'Aviso de llegada',
              'eta': 'Aviso de tiempo',
              'prepared': 'Preparación',
            };
            return ListView(
              children: items
                  .map(
                    (v) => ListTile(
                      title: Text(labels[v['action']] ?? v['action']),
                      subtitle: Text(
                        '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(v['date']))}\n${v['reason'] ?? ''}',
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
