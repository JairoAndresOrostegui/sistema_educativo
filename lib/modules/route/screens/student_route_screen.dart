import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_V2.dart';
import '../services/student_route_service.dart';

class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({super.key});

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends State<MyRoutesScreen> {
  late final MyRouteService _myRouteService;

  GoogleMapController? _mapController;
  LatLng? _teacherPosition;

  bool _isLoading = true;
  String? _currentUserId;

  bool _isFamily = false;
  List<_StudentRef> _students = const [];
  String? _selectedStudentId;

  String? _dailyRouteId;

  late String _institutionId;
  late String _campusId;

  @override
  void initState() {
    super.initState();
    _myRouteService = MyRouteService();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final session = context.read<UserProviderV2>().user;
    if (session == null) {
      setState(() => _isLoading = false);
      return;
    }

    _currentUserId = session.id;
    _institutionId = session.institution;
    _campusId = session.campus;

    await _loadRoleAndStudents(_currentUserId!);

    _selectedStudentId ??=
        _isFamily
            ? (session.activeStudentId?.isNotEmpty == true
                ? session.activeStudentId
                : (_students.isNotEmpty ? _students.first.id : null))
            : _currentUserId;

    if (_selectedStudentId != null) {
      final ruta = await _myRouteService.getMyDailyRoute(
        studentId: _selectedStudentId!,
        institutionId: _institutionId,
        campusId: _campusId,
      );
      _dailyRouteId = ruta?.id;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadRoleAndStudents(String uid) async {
    final session = context.read<UserProviderV2>().user;
    if (session == null) return;

    if (session.role == 'Familiar') {
      _isFamily = true;
      final ids = session.studentIds ?? const <String>[];

      if (ids.isNotEmpty) {
        final users = FirebaseFirestore.instance.collection('users');
        final List<_StudentRef> list = [];

        for (final chunk in _chunks(ids, 10)) {
          final snap =
              await users
                  .where('institution', isEqualTo: _institutionId)
                  .where('campus', isEqualTo: _campusId)
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get();

          for (final d in snap.docs) {
            final u = d.data();
            final name =
                '${(u['firstName'] ?? '').toString().trim()} ${(u['lastName'] ?? '').toString().trim()}'
                    .trim();
            list.add(_StudentRef(id: d.id, name: name.isEmpty ? d.id : name));
          }
        }
        _students = list;
      } else {
        _students = const [];
      }
    } else {
      _isFamily = false;
      _students = const [];
    }
  }

  Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateTeacherPosition(LatLng pos) {
    setState(() {
      _teacherPosition = pos;
      _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
    });
  }

  String _str(Map<String, dynamic> d, List<String> keys, [String def = '']) {
    for (final k in keys) {
      final v = d[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return def;
  }

  bool _bool(Map<String, dynamic> d, List<String> keys, [bool def = false]) {
    for (final k in keys) {
      final v = d[k];
      if (v is bool) return v;
    }
    return def;
  }

  int _int(Map<String, dynamic> d, List<String> keys, [int def = 0]) {
    for (final k in keys) {
      final v = d[k];
      if (v is int) return v;
    }
    return def;
  }

  Timestamp? _ts(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is Timestamp) return v;
    }
    return null;
  }

  Map<String, dynamic>? _map(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is Map<String, dynamic>) return v;
    }
    return null;
  }

  String _normalizeStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'activa':
        return 'active';
      case 'finalizada':
        return 'finished';
      case 'pendiente':
        return 'pending';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'Mi Ruta de Hoy',
            style: TextStyle(color: Colors.red),
            semanticsLabel: 'Mi Ruta de Hoy',
          ),
          iconTheme: const IconThemeData(color: Colors.red),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'La vista del mapa solo está disponible en dispositivos móviles. '
              'Por favor, usa la aplicación en un teléfono o tablet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
              semanticsLabel:
                  'Mensaje informativo: La vista del mapa solo está disponible en dispositivos móviles.',
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUserId == null) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Usuario no autenticado. No se puede mostrar la ruta.',
            child: const Text('Usuario no autenticado.'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        title: const Text('Mi Ruta de Hoy'),
        iconTheme: const IconThemeData(color: Colors.redAccent),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_isFamily)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Selecciona estudiante',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedStudentId,
                  items:
                      _students
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                  onChanged: (id) async {
                    if (id == null) return;
                    setState(() {
                      _selectedStudentId = id;
                      _dailyRouteId = null;
                      _teacherPosition = null;
                      _isLoading = true;
                    });
                    final ruta = await _myRouteService.getMyDailyRoute(
                      studentId: id,
                      institutionId: _institutionId,
                      campusId: _campusId,
                    );
                    if (!mounted) return;
                    setState(() {
                      _dailyRouteId = ruta?.id;
                      _isLoading = false;
                    });
                  },
                ),

              if (_isFamily) const SizedBox(height: 12),

              Expanded(
                child:
                    (_selectedStudentId == null)
                        ? const Center(
                          child: Text('No hay estudiantes vinculados.'),
                        )
                        : (_dailyRouteId == null)
                        ? const Center(
                          child: Text(
                            'No hay ruta activa para hoy o no estás asignado.',
                          ),
                        )
                        : _RouteLiveView(
                          dailyRouteId: _dailyRouteId!,
                          studentId: _selectedStudentId!,
                          onMapCreated: _onMapCreated,
                          teacherPosition: _teacherPosition,
                          updateTeacherPosition: _updateTeacherPosition,
                          str: _str,
                          boolf: _bool,
                          intf: _int,
                          ts: _ts,
                          mapf: _map,
                          normalizeStatus: _normalizeStatus,
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteLiveView extends StatelessWidget {
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

  const _RouteLiveView({
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

  // <-- ELIMINAMOS _extractLatLngFlexible. Usamos SOLO 'teacherPosition'
  LatLng? _readTeacherPosition(Map<String, dynamic> data) {
    final tp = data['teacherPosition'];

    // Caso 1: GeoPoint
    if (tp is GeoPoint) {
      return LatLng(tp.latitude, tp.longitude);
    }

    // Caso 2: Map {'lat':..., 'lng':...} (por si aún lo guardas así)
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
          return const Center(child: CircularProgressIndicator());
        }
        if (!routeSnap.data!.exists) {
          return const Center(child: Text('Ruta no encontrada.'));
        }

        final data = routeSnap.data!.data() as Map<String, dynamic>;

        // status normalizado
        final rawStatus = str(data, ['status', 'estado'], 'pending');
        final status = normalizeStatus(rawStatus);

        // nombre ruta
        final routeName = str(data, [
          'routeName',
          'nombreRuta',
        ], 'Ruta escolar');

        // POSICIÓN DEL DOCENTE (SOLO 'teacherPosition')
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
            // MAPA
            Expanded(
              flex: 2,
              child: Semantics(
                label:
                    status == 'active'
                        ? 'Mapa mostrando ubicación del bus escolar.'
                        : status == 'finished'
                        ? 'La ruta ha finalizado. El mapa ya no está disponible.'
                        : 'La ruta aún no ha iniciado.',
                child:
                    status == 'active'
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
                                      markerId: const MarkerId('bus'),
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
                              status == 'finished'
                                  ? 'La ruta ha finalizado. El mapa ya no está disponible.'
                                  : 'La ruta aún no ha iniciado.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
              ),
            ),

            // INFO DEL ESTUDIANTE
            Expanded(
              flex: 1,
              child: StreamBuilder<DocumentSnapshot>(
                stream: service.streamStudentDailyRoute(
                  dailyRouteId,
                  studentId,
                ),
                builder: (context, estSnap) {
                  if (!estSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!estSnap.data!.exists) {
                    return const Center(
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
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withOpacity(.15)),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Colors.red.withOpacity(.06), Colors.white],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                  semanticsLabel:
                                      'Nombre de la ruta: $routeName',
                                ),
                              ),
                              _StatusChip(status: status),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Semantics(
                            label: 'Dirección asignada: $address',
                            child: Text('Dirección: $address'),
                          ),
                          const SizedBox(height: 6),

                          Semantics(
                            label:
                                picked
                                    ? 'Estado de recogida: Sí'
                                    : 'Estado de recogida: No',
                            child: Text('Recogido: ${picked ? "Sí" : "No"}'),
                          ),
                          if (pickedAt != null)
                            Text(
                              'Hora de recogida: '
                              '${TimeOfDay.fromDateTime(pickedAt.toDate()).format(context)}',
                            ),

                          const SizedBox(height: 6),

                          if (notices > 0) Text('Avisos enviados: $notices'),

                          const Spacer(),

                          Text(
                            status == 'pending'
                                ? 'La ruta aún no inicia.'
                                : status == 'active'
                                ? 'La ruta está en camino.'
                                : 'La ruta ha finalizado por hoy.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
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

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late final MaterialColor base;
    late final String label;

    switch (status) {
      case 'active':
        base = Colors.green;
        label = 'Activa';
        break;
      case 'finished':
        base = Colors.grey;
        label = 'Finalizada';
        break;
      default:
        base = Colors.orange;
        label = 'Pendiente';
    }

    return Semantics(
      label: 'Estado: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: base.withOpacity(.12),
          border: Border.all(color: base.withOpacity(.35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(color: base.shade700, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _StudentRef {
  final String id;
  final String name;
  const _StudentRef({required this.id, required this.name});
}
