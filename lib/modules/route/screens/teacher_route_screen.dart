import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/route/daily_route_model.dart';
import '../../../models/route/route_model.dart';
import '../../../models/route/student_route_model.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/notification_service.dart';
import '../services/admin_route_service.dart';
import '../services/daily_route_service.dart';
import '../services/location_service.dart';
import '../widgets/teacher/teacher_route_form_dialog.dart';
import '../widgets/teacher/teacher_route_header.dart';
import '../widgets/teacher/teacher_route_student_list.dart';
import '../widgets/teacher/teacher_route_controls.dart';
import '../utils/teacher_route_helpers.dart';

class ManageRouteScreen extends StatefulWidget {
  const ManageRouteScreen({super.key});

  @override
  State<ManageRouteScreen> createState() => _ManageRouteScreenState();
}

class _ManageRouteScreenState extends State<ManageRouteScreen> {
  late final RouteService _rutaService;
  late RutaDiariaService _rutaDiariaService;
  late final LocationService _locationService;

  final ScrollController _listController = ScrollController();

  List<RouteModel> _rutasAsignadas = [];
  RouteModel? _rutaSeleccionada;
  RutaDiaria? _rutaDiaActual;
  List<EstudianteRutaDiaria> _estudiantesDia = [];
  bool _isLoading = true;
  final bool _locationGranted = true;

  bool _groupSameAddress = true;

  final Map<String, String> _addressDrafts = {};
  void _updateDraft(String studentId, String value) {
    setState(() => _addressDrafts[studentId] = value);
  }

  String _draftOrAddress(EstudianteRutaDiaria s) {
    return _addressDrafts[s.id] ?? s.direccion;
  }

  Future<List<String>> _tokensForActors(List<String> studentIds) async {
    final user = context.read<UserProviderV2>().user;
    if (user == null) return [];
    return collectTokensForActors(
      db: FirebaseFirestore.instance,
      institutionId: user.institution,
      campusId: user.campus,
      studentIds: studentIds,
    );
  }

  @override
  void initState() {
    super.initState();
    _locationService = LocationService();

    // Esperamos al primer frame para tener el context listo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    _locationService.stopLocationUpdates();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    // Instanciamos servicios con el usuario del provider (sin Auth)
    final user = context.read<UserProviderV2>().user!;
    _rutaService = RouteService();
    _rutaDiariaService = RutaDiariaService(currentUser: user);

    await _loadRutasAsignadas();
    setState(() => _isLoading = false);
  }

