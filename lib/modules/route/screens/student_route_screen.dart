import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/navigation_utils.dart';
import '../services/student_route_service.dart';
import '../utils/route_ui_helpers.dart';
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final session = context.read<UserProviderV2>().user;
      if (session == null) {
        if (mounted) setState(() => _isLoading = false);
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
        await _loadSelectedStudent(_selectedStudentId!);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        final message = routeErrorMessage(
          e,
          fallback: 'No fue posible consultar el recorrido.',
        );
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

  Future<void> _loadSelectedStudent(String studentId) async {
    final ruta = await _myRouteService.getMyDailyRoute(
      studentId: studentId,
      institutionId: _institutionId,
      campusId: _campusId,
    );
    _dailyRouteId = ruta?.id;
  }

  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _dailyRouteId = null;
    });
    await _bootstrap();
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

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final colors = Theme.of(context).colorScheme;
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          centerTitle: true,
          title: Text(
            'Mi Ruta de Hoy',
            style: TextStyle(color: colors.primary),
            semanticsLabel: 'Mi Ruta de Hoy',
          ),
          leading: BackToDashboardButton(),
          iconTheme: IconThemeData(color: colors.primary),
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

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(routeErrorMessage(e))),
                    );
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
        iconTheme: IconThemeData(color: colors.primary),
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
                    setState(() {
                      _selectedStudentId = id;
                      _dailyRouteId = null;
                      _loadError = null;
                      _isLoading = true;
                    });
                    try {
                      await RouteOperations.call('seleccionarHijoActivo', {
                        'studentId': id,
                      });
                      if (!mounted || !context.mounted) return;
                      context.read<UserProviderV2>().setActiveStudentId(id);
                      await _loadSelectedStudent(id);
                    } catch (e) {
                      _loadError = routeErrorMessage(
                        e,
                        fallback: 'No fue posible consultar este recorrido.',
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                ),

              if (_isFamily) SizedBox(height: 12),

              Expanded(
                child: (_loadError != null)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_loadError!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _retry,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : (_selectedStudentId == null)
                    ? Center(child: Text('No hay estudiantes vinculados.'))
                    : (_dailyRouteId == null)
                    ? Center(
                        child: Text(
                          'No tienes un recorrido asignado para hoy.',
                        ),
                      )
                    : RouteLiveView(
                        dailyRouteId: _dailyRouteId!,
                        studentId: _selectedStudentId!,
                        onMapCreated: _onMapCreated,
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
