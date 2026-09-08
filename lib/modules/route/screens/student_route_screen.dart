import 'package:sistema_educativo/config/app_palette.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/navigation_utils.dart';
import '../services/student_route_service.dart';
import '../widgets/student/route_live_view.dart';
import '../widgets/route_history_dialog.dart';
import '../services/daily_route_service.dart';
import '../widgets/route_admin_tools.dart';

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
  List<_StudentRef> _students = [];
  String? _selectedStudentId;

  String? _dailyRouteId;
  String? _loadError;

  late String _institutionId;
  late String _campusId;

  @override
  void initState() {
    super.initState();
    _myRouteService = MyRouteService();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final session = context.read<UserProviderV2>().user;
      if (session == null) {
        setState(() => _isLoading = false);
        return;
      }

      _currentUserId = session.id;
      _institutionId = session.institution;
      _campusId = session.campus;

      await _loadRoleAndStudents(_currentUserId!);

      _selectedStudentId ??= _isFamily
          ? (_students.any((s) => s.id == session.activeStudentId)
                ? session.activeStudentId
                : (_students.isNotEmpty ? _students.first.id : null))
          : _currentUserId;

      if (_selectedStudentId != null) {
        if (_isFamily) {
          await RouteOperations.call('seleccionarHijoActivo', {
            'studentId': _selectedStudentId,
          });
          if (!mounted) return;
          context.read<UserProviderV2>().setActiveStudentId(
            _selectedStudentId!,
          );
        }
        final ruta = await _myRouteService.getMyDailyRoute(
          studentId: _selectedStudentId!,
          institutionId: _institutionId,
          campusId: _campusId,
        );
        _dailyRouteId = ruta?.id;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        final message = e is FirebaseFunctionsException
            ? (e.message ?? 'No fue posible consultar el recorrido.')
            : 'No fue posible consultar el recorrido.';
        setState(() {
          _isLoading = false;
          _loadError = message;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _loadRoleAndStudents(String uid) async {
    final session = context.read<UserProviderV2>().user;
    if (session == null) return;

    if (session.role == 'Familiar') {
      _isFamily = true;
      final ids = session.studentIds ?? <String>[];

      if (ids.isNotEmpty) {
        final users = FirebaseFirestore.instance.collection('user_directory');
        final List<_StudentRef> list = [];

        for (final chunk in _chunks(ids, 10)) {
          final snap = await users
              .where('institution', isEqualTo: _institutionId)
              .where('campus', isEqualTo: _campusId)
              .where('status', isEqualTo: 'activo')
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
        _students = [];
      }
    } else {
      _isFamily = false;
      _students = [];
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
        backgroundColor: AppPalette.surface,
        appBar: AppBar(
          backgroundColor: AppPalette.surface,
          centerTitle: true,
          title: Text(
            'Mi Ruta de Hoy',
            style: TextStyle(color: AppPalette.error),
            semanticsLabel: 'Mi Ruta de Hoy',
          ),
          leading: BackToDashboardButton(),
          iconTheme: IconThemeData(color: AppPalette.error),
        ),
        body: Center(
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
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUserId == null) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Usuario no autenticado. No se puede mostrar la ruta.',
            child: Text('Usuario no autenticado.'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.primary,
        centerTitle: true,
        title: Text('Mi Ruta de Hoy'),
        actions: [
          if (_isFamily && _dailyRouteId != null)
            IconButton(
              tooltip: 'Solicitar cambio de parada para hoy',
              onPressed: () async {
                final address = await routeTextDialog(
                  context,
                  'Nueva dirección para hoy',
                );
                if (!context.mounted || address == null || address.isEmpty) {
                  return;
                }
                final reason = await routeTextDialog(
                  context,
                  'Motivo del cambio',
                );
                if (!context.mounted || reason == null || reason.isEmpty) {
                  return;
                }
                try {
                  await RouteOperations.call('solicitarCambioParada', {
                    'dailyRouteId': _dailyRouteId,
                    'studentId': _selectedStudentId,
                    'address': address,
                    'reason': reason,
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Solicitud enviada. La parada no cambia hasta que el colegio la apruebe.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              icon: const Icon(Icons.edit_location_alt_outlined),
            ),
          IconButton(
            tooltip: 'Historial de recogidas',
            onPressed: () =>
                showRouteHistory(context, studentId: _selectedStudentId),
            icon: const Icon(Icons.history),
          ),
        ],
        leading: BackToDashboardButton(),
        iconTheme: IconThemeData(color: AppPalette.primary),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              if (_isFamily)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Selecciona estudiante',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _selectedStudentId,
                  items: _students
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (id) async {
                    if (id == null) return;
                    await RouteOperations.call('seleccionarHijoActivo', {
                      'studentId': id,
                    });
                    if (!mounted || !context.mounted) return;
                    context.read<UserProviderV2>().setActiveStudentId(id);
                    setState(() {
                      _selectedStudentId = id;
                      _dailyRouteId = null;
                      _loadError = null;
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

              if (_isFamily) SizedBox(height: 12),

              Expanded(
                child: (_loadError != null)
                    ? Center(
                        child: Text(_loadError!, textAlign: TextAlign.center),
                      )
                    : (_selectedStudentId == null)
                    ? Center(child: Text('No hay estudiantes vinculados.'))
                    : (_dailyRouteId == null)
                    ? Center(
                        child: Text(
                          'No hay ruta activa para hoy o no estás asignado.',
                        ),
                      )
                    : RouteLiveView(
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

class _StudentRef {
  final String id;
  final String name;
  _StudentRef({required this.id, required this.name});
}