  Future<void> _loadRutasAsignadas() async {
    final user = context.read<UserProviderV2>().user!;
    try {
      final rutas = await _rutaService.getRutasAsignadas(
        userId: user.id,
        institutionId: user.institution,
        campusId: user.campus,
      );
      setState(() => _rutasAsignadas = rutas);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar rutas asignadas: $e')),
        );
      }
    }
  }

  Future<void> _loadRutaDia(RouteModel route) async {
    setState(() {
      _rutaSeleccionada = route;
      _isLoading = true;
      _addressDrafts.clear();
    });

    try {
      RutaDiaria? rutaDiaria = await _rutaDiariaService.getRutaDia(route.id);

      // Ya no pasamos currentUser aquí: el servicio lo tiene por constructor
      rutaDiaria ??= await _rutaDiariaService.createRutaDia(
        rutaId: route.id,
        nombreRuta: route.name,
        estudiantesIds: route.students,
      );

      final estudiantes = await _rutaDiariaService.getEstudiantesRutaDia(
        rutaDiaria.id,
      );

      setState(() {
        _rutaDiaActual = rutaDiaria;
        _estudiantesDia = estudiantes;
        _isLoading = false;
      });

      if (_locationGranted && _rutaDiaActual!.estado == EstadoRuta.activa) {
        _locationService.startLocationUpdates(_rutaDiaActual!.id);
      } else {
        _locationService.stopLocationUpdates();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _rutaDiaActual = null;
        _estudiantesDia = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar/crear ruta del día: $e')),
        );
      }
    }
  }

  
  Future<void> _reloadPreservingScroll() async {
    final offset = _listController.hasClients ? _listController.offset : 0.0;
    if (_rutaSeleccionada == null) return;
    await _loadRutaDia(_rutaSeleccionada!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listController.hasClients) {
        final max = _listController.position.maxScrollExtent;
        _listController.jumpTo(offset.clamp(0.0, max));
      }
    });
  }

  Future<void> _onUpdateEstudiante(
    String estudianteId,
    Map<String, dynamic> data,
  ) async {
    if (_rutaDiaActual == null) return;
    try {
      await _rutaDiariaService.updateEstudianteRutaDiaria(
        _rutaDiaActual!.id,
        estudianteId,
        data,
      );
      await _reloadPreservingScroll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar estudiante: $e')),
        );
      }
    }
  }

  Future<void> _onUpdateRutaDia(Map<String, dynamic> data) async {
    if (_rutaDiaActual == null) return;
    try {
      await _rutaDiariaService.updateRutaDiaria(_rutaDiaActual!.id, data);
      await _reloadPreservingScroll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar ruta del día: $e')),
        );
      }
    }
  }

  // === Dirección: guardar ===
  Future<void> _onUpdateStudentAddress(
    String studentId,
    String newAddress,
  ) async {
    final trimmed = newAddress.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La dirección no puede estar vacía')),
        );
      }
      return;
    }

    // evita escrituras innecesarias
    final current =
        _estudiantesDia.firstWhere((s) => s.id == studentId).direccion.trim();
    if (current == trimmed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La dirección es la misma.')),
        );
      }
      return;
    }

    try {
      await _onUpdateEstudiante(studentId, {'direccion': trimmed});
      await _rutaDiariaService.updateStudentAddress(studentId, trimmed);
      _addressDrafts.remove(studentId); // limpiamos el draft
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dirección actualizada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar dirección: $e')),
        );
      }
    }
  }

  // === Antes de iniciar, si hay borradores de direcciones, se guardan ===
  Future<void> _flushAddressDrafts() async {
    if (_addressDrafts.isEmpty) return;
    final entries = _addressDrafts.entries.toList();
    for (final e in entries) {
      final id = e.key;
      final addr = e.value.trim();
      if (addr.isNotEmpty) {
        await _onUpdateStudentAddress(id, addr);
      }
    }
  }

  Future<void> _onStartRuta() async {
    if (_rutaDiaActual == null) return;
    try {
      // 1) Guarda lo tipeado antes de cambiar a activa
      await _flushAddressDrafts();

      // 2) Cambia estado a activa
      await _onUpdateRutaDia({
        'estado': EstadoRuta.activa.name,
        'horaInicio': Timestamp.now(),
      });

      if (_locationGranted) {
        _locationService.startLocationUpdates(_rutaDiaActual!.id);
      }

      // 3) Notifica inicio a activos
      final activeStudents = _estudiantesDia.where((e) => e.activo).toList();
      for (final e in activeStudents) {
        final tokens = await _tokensForActors([e.id]);
        if (tokens.isNotEmpty) {
          await enviarNotificacion(
            tokens: tokens,
            titulo: '🚌 Ruta escolar iniciada',
            cuerpo: 'Ruta en camino para ${e.nombre}.',
          );
        }
      }

      // 4) ETA a próximo
      if (activeStudents.isNotEmpty) {
        final first = activeStudents.firstWhere(
          (e) => !e.recogido && !e.anulado,
          orElse: () => activeStudents.first,
        );

        if (!mounted) return;
        final estimatedMinutes = await DialogUtils.askEstimatedMinutes(
          context,
          '¿Cuántos minutos faltan para el próximo estudiante?',
        );

        final targets =
            _groupSameAddress
                ? sameAddressGroup(first, _estudiantesDia)
                : <EstudianteRutaDiaria>[first];

        final tokens = await _tokensForActors(
          targets.map((e) => e.id).toList(),
        );

        if (tokens.isNotEmpty && estimatedMinutes != null) {
          await enviarNotificacion(
            tokens: tokens,
            titulo: '⏱ Tiempo estimado de llegada',
            cuerpo: 'La ruta llegará en aproximadamente $estimatedMinutes min.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al iniciar ruta: $e')));
      }
    }
  }

  Future<void> _onFinalizeRuta() async {
    if (_rutaDiaActual == null) return;
    try {
      for (final e in _estudiantesDia.where((e) => e.activo)) {
        final tokens = await _tokensForActors([e.id]);
        if (tokens.isNotEmpty) {
          await enviarNotificacion(
            tokens: tokens,
            titulo: '🏁 Ruta finalizada',
            cuerpo: 'La ruta de ${e.nombre} ha finalizado por hoy.',
          );
        }
      }
      await _onUpdateRutaDia({
        'estado': EstadoRuta.finalizada.name,
        'horaFin': Timestamp.now(),
      });
      _locationService.stopLocationUpdates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al finalizar ruta: $e')));
      }
    }
  }

  Future<void> _onToggleRecogido(EstudianteRutaDiaria estudiante) async {
    if (_rutaDiaActual?.estado != EstadoRuta.activa) return;

    bool proceed = true;
    if (estudiante.recogido) {
      final confirm = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Confirmar',
        content:
            'Este estudiante ya fue marcado como recogido.\n¿Deseas cambiarlo?',
      );
      proceed = confirm ?? false;
    }
    if (!proceed) return;

    try {
      await _onUpdateEstudiante(estudiante.id, {
        'recogido': !estudiante.recogido,
        'horaRecogida': !estudiante.recogido ? Timestamp.now() : null,
        'anulado': false,
      });

      if (!estudiante.recogido) {
        final tokens = await _tokensForActors([estudiante.id]);
        if (tokens.isNotEmpty) {
          await enviarNotificacion(
            tokens: tokens,
            titulo: '✅ Estudiante recogido',
            cuerpo: 'Hemos recogido a ${estudiante.nombre}.',
          );
        }

        // === NUEVA LÓGICA: ETA solo cuando se cierra el grupo ===
        final groupKey = normAddress(estudiante.direccion);

        if (_groupSameAddress) {
          if (!isGroupClosed(groupKey, _estudiantesDia)) return;
        }

        final next = firstPendingOutsideGroup(groupKey, _estudiantesDia);
        if (next == null) return;

        if (!mounted) return;
        final estimatedMinutes = await DialogUtils.askEstimatedMinutes(
          context,
          '¿Cuántos minutos faltan para recoger a ${next.nombre}?',
        );

        final targets =
            _groupSameAddress
                ? sameAddressGroup(next, _estudiantesDia)
                : <EstudianteRutaDiaria>[next];

        final tokensNext = await _tokensForActors(
          targets.map((e) => e.id).toList(),
        );

        if (tokensNext.isNotEmpty) {
          await enviarNotificacion(
            tokens: tokensNext,
            titulo: '🚌 La ruta está cerca',
            cuerpo:
                (estimatedMinutes != null)
                    ? 'La ruta llegará en aproximadamente $estimatedMinutes min.'
                    : 'Hora estimada no disponible.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al marcar estudiante como recogido: $e'),
          ),
        );
      }
    }
  }

  Future<void> _onSendArrivalNotice(EstudianteRutaDiaria estudiante) async {
    if (_rutaDiaActual?.estado != EstadoRuta.activa) return;
    try {
      final tokens = await _tokensForActors([estudiante.id]);
      if (tokens.isNotEmpty) {
        await enviarNotificacion(
          tokens: tokens,
          titulo: '🚪 Aviso de ruta escolar',
          cuerpo: 'El transporte de ${estudiante.nombre} ya está esperándote.',
        );
      }
      await _onUpdateEstudiante(estudiante.id, {
        'avisoEnviado': true,
        'avisosEnviados': FieldValue.increment(1),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificación de aviso de llegada enviada'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar aviso de llegada: $e')),
        );
      }
    }
  }

  Future<void> _onToggleAnulado(EstudianteRutaDiaria estudiante) async {
    if (_rutaDiaActual?.estado != EstadoRuta.activa) return;

    final confirm = await DialogUtils.showConfirmationDialog(
      context,
      title: estudiante.anulado ? 'Reactivar estudiante' : 'Anular estudiante',
      content:
          estudiante.anulado
              ? '¿Deseas reactivar la recogida de este estudiante?'
              : '¿Estás seguro de que deseas anular la recogida de este estudiante?',
    );
    if (confirm != true) return;

    try {
      final nuevoEstadoAnulado = !estudiante.anulado;

      await _onUpdateEstudiante(estudiante.id, {
        'anulado': nuevoEstadoAnulado,
        'recogido': false,
        'horaRecogida': null,
      });

      if (nuevoEstadoAnulado) {
        final tokens = await _tokensForActors([estudiante.id]);
        if (tokens.isNotEmpty) {
          await enviarNotificacion(
            tokens: tokens,
            titulo: '🚫 Cancelación de recogida',
            cuerpo: 'Se canceló la recogida de ${estudiante.nombre} para hoy.',
          );
        }

        // === NUEVA LÓGICA: ETA solo cuando se cierra el grupo ===
        final groupKey = normAddress(estudiante.direccion);

        if (_groupSameAddress) {
          if (!isGroupClosed(groupKey, _estudiantesDia)) return;
        }

        final next = firstPendingOutsideGroup(groupKey, _estudiantesDia);
        if (next == null) return;

        if (!mounted) return;
        final estimatedMinutes = await DialogUtils.askEstimatedMinutes(
          context,
          '¿Cuántos minutos faltan para el próximo estudiante?',
        );

        final targets =
            _groupSameAddress
                ? sameAddressGroup(next, _estudiantesDia)
                : <EstudianteRutaDiaria>[next];

        final tokensNext = await _tokensForActors(
          targets.map((e) => e.id).toList(),
        );

        if (tokensNext.isNotEmpty) {
          await enviarNotificacion(
            tokens: tokensNext,
            titulo: '🚌 La ruta está cerca',
            cuerpo:
                (estimatedMinutes != null)
                    ? 'La ruta llegará en aproximadamente $estimatedMinutes min.'
                    : 'Hora estimada no disponible.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al anular estudiante: $e')),
        );
      }
    }
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        title: const Text('School route management'),
        iconTheme: const IconThemeData(color: Colors.redAccent),
        leading: const BackToDashboardButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TeacherRouteHeader(
                routes: _rutasAsignadas,
                selected: _rutaSeleccionada,
                onRouteChanged: (RouteModel? nueva) {
                  if (nueva != null) _loadRutaDia(nueva);
                },
                showGrouping: _rutaDiaActual != null,
                groupSameAddress: _groupSameAddress,
                onToggleGrouping: (v) =>
                    setState(() => _groupSameAddress = v),
              ),

              const SizedBox(height: 16),

              // Lista de estudiantes (agrupada si está ON)
              if (_rutaDiaActual != null)
                Expanded(
                  child: TeacherRouteStudentList(
                    groupSameAddress: _groupSameAddress,
                    groups: buildGroupsForUI(_estudiantesDia),
                    students: _estudiantesDia,
                    controller: _listController,
                    rutaPendiente:
                        _rutaDiaActual!.estado == EstadoRuta.pendiente,
                    rutaActiva: _rutaDiaActual!.estado == EstadoRuta.activa,
                    addressForStudent: _draftOrAddress,
                    onAddressDraftChanged: _updateDraft,
                    onAddressSubmit: _onUpdateStudentAddress,
                    onActiveChanged: (id, val) =>
                        _onUpdateEstudiante(id, {'activo': val}),
                    onToggleRecogido: _onToggleRecogido,
                    onSendArrival: _onSendArrivalNotice,
                    onToggleAnulado: _onToggleAnulado,
                  ),
                ),


              // Botones de iniciar/finalizar
              TeacherRouteControls(
                dailyRoute: _rutaDiaActual,
                onStart: _onStartRuta,
                onFinalize: _onFinalizeRuta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
