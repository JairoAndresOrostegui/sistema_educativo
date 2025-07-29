import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// Importaciones de los modelos

// Importaciones de los servicios
import '../../../models/daily_route_model.dart';
import '../../../models/route_model.dart';
import '../../../models/student_route_model.dart';
import '../../../services/daily_route_service.dart';
import '../../../services/firebase_utils.dart';
import '../../../services/location_service.dart';
import '../../../services/route_service.dart';

// Importaciones de las utilidades

// Importaciones de los componentes del body
import '../../../services/user_token_service.dart';
import '../widgets/location_permission_denied_body.dart';
import '../widgets/teacher_route_form_body.dart';
import '../widgets/teacher_route_form_dialog.dart';
import '../widgets/web_not_supported_body.dart';

class ManageRouteScreen extends StatefulWidget {
  const ManageRouteScreen({super.key});

  @override
  State<ManageRouteScreen> createState() => _ManageRouteScreenState();
}

class _ManageRouteScreenState extends State<ManageRouteScreen> {
  // Servicios
  late final RouteService _rutaService;
  late final RutaDiariaService _rutaDiariaService;
  late final LocationService _locationService;
  late final UserTokenService _userTokenService;

  // Estado de la pantalla
  List<RutaModel> _rutasAsignadas = [];
  RutaModel? _rutaSeleccionada;
  RutaDiaria? _rutaDiaActual;
  List<EstudianteRutaDiaria> _estudiantesDia = [];
  bool _isLoading = true;
  bool _locationGranted = false;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    // Inicializar servicios
    _rutaService = RouteService();
    _rutaDiariaService = RutaDiariaService();
    _locationService = LocationService();
    _userTokenService = UserTokenService();

