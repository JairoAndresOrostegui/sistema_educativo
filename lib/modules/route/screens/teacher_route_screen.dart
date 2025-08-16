import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/route/daily_route_model.dart';
import '../../../models/route/route_model.dart';
import '../../../models/route/student_route_model.dart';
import '../../../providers/user_provider_V2.dart';
import '../services/daily_route_service.dart';
import '../../../utils/notification_service.dart';
import '../services/location_service.dart';
import '../services/admin_route_service.dart';

// Usa tu dialog existente
import '../widgets/teacher/teacher_route_form_dialog.dart';

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
  bool _locationGranted = true;

  bool _groupSameAddress = true;

  final Map<String, String> _addressDrafts = {};

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

  // ==== Helpers de notificaciones y tokens ====

  List<String> _extractTokensFromData(Map<String, dynamic> data) {
    final out = <String>{};
    final t1 = data['fcmToken'];
    if (t1 is String && t1.trim().isNotEmpty) out.add(t1.trim());
    final tN = data['fcmTokens'];
    if (tN is List) {
      out.addAll(
        tN.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }
    return out.toList();
  }

  Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }

  Future<List<String>> _collectTokensForActors({
    required List<String> studentIds,
  }) async {
    final user = context.read<UserProviderV2>().user!;
    final inst = user.institution;
    final camp = user.campus;

    final users = FirebaseFirestore.instance.collection('users');
    final tokens = <String>{};

    // Estudiantes (por id) filtrados por institution/campus
    for (final chunk in _chunks(studentIds, 10)) {
      final snap =
          await users
              .where(FieldPath.documentId, whereIn: chunk)
              .where('institution', isEqualTo: inst)
              .where('campus', isEqualTo: camp)
              .get();
      for (final d in snap.docs) {
        tokens.addAll(_extractTokensFromData(d.data()));
      }
    }

    // Familiares activos del mismo institution/campus, con studentIds intersectando
    for (final chunk in _chunks(studentIds, 10)) {
      final famSnap =
          await users
              .where('institution', isEqualTo: inst)
              .where('campus', isEqualTo: camp)
              .where('role', isEqualTo: 'Familiar')
              .where('status', isEqualTo: 'activo')
              .where('studentIds', arrayContainsAny: chunk)
              .get();
      for (final d in famSnap.docs) {
        tokens.addAll(_extractTokensFromData(d.data()));
      }
    }

    return tokens.toList();
  }

  List<EstudianteRutaDiaria> _sameAddressGroup(EstudianteRutaDiaria ref) {
    final addr = (ref.direccion).trim().toLowerCase();
    if (addr.isEmpty) return [ref];

    return _estudiantesDia.where((e) {
      final a = (e.direccion).trim().toLowerCase();
      return e.activo && !e.recogido && !e.anulado && a == addr;
    }).toList();
  }

  // ====== NUEVOS HELPERS PARA AGRUPACIÓN/REGLAS DE ETA ======

  String _norm(String s) => s.trim().toLowerCase();

  /// Grupo completo por dirección normalizada (incluye activos e inactivos).
  List<EstudianteRutaDiaria> _groupForAddress(String addrNorm) {
    return _estudiantesDia
        .where((e) => _norm(e.direccion) == addrNorm)
        .toList();
  }

  /// Un grupo está "cerrado" si todos los ACTIVOS están recogidos o anulados.
  bool _isGroupClosed(String addrNorm) {
    final g = _groupForAddress(addrNorm);
    for (final s in g) {
      if (s.activo && !s.recogido && !s.anulado) return false;
    }
    return true;
  }

  /// Primer pendiente (activo, no recogido, no anulado) FUERA del grupo.
  EstudianteRutaDiaria? _firstPendingOutsideGroup(String addrNorm) {
    final sorted = [..._estudiantesDia]
      ..sort((a, b) => (a.orden ?? 0).compareTo(b.orden ?? 0));
    for (final s in sorted) {
      if (s.activo &&
          !s.recogido &&
          !s.anulado &&
          _norm(s.direccion) != addrNorm) {
        return s;
      }
    }
    return null;
  }

  /// Grupos para UI manteniendo orden por el primero del grupo.
  List<List<EstudianteRutaDiaria>> _buildGroupsForUI() {
    final map = <String, List<EstudianteRutaDiaria>>{};
    final sorted = [..._estudiantesDia]
      ..sort((a, b) => (a.orden ?? 0).compareTo(b.orden ?? 0));
    for (final s in sorted) {
      final base = _norm(s.direccion);
      // Dirección vacía => grupo unitario por id para no mezclar vacíos
      final key = base.isEmpty ? '__addr_empty_${s.id}' : base;
      map.putIfAbsent(key, () => []).add(s);
    }
    return map.values.toList();
  }

  // ==========================================================

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
        final tokens = await _collectTokensForActors(studentIds: [e.id]);
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

        final estimatedMinutes = await DialogUtils.askEstimatedMinutes(
          context,
          '¿Cuántos minutos faltan para el próximo estudiante?',
        );
        if (!mounted) return;

        final targets =
            _groupSameAddress
                ? _sameAddressGroup(first)
                : <EstudianteRutaDiaria>[first];

        final tokens = await _collectTokensForActors(
          studentIds: targets.map((e) => e.id).toList(),
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
        final tokens = await _collectTokensForActors(studentIds: [e.id]);
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
        final tokens = await _collectTokensForActors(
          studentIds: [estudiante.id],
        );
        if (tokens.isNotEmpty) {
          await enviarNotificacion(
            tokens: tokens,
            titulo: '✅ Estudiante recogido',
            cuerpo: 'Hemos recogido a ${estudiante.nombre}.',
          );
        }

        // === NUEVA LÓGICA: ETA solo cuando se cierra el grupo ===
        final groupKey = _norm(estudiante.direccion);

        if (_groupSameAddress) {
          // Si el grupo todavía NO está cerrado, no pedimos minutos ni mandamos ETA
          if (!_isGroupClosed(groupKey)) return;
        }

        // Grupo cerrado o agrupamiento desactivado => buscar próximo pendiente FUERA del grupo
        final next = _firstPendingOutsideGroup(groupKey);
        if (next == null) return;

        final estimatedMinutes = await DialogUtils.askEstimatedMinutes(
          context,
          '¿Cuántos minutos faltan para recoger a ${next.nombre}?',
        );
        if (!mounted) return;

        final targets =
            _groupSameAddress
                ? _sameAddressGroup(next)
                : <EstudianteRutaDiaria>[next];

        final tokensNext = await _collectTokensForActors(
          studentIds: targets.map((e) => e.id).toList(),
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
      final tokens = await _collectTokensForActors(studentIds: [estudiante.id]);
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
        final tokens = await _collectTokensForActors(
          studentIds: [estudiante.id],
        );
        if (tokens.isNotEmpty) {
          await enviarNotificacion(
            tokens: tokens,
            titulo: '🚫 Cancelación de recogida',
            cuerpo: 'Se canceló la recogida de ${estudiante.nombre} para hoy.',
          );
        }

        // === NUEVA LÓGICA: ETA solo cuando se cierra el grupo ===
        final groupKey = _norm(estudiante.direccion);

        if (_groupSameAddress) {
          if (!_isGroupClosed(groupKey)) return;
        }

        final next = _firstPendingOutsideGroup(groupKey);
        if (next == null) return;

        final estimatedMinutes = await DialogUtils.askEstimatedMinutes(
          context,
          '¿Cuántos minutos faltan para el próximo estudiante?',
        );
        if (!mounted) return;

        final targets =
            _groupSameAddress
                ? _sameAddressGroup(next)
                : <EstudianteRutaDiaria>[next];

        final tokensNext = await _collectTokensForActors(
          studentIds: targets.map((e) => e.id).toList(),
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Selector de ruta
              DropdownButtonFormField<RouteModel>(
                decoration: const InputDecoration(
                  labelText: 'Selecciona una ruta',
                  border: OutlineInputBorder(),
                ),
                value: _rutaSeleccionada,
                items:
                    _rutasAsignadas
                        .map(
                          (r) => DropdownMenuItem<RouteModel>(
                            value: r,
                            child: Text(r.name),
                          ),
                        )
                        .toList(),
                onChanged: (nueva) {
                  if (nueva != null) _loadRutaDia(nueva);
                },
              ),

              const SizedBox(height: 12),

              // Switch agrupar: SOLO si hay ruta cargada
              if (_rutaDiaActual != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Agrupar por misma dirección (solo notificaciones de aviso)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch.adaptive(
                        value: _groupSameAddress,
                        onChanged: (v) => setState(() => _groupSameAddress = v),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Lista de estudiantes (agrupada si está ON)
              if (_rutaDiaActual != null)
                Expanded(
                  child:
                      _groupSameAddress
                          ? ListView.builder(
                            controller: _listController,
                            itemCount: _buildGroupsForUI().length,
                            itemBuilder: (_, gi) {
                              final groups = _buildGroupsForUI();
                              final group = groups[gi];
                              final addr = group.first.direccion.trim();

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(.15),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.red.withOpacity(.06),
                                      Colors.white,
                                    ],
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
                                    if (addr.isNotEmpty) ...[
                                      Text(
                                        addr,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    ...List.generate(group.length, (i) {
                                      final s = group[i];
                                      final recogido = s.recogido;
                                      final esActivo = s.activo;
                                      final esAnulado = s.anulado;
                                      final rutaPendiente =
                                          _rutaDiaActual!.estado ==
                                          EstadoRuta.pendiente;
                                      final rutaActiva =
                                          _rutaDiaActual!.estado ==
                                          EstadoRuta.activa;
                                      final fieldValue =
                                          _addressDrafts[s.id] ?? s.direccion;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.nombre,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            enabled: rutaPendiente,
                                            initialValue: fieldValue,
                                            onChanged:
                                                (v) => setState(
                                                  () =>
                                                      _addressDrafts[s.id] = v,
                                                ),
                                            onFieldSubmitted:
                                                (v) => _onUpdateStudentAddress(
                                                  s.id,
                                                  v,
                                                ),
                                            decoration: InputDecoration(
                                              labelText: 'Dirección',
                                              border:
                                                  const OutlineInputBorder(),
                                              suffixIcon:
                                                  rutaPendiente
                                                      ? IconButton(
                                                        tooltip:
                                                            'Guardar dirección',
                                                        icon: const Icon(
                                                          Icons.save,
                                                        ),
                                                        onPressed: () {
                                                          final v =
                                                              _addressDrafts[s
                                                                  .id] ??
                                                              s.direccion;
                                                          _onUpdateStudentAddress(
                                                            s.id,
                                                            v,
                                                          );
                                                        },
                                                      )
                                                      : null,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Checkbox(
                                                value: esActivo,
                                                onChanged:
                                                    rutaPendiente
                                                        ? (val) =>
                                                            _onUpdateEstudiante(
                                                              s.id,
                                                              {'activo': val},
                                                            )
                                                        : null,
                                              ),
                                              const Text('Activo hoy'),
                                            ],
                                          ),
                                          if (rutaActiva) ...[
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                ElevatedButton.icon(
                                                  icon: Icon(
                                                    recogido
                                                        ? Icons.check_circle
                                                        : Icons.directions_bus,
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            recogido
                                                                ? Colors.green
                                                                : Theme.of(
                                                                  context,
                                                                ).primaryColor,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                  onPressed:
                                                      esAnulado
                                                          ? null
                                                          : () =>
                                                              _onToggleRecogido(
                                                                s,
                                                              ),
                                                  label: Text(
                                                    recogido
                                                        ? 'Recogido'
                                                        : 'Marcar como recogido',
                                                  ),
                                                ),
                                                ElevatedButton.icon(
                                                  icon: const Icon(
                                                    Icons
                                                        .notification_important,
                                                  ),
                                                  label: const Text(
                                                    'Aviso de llegada',
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            s.avisoEnviado
                                                                ? Colors.green
                                                                : Colors.amber,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                  onPressed: () async {
                                                    final confirm = await DialogUtils.showConfirmationDialog(
                                                      context,
                                                      title:
                                                          'Enviar aviso de llegada',
                                                      content:
                                                          s.avisoEnviado
                                                              ? 'Ya se ha enviado un aviso anteriormente.\n¿Deseas reenviarlo?'
                                                              : '¿Deseas enviar el aviso de llegada a este estudiante?',
                                                    );
                                                    if (confirm == true) {
                                                      _onSendArrivalNotice(s);
                                                    }
                                                  },
                                                ),
                                                ElevatedButton.icon(
                                                  icon: Icon(
                                                    esAnulado
                                                        ? Icons.block
                                                        : Icons.cancel,
                                                  ),
                                                  label: Text(
                                                    esAnulado
                                                        ? 'Anulado'
                                                        : 'Anular',
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            esAnulado
                                                                ? Colors.red
                                                                : Colors.orange,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                  onPressed:
                                                      recogido
                                                          ? null
                                                          : () =>
                                                              _onToggleAnulado(
                                                                s,
                                                              ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (i != group.length - 1) ...[
                                            const SizedBox(height: 12),
                                            const Divider(height: 1),
                                            const SizedBox(height: 12),
                                          ],
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          )
                          : ListView.builder(
                            controller: _listController,
                            itemCount: _estudiantesDia.length,
                            itemBuilder: (_, i) {
                              final s = _estudiantesDia[i];
                              final recogido = s.recogido;
                              final esActivo = s.activo;
                              final esAnulado = s.anulado;
                              final rutaPendiente =
                                  _rutaDiaActual!.estado ==
                                  EstadoRuta.pendiente;
                              final rutaActiva =
                                  _rutaDiaActual!.estado == EstadoRuta.activa;

                              final fieldValue =
                                  _addressDrafts[s.id] ?? s.direccion; // draft

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(.15),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.red.withOpacity(.06),
                                      Colors.white,
                                    ],
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
                                    Text(
                                      s.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Dirección
                                    TextFormField(
                                      enabled: rutaPendiente,
                                      initialValue: fieldValue,
                                      onChanged:
                                          (v) => setState(
                                            () => _addressDrafts[s.id] = v,
                                          ),
                                      onFieldSubmitted:
                                          (v) =>
                                              _onUpdateStudentAddress(s.id, v),
                                      decoration: InputDecoration(
                                        labelText: 'Dirección',
                                        border: const OutlineInputBorder(),
                                        suffixIcon:
                                            rutaPendiente
                                                ? IconButton(
                                                  tooltip: 'Guardar dirección',
                                                  icon: const Icon(Icons.save),
                                                  onPressed: () {
                                                    final v =
                                                        _addressDrafts[s.id] ??
                                                        s.direccion;
                                                    _onUpdateStudentAddress(
                                                      s.id,
                                                      v,
                                                    );
                                                  },
                                                )
                                                : null,
                                      ),
                                    ),

                                    // Activo hoy
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: esActivo,
                                          onChanged:
                                              rutaPendiente
                                                  ? (val) =>
                                                      _onUpdateEstudiante(
                                                        s.id,
                                                        {'activo': val},
                                                      )
                                                  : null,
                                        ),
                                        const Text('Activo hoy'),
                                      ],
                                    ),

                                    if (rutaActiva) ...[
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: Icon(
                                              recogido
                                                  ? Icons.check_circle
                                                  : Icons.directions_bus,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  recogido
                                                      ? Colors.green
                                                      : Theme.of(
                                                        context,
                                                      ).primaryColor,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed:
                                                esAnulado
                                                    ? null
                                                    : () =>
                                                        _onToggleRecogido(s),
                                            label: Text(
                                              recogido
                                                  ? 'Recogido'
                                                  : 'Marcar como recogido',
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.notification_important,
                                            ),
                                            label: const Text(
                                              'Aviso de llegada',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  s.avisoEnviado
                                                      ? Colors.green
                                                      : Colors.amber,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () async {
                                              final confirm =
                                                  await DialogUtils.showConfirmationDialog(
                                                    context,
                                                    title:
                                                        'Enviar aviso de llegada',
                                                    content:
                                                        s.avisoEnviado
                                                            ? 'Ya se ha enviado un aviso anteriormente.\n¿Deseas reenviarlo?'
                                                            : '¿Deseas enviar el aviso de llegada a este estudiante?',
                                                  );
                                              if (confirm == true) {
                                                _onSendArrivalNotice(s);
                                              }
                                            },
                                          ),
                                          ElevatedButton.icon(
                                            icon: Icon(
                                              esAnulado
                                                  ? Icons.block
                                                  : Icons.cancel,
                                            ),
                                            label: Text(
                                              esAnulado ? 'Anulado' : 'Anular',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  esAnulado
                                                      ? Colors.red
                                                      : Colors.orange,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed:
                                                recogido
                                                    ? null
                                                    : () => _onToggleAnulado(s),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                ),

              // Botones de iniciar/finalizar
              if (_rutaDiaActual?.estado == EstadoRuta.pendiente)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar ruta'),
                    onPressed: _onStartRuta,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              if (_rutaDiaActual?.estado == EstadoRuta.activa) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Finalizar ruta'),
                    onPressed: _onFinalizeRuta,
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
          ),
        ),
      ),
    );
  }
}
