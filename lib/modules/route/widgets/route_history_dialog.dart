import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/daily_route_service.dart';
import '../utils/route_ui_helpers.dart';

Future<void> showRouteHistory(BuildContext context, {String? studentId}) async {
  var future = RouteOperations.call('consultarHistorialRuta', {
    'studentId': ?studentId,
  });
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Avisos e historial de Rutas'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: FutureBuilder<Map<String, dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudo consultar el historial.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => setDialogState(() {
                          future = RouteOperations.call(
                            'consultarHistorialRuta',
                            {'studentId': ?studentId},
                          );
                        }),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rawItems = snapshot.data?['items'];
              final items = rawItems is List
                  ? rawItems
                        .whereType<Map>()
                        .map((value) => Map<String, dynamic>.from(value))
                        .toList()
                  : <Map<String, dynamic>>[];
              if (items.isEmpty) return const Text('Sin registros.');
              const labels = {
                'announcement': 'Aviso general del responsable',
                'address_requested': 'Cambio de parada solicitado',
                'address_approved': 'Cambio de parada aprobado',
                'address_rejected': 'Cambio de parada rechazado',
                'eta_calculated': 'Estimación calculada',
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
                children: items.map((v) {
                  final action = routeText(
                    v['action'],
                    fallback: 'Registro del recorrido',
                  );
                  final millis = v['date'];
                  final date = millis is num
                      ? DateFormat('dd/MM/yyyy HH:mm').format(
                          DateTime.fromMillisecondsSinceEpoch(millis.toInt()),
                        )
                      : 'Fecha no disponible';
                  final reason = routeText(v['reason']);
                  return ListTile(
                    title: Text(labels[action] ?? action),
                    subtitle: Text(reason.isEmpty ? date : '$date\n$reason'),
                  );
                }).toList(),
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
    ),
  );
}
