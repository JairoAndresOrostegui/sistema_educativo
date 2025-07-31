import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../models/route/daily_route_model.dart';
import '../../../../services/route/student_route_service.dart';

class MyRoutesBody extends StatelessWidget {
  final String userId;
  final MyRouteService myRouteService;
  final Function(GoogleMapController) onMapCreated;
  final LatLng? teacherPosition;
  final Function(LatLng) updateTeacherPosition;

  const MyRoutesBody({
    super.key,
    required this.userId,
    required this.myRouteService,
    required this.onMapCreated,
    required this.teacherPosition,
    required this.updateTeacherPosition,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RutaDiaria?>(
      future: myRouteService.getMyDailyRoute(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Semantics(
              label: 'No hay ruta activa para hoy o no estás asignado.',
              child: Text('No hay ruta activa para hoy o no estás asignado.'),
            ),
          );
        }

        final rutaDiaria = snapshot.data!;
        final rutaDiariaId = rutaDiaria.id;

        return StreamBuilder<DocumentSnapshot>(
          stream: myRouteService.streamDailyRoute(rutaDiariaId),
          builder: (context, rutaSnap) {
            if (!rutaSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = rutaSnap.data!.data() as Map<String, dynamic>;
            final String estadoRuta = data['estado'] ?? 'desconocido';
            final bool showMap = estadoRuta == 'activa';
            final geo = data['posicionDocente'];

            if (showMap &&
                geo != null &&
                geo['lat'] != null &&
                geo['lng'] != null) {
              final newPosition = LatLng(geo['lat'], geo['lng']);
              if (teacherPosition == null || teacherPosition != newPosition) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  updateTeacherPosition(newPosition);
                });
              }
            }

            return Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Semantics(
                    label:
                        showMap
                            ? 'Mapa mostrando ubicación del bus escolar.'
                            : estadoRuta == 'finalizada'
                            ? 'La ruta ha finalizado. El mapa ya no está disponible.'
                            : 'La ruta aún no ha iniciado o está en un estado no activo.',
                    child:
                        showMap
                            ? GoogleMap(
                              onMapCreated: onMapCreated,
                              initialCameraPosition: CameraPosition(
                                target:
                                    teacherPosition ??
                                    const LatLng(7.119349, -73.122742),
                                zoom: 15,
                              ),
                              markers:
                                  teacherPosition != null
                                      ? {
                                        Marker(
                                          markerId: const MarkerId('docente'),
                                          position: teacherPosition!,
                                          infoWindow: const InfoWindow(
                                            title: 'Ubicación del bus',
                                          ),
                                        ),
                                      }
                                      : {},
                            )
                            : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  estadoRuta == 'finalizada'
                                      ? 'La ruta ha finalizado. El mapa ya no está disponible.'
                                      : 'La ruta aún no ha iniciado o está en un estado no activo.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: myRouteService.streamStudentDailyRoute(
                      rutaDiariaId,
                      userId,
                    ),
                    builder: (context, estSnap) {
                      if (!estSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!estSnap.data!.exists) {
                        return Center(
                          child: Semantics(
                            label: 'No estás asignado a esta ruta.',
                            child: Text('No estás asignado a esta ruta.'),
                          ),
                        );
                      }

                      final est = estSnap.data!.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              label:
                                  'Estado de la ruta: ${data['estado'] ?? 'Desconocido'}',
                              child: Text(
                                'Estado de la Ruta: ${data['estado'] ?? 'Desconocido'}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Semantics(
                              label:
                                  'Dirección asignada: ${est['direccion'] ?? 'Sin dirección'}',
                              child: Text(
                                'Dirección Asignada: ${est['direccion'] ?? 'Sin dirección'}',
                              ),
                            ),
                            Semantics(
                              label:
                                  'Estado de recogida: ${est['recogido'] == true ? "Sí" : "No"}',
                              child: Text(
                                'Recogido: ${est['recogido'] == true ? "Sí" : "No"}',
                              ),
                            ),
                            if (est['horaRecogida'] != null)
                              Semantics(
                                label:
                                    'Hora de recogida: ${DateFormat('HH:mm').format((est['horaRecogida'] as Timestamp).toDate())}',
                                child: Text(
                                  'Hora de Recogida: ${DateFormat('HH:mm').format((est['horaRecogida'] as Timestamp).toDate())}',
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
