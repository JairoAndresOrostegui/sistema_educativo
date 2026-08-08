import 'package:sistema_educativo/config/app_palette.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/student_route_service.dart';

class RouteLiveView extends StatelessWidget {
  final String dailyRouteId;
  final String studentId;
  final void Function(GoogleMapController) onMapCreated;
  final LatLng? teacherPosition;
  final void Function(LatLng) updateTeacherPosition;

  // helpers
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

  LatLng? _readTeacherPosition(Map<String, dynamic> data) {
    final tp = data['teacherPosition'];

    if (tp is GeoPoint) {
      return LatLng(tp.latitude, tp.longitude);
    }

    if (tp is Map) {
      final lat = tp['lat'];
      final lng = tp['lng'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final service = MyRouteService();

    return StreamBuilder<DocumentSnapshot>(
      stream: service.streamDailyRoute(dailyRouteId),
      builder: (context, routeSnap) {
        if (!routeSnap.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        if (!routeSnap.data!.exists) {
          return Center(child: Text('Ruta no encontrada.'));
        }

        final data = routeSnap.data!.data() as Map<String, dynamic>;

        final rawStatus = str(data, ['status', 'estado'], 'pending');
        final status = normalizeStatus(rawStatus);

        final routeName = str(data, [
          'routeName',
          'nombreRuta',
        ], 'Ruta escolar');

        final newPos = _readTeacherPosition(data);
        if (status == 'active' && newPos != null) {
          if (teacherPosition == null || teacherPosition != newPos) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              updateTeacherPosition(newPos);
            });
          }
        }

        return Column(
          children: [
            Expanded(
              flex: 2,
              child: Semantics(
                label: status == 'active'
                    ? 'Mapa mostrando ubicación del bus escolar.'
                    : status == 'finished'
                    ? 'La ruta ha finalizado. El mapa ya no está disponible.'
                    : 'La ruta aún no ha iniciado.',
                child: status == 'active'
                    ? GoogleMap(
                        onMapCreated: onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target:
                              teacherPosition ?? LatLng(7.119349, -73.122742),
                          zoom: 15,
                        ),
                        markers: teacherPosition != null
                            ? {
                                Marker(
                                  markerId: MarkerId('bus'),
                                  position: teacherPosition!,
                                  infoWindow: InfoWindow(
                                    title: 'Ubicación del bus',
                                  ),
                                ),
                              }
                            : {},
                      )
                    : Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            status == 'finished'
                                ? 'La ruta ha finalizado. El mapa ya no está disponible.'
                                : 'La ruta aún no ha iniciado.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 1,
              child: StreamBuilder<DocumentSnapshot>(
                stream: service.streamStudentDailyRoute(
                  dailyRouteId,
                  studentId,
                ),
                builder: (context, estSnap) {
                  if (!estSnap.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!estSnap.data!.exists) {
                    return Center(
                      child: Text('No estás asignado a esta ruta.'),
                    );
                  }

                  final est = estSnap.data!.data() as Map<String, dynamic>;
                  final picked = boolf(est, ['picked', 'recogido'], false);
                  final address = str(est, [
                    'address',
                    'direccion',
                  ], 'Sin dirección');
                  final pickedAt = ts(est, ['pickupTime', 'horaRecogida']);
                  final notices = intf(est, [
                    'arrivalNotices',
                    'avisosEnviados',
                  ], 0);

                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppPalette.error.withValues(alpha: .15),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppPalette.error.withValues(alpha: .06),
                            AppPalette.surface,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.onSurface.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  routeName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                  semanticsLabel:
                                      'Nombre de la ruta: $routeName',
                                ),
                              ),
                              StatusChip(status: status),
                            ],
                          ),
                          SizedBox(height: 8),
                          Semantics(
                            label: 'Dirección asignada: $address',
                            child: Text('Dirección: $address'),
                          ),
                          SizedBox(height: 6),
                          Semantics(
                            label: picked
                                ? 'Estado de recogida: Sí'
                                : 'Estado de recogida: No',
                            child: Text('Recogido: ${picked ? "Sí" : "No"}'),
                          ),
                          if (pickedAt != null)
                            Text(
                              'Hora de recogida: '
                              '${TimeOfDay.fromDateTime(pickedAt.toDate()).format(context)}',
                            ),
                          SizedBox(height: 6),
                          if (notices > 0) Text('Avisos enviados: $notices'),
                          Spacer(),
                          Text(
                            status == 'pending'
                                ? 'La ruta aún no inicia.'
                                : status == 'active'
                                ? 'La ruta está en camino.'
                                : 'La ruta ha finalizado por hoy.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color base;
    late final String label;

    switch (status) {
      case 'active':
        base = AppPalette.success;
        label = 'Activa';
        break;
      case 'finished':
        base = AppPalette.outline;
        label = 'Finalizada';
        break;
      default:
        base = AppPalette.warning;
        label = 'Pendiente';
    }

    return Semantics(
      label: 'Estado: $label',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: base.withValues(alpha: .12),
          border: Border.all(color: base.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(color: base, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
