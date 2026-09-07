import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../route_history_dialog.dart';

class RouteLiveView extends StatelessWidget {
  final String dailyRouteId;
  final String studentId;
  final void Function(GoogleMapController) onMapCreated;
  final LatLng? teacherPosition;
  final void Function(LatLng) updateTeacherPosition;
  final String Function(Map<String, dynamic>, List<String>, [String]) str;
  final bool Function(Map<String, dynamic>, List<String>, [bool]) boolf;
  final int Function(Map<String, dynamic>, List<String>, [int]) intf;
  final Timestamp? Function(Map<String, dynamic>, List<String>) ts;
  final Map<String, dynamic>? Function(Map<String, dynamic>, List<String>) mapf;
  final String Function(String) normalizeStatus;

  const RouteLiveView({
    super.key,
    required this.dailyRouteId,
    required this.studentId,
    required this.onMapCreated,
    required this.teacherPosition,
    required this.updateTeacherPosition,
    required this.str,
    required this.boolf,
    required this.intf,
    required this.ts,
    required this.mapf,
    required this.normalizeStatus,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('daily_routes')
        .doc(dailyRouteId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, route) {
        if (route.hasError) {
          return const Center(
            child: Text(
              'No se pudo consultar el recorrido. Revisa la conexión y el hijo seleccionado.',
            ),
          );
        }
        if (!route.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = route.data!.data();
        if (data == null) {
          return const Center(child: Text('Recorrido no disponible.'));
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey('$dailyRouteId:$studentId'),
          stream: ref.collection('students').doc(studentId).snapshots(),
          builder: (context, stop) {
            if (stop.hasError) {
              return const Center(
                child: Text('No tienes acceso a esta parada.'),
              );
            }
            if (!stop.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final s = stop.data!.data();
            if (s == null) {
              return const Center(
                child: Text('Estudiante no incluido en este recorrido.'),
              );
            }
            final closed = s['recogido'] == true || s['anulado'] == true;
            final enabled =
                data['estado'] == 'activa' &&
                s['activo'] == true &&
                !closed &&
                s['mapEnabled'] == true;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  data['nombreRuta'] ?? 'Ruta escolar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Estado: ${data['estado']}'),
                const SizedBox(height: 12),
                Text(
                  s['nombre'] ?? 'Estudiante',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Parada: ${s['direccion'] ?? "Sin dirección"}'),
                Text(
                  s['recogido'] == true
                      ? 'Recogida registrada'
                      : s['anulado'] == true
                      ? 'No recogido: ${s['observacion'] ?? ""}'
                      : s['activo'] != true
                      ? 'No viaja hoy'
                      : 'Pendiente de recogida',
                ),
                const SizedBox(height: 12),
                if (enabled)
                  SizedBox(
                    height: 300,
                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: ref
                          .collection('live')
                          .doc('location')
                          .snapshots(),
                      builder: (context, location) {
                        if (location.hasError) {
                          return const Center(
                            child: Text(
                              'Ubicación no disponible. El acceso puede haber finalizado.',
                            ),
                          );
                        }
                        final value = location.data?.data();
                        final point = value?['teacherPosition'];
                        if (point is! GeoPoint) {
                          return const Center(
                            child: Text('Esperando ubicación del responsable.'),
                          );
                        }
                        final position = LatLng(
                          point.latitude,
                          point.longitude,
                        );
                        final timestamp = value?['lastUpdate'];
                        return Column(
                          children: [
                            Text(
                              timestamp is Timestamp
                                  ? 'Actualizada: ${TimeOfDay.fromDateTime(timestamp.toDate()).format(context)}. Puede haber demora por señal.'
                                  : 'Sin fecha de actualización',
                            ),
                            Expanded(
                              child: GoogleMap(
                                key: ValueKey('map:$dailyRouteId:$studentId'),
                                onMapCreated: onMapCreated,
                                initialCameraPosition: CameraPosition(
                                  target: position,
                                  zoom: 15,
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId('bus'),
                                    position: position,
                                    infoWindow: const InfoWindow(
                                      title: 'Transporte escolar',
                                    ),
                                  ),
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        closed || data['estado'] == 'finalizada'
                            ? 'El mapa ya no está disponible. Seguirás recibiendo los avisos generales y el cierre del recorrido.'
                            : 'El mapa se habilita cuando la llegada estimada es de 10 minutos o menos. Recibirás un aviso; permite las notificaciones en Inicio.',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      showRouteHistory(context, studentId: studentId),
                  icon: const Icon(Icons.history),
                  label: const Text('Avisos e historial de Rutas'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