    _initializeScreen();
  }

  @override
  void dispose() {
    _locationService
        .stopLocationUpdates(); // Asegura detener las actualizaciones de ubicación
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _checkAndRequestLocationPermission();
    await _loadRutasAsignadas();
    setState(() => _isLoading = false);
  }

  Future<void> _checkAndRequestLocationPermission() async {
    if (kIsWeb) {
      setState(
        () => _locationGranted = true,
      ); // En web, asumimos que no hay permisos de GPS restrictivos
      return;
    }

    setState(() => _isRequestingPermission = true);
    final granted = await _locationService.requestLocationPermission();
    setState(() {
      _locationGranted = granted;
      _isRequestingPermission = false;
    });

    if (_locationGranted && _rutaDiaActual?.estado == EstadoRuta.activa) {
      _locationService.startLocationUpdates(_rutaDiaActual!.id);
    }
  }

  Future<void> _loadRutasAsignadas() async {
    try {
      final rutas = await _rutaService.getRutasAsignadas();
      setState(() {
        _rutasAsignadas = rutas;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar rutas asignadas: $e')),
        );
      }
    }
  }

  Future<void> _loadRutaDia(RutaModel ruta) async {
    setState(() {
      _rutaSeleccionada = ruta;
      _isLoading = true;
    });

    try {
      RutaDiaria? rutaDiaria = await _rutaDiariaService.getRutaDia(ruta.id);

      rutaDiaria ??= await _rutaDiariaService.createRutaDia(
        rutaId: ruta.id,
        nombreRuta: ruta.nombre,
        estudiantesIds: ruta.estudiantes,
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
      await _loadRutaDia(_rutaSeleccionada!);
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
      await _loadRutaDia(_rutaSeleccionada!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar ruta del día: $e')),
        );
      }
    }
  }

  Future<void> _onStartRuta() async {
    if (_rutaDiaActual == null) return;
    try {
      // Paso 1: Actualizar estado y hora de inicio
      await _onUpdateRutaDia({
        'estado': EstadoRuta.activa.name,
        'horaInicio': Timestamp.now(),
      });

      if (_locationGranted) {
        _locationService.startLocationUpdates(_rutaDiaActual!.id);
      }

      // Paso 2: Enviar notificación de inicio a todos los estudiantes activos
      final activeStudents = _estudiantesDia.where((e) => e.activo).toList();

      for (final e in activeStudents) {
        final List<String> tokens = await _userTokenService.getFcmTokensForUser(
          e.id,
        );
        if (tokens.isNotEmpty) {
          await enviarNotificacion(
            tokens: tokens,
            titulo: '🚌 Ruta escolar iniciada',
            cuerpo: 'Ruta en camino.',
          );
        }
      }

      // Paso 3: Preguntar minutos estimados para el primer estudiante
      if (activeStudents.isNotEmpty) {
        final firstStudent = activeStudents.firstWhere(
          (e) => !e.recogido && !e.anulado,
          orElse: () => activeStudents.first,
        );

        final estimatedMinutes = await DialogUtils.askEstimatedMinutes(
          context,
          '¿Cuántos minutos faltan para el próximo estudiante?',
        );

        if (!mounted) return;

        if (estimatedMinutes != null) {
          final List<String> firstStudentTokens = await _userTokenService
              .getFcmTokensForUser(firstStudent.id);

          if (firstStudentTokens.isNotEmpty) {
            await enviarNotificacion(
              tokens: firstStudentTokens,
              titulo: '⏱ Tiempo estimado de llegada',
              cuerpo:
                  'La ruta llegará en aproximadamente $estimatedMinutes min.',
            );
          }
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
        final List<String> studentTokens = await _userTokenService
            .getFcmTokensForUser(e.id);
        if (studentTokens.isNotEmpty) {
          await enviarNotificacion(
            tokens: studentTokens,
            titulo: '🏁 Ruta finalizada',
            cuerpo: 'La ruta escolar ha finalizado por hoy.',
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

    bool shouldProceed = true;
    if (estudiante.recogido) {
      final confirm = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Confirmar',
        content:
            'Este estudiante ya fue marcado como recogido.\n¿Deseas cambiarlo?',
      );
      shouldProceed = confirm ?? false;
    }

    if (shouldProceed) {
      try {
        await _onUpdateEstudiante(estudiante.id, {
          'recogido': !estudiante.recogido,
          'horaRecogida': !estudiante.recogido ? Timestamp.now() : null,
          'anulado': false,
        });

        if (!estudiante.recogido) {
          // Notificar recogida
          final List<String> studentTokens = await _userTokenService
              .getFcmTokensForUser(estudiante.id);
          if (studentTokens.isNotEmpty) {
            await enviarNotificacion(
              tokens: studentTokens,
              titulo: '✅ Estudiante recogido',
              cuerpo: 'Tu hijo(a) ha sido recogido.',
            );
          }

          // Buscar siguiente estudiante según orden
          final siguiente =
              _estudiantesDia
                  .where(
                    (s) =>
                        s.orden != null &&
                        s.orden! > (estudiante.orden ?? -1) &&
                        s.activo &&
                        !s.recogido &&
                        !s.anulado,
                  )
                  .toList()
                ..sort((a, b) => (a.orden ?? 0).compareTo(b.orden ?? 0));

          if (siguiente.isNotEmpty) {
            final siguienteEst = siguiente.first;
            final List<String> nextTokens = await _userTokenService
                .getFcmTokensForUser(siguienteEst.id);

            if (nextTokens.isNotEmpty) {
              final estimatedMinutes = await DialogUtils.askEstimatedMinutes(
                context,
                '¿Cuántos minutos faltan para recoger a ${siguienteEst.nombre}?',
              );

              if (!mounted) return;

              if (estimatedMinutes != null) {
                await enviarNotificacion(
                  tokens: nextTokens,
                  titulo: '🚌 La ruta está cerca',
                  cuerpo:
                      'La ruta llegará en aproximadamente $estimatedMinutes min.',
                );
              }
            }
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
  }

  Future<void> _onSendArrivalNotice(EstudianteRutaDiaria estudiante) async {
    if (_rutaDiaActual?.estado != EstadoRuta.activa) return;
    try {
      final List<String> studentTokens = await _userTokenService
          .getFcmTokensForUser(estudiante.id);
      if (studentTokens.isNotEmpty) {
        await enviarNotificacion(
          tokens: studentTokens,
          titulo: '🚪 Aviso de ruta escolar',
          cuerpo: 'El transporte escolar ya está esperándote.',
        );
      }
      await _onUpdateEstudiante(estudiante.id, {'avisoEnviado': true});
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
        final List<String> studentTokens = await _userTokenService
            .getFcmTokensForUser(estudiante.id);
        if (studentTokens.isNotEmpty) {
          await enviarNotificacion(
            tokens: studentTokens,
            titulo: '🚫 Cancelación de recogida',
            cuerpo:
                'El transporte escolar ya no podrá recogerte hoy. Lo sentimos.',
          );
        }

        final listaActualizada =
            _estudiantesDia.map((e) {
              return e.id == estudiante.id ? e.copyWith(anulado: true) : e;
            }).toList();

        final currentIndex = listaActualizada.indexWhere(
          (s) => s.id == estudiante.id,
        );

        if (currentIndex != -1) {
          for (int i = currentIndex + 1; i < listaActualizada.length; i++) {
            final next = listaActualizada[i];
            if (next.activo && !next.recogido && !next.anulado) {
              final tokens = await _userTokenService.getFcmTokensForUser(
                next.id,
              );
              if (tokens.isNotEmpty) {
                final minutos = await DialogUtils.askEstimatedMinutes(
                  context,
                  '¿Cuántos minutos faltan para el próximo estudiante?',
                );

                if (!mounted) return;

                final cuerpo =
                    (minutos != null)
                        ? 'La ruta llegará en aproximadamente $minutos min.'
                        : 'Hora estimada no disponible.';

                await enviarNotificacion(
                  tokens: tokens,
                  titulo: '🚌 La ruta está cerca',
                  cuerpo: cuerpo,
                );
              }
              break;
            }
          }
        }
      }

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al anular estudiante: $e')),
        );
      }
    }
  }

  Future<void> _onUpdateStudentAddress(
    String studentId,
    String newAddress,
  ) async {
    try {
      await _onUpdateEstudiante(studentId, {'direccion': newAddress});

      await _rutaDiariaService.updateStudentAddress(studentId, newAddress);

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

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebNotSupportedBody();
    }

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_locationGranted) {
      return LocationPermissionDeniedBody(
        isRequesting: _isRequestingPermission,
        onRequestPermission: _checkAndRequestLocationPermission,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Gestionar Ruta Escolar',
          style: TextStyle(color: Colors.red),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ManageRouteBody(
        rutasAsignadas: _rutasAsignadas,
        rutaSeleccionada: _rutaSeleccionada,
        rutaDiaActual: _rutaDiaActual,
        estudiantesDia: _estudiantesDia,
        onRutaSelected: _loadRutaDia,
        onUpdateEstudiante: _onUpdateEstudiante,
        onUpdateStudentAddress: _onUpdateStudentAddress,
        onStartRuta: _onStartRuta,
        onFinalizeRuta: _onFinalizeRuta,
        onToggleRecogido: _onToggleRecogido,
        onSendArrivalNotice: _onSendArrivalNotice,
        onToggleAnulado: _onToggleAnulado,
      ),
    );
  }
}
