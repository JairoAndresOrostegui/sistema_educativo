import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../../../utils/firebase_utils.dart';

class GestionarRutaScreen extends StatefulWidget {
  const GestionarRutaScreen({super.key});
  @override
  State<GestionarRutaScreen> createState() => _GestionarRutaScreenState();
}

class _GestionarRutaScreenState extends State<GestionarRutaScreen> {
  List<DocumentSnapshot> rutasAsignadas = [];
  DocumentSnapshot? rutaSeleccionada;
  DocumentSnapshot? rutaDiaDoc;
  List<DocumentSnapshot> estudiantesDia = [];
  bool isLoading = true;
  bool _locationGranted = false;
  bool _isRequesting = false;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _cargarRutasAsignadas();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (!kIsWeb) {
      final status = await Permission.location.request();
      setState(() => _locationGranted = status.isGranted);
      if (_locationGranted &&
          rutaDiaDoc != null &&
          rutaDiaDoc!.get('estado') == 'activa') {
        _startLocationUpdates();
      }
    }
  }

  void _startLocationUpdates() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      final geo = {'lat': pos.latitude, 'lng': pos.longitude};
      await FirebaseFirestore.instance
          .collection('rutas_diarias')
          .doc(rutaDiaDoc!.id)
          .update({'posicionDocente': geo});
    });
  }

  Future<void> _cargarRutasAsignadas() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final query =
        await FirebaseFirestore.instance
            .collection('rutas')
            .where('gestionador', isEqualTo: uid)
            .get();
    setState(() {
      rutasAsignadas = query.docs;
      isLoading = false;
    });
  }

  Future<void> _cargarRutaDia(DocumentSnapshot ruta) async {
    final fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final idRutaDia = '${ruta.id}_$fechaHoy';
    final ref = FirebaseFirestore.instance
        .collection('rutas_diarias')
        .doc(idRutaDia);
    final snap = await ref.get();

    if (snap.exists) {
      final estudiantesSnap = await ref.collection('estudiantes').get();
      setState(() {
        rutaSeleccionada = ruta;
        rutaDiaDoc = snap;
        estudiantesDia = estudiantesSnap.docs;
      });
    } else {
      final dataRuta = ruta.data()! as Map<String, dynamic>;
      final idsEstudiantes = List<String>.from(dataRuta['estudiantes'] ?? []);
      final estudiantesRef = FirebaseFirestore.instance.collection('usuarios');
      final estudiantesData = <Map<String, dynamic>>[];

      for (final id in idsEstudiantes) {
        final doc = await estudiantesRef.doc(id).get();
        if (doc.exists) {
          final dataEst = doc.data()!;
          estudiantesData.add({
            'id': id,
            'nombre': '${dataEst['nombres']} ${dataEst['apellidos']}',
            'direccion': dataEst['direccionRuta'] ?? '',
            'activo': true,
            'recogido': false,
            'horaRecogida': null,
          });
        }
      }

      final user = FirebaseAuth.instance.currentUser!;
      final userSnap =
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .get();
      final nombreDocente = '${userSnap['nombres']} ${userSnap['apellidos']}';

      await ref.set({
        'idRuta': ruta.id,
        'nombreRuta': dataRuta['nombre'] ?? '',
        'fecha': Timestamp.now(),
        'gestionador': user.uid,
        'gestionadaPorNombre': nombreDocente,
        'estado': 'pendiente',
        'horaInicio': null,
        'horaFin': null,
      });

      for (final est in estudiantesData) {
        await ref.collection('estudiantes').doc(est['id']).set(est);
      }

      final estudiantesSnap = await ref.collection('estudiantes').get();
      final nuevaRutaDiaDoc = await ref.get();
      setState(() {
        rutaSeleccionada = ruta;
        rutaDiaDoc = nuevaRutaDiaDoc;
        estudiantesDia = estudiantesSnap.docs;
      });
    }
  }

  Future<void> _actualizarCampoEstudiante(
    String idEst,
    Map<String, dynamic> data,
  ) async {
    final ref = FirebaseFirestore.instance
        .collection('rutas_diarias')
        .doc(rutaDiaDoc!.id);
    await ref.collection('estudiantes').doc(idEst).update(data);
    await _cargarRutaDia(rutaSeleccionada!);
  }

  Future<void> _actualizarRutaDia(Map<String, dynamic> data) async {
    final ref = FirebaseFirestore.instance
        .collection('rutas_diarias')
        .doc(rutaDiaDoc!.id);
    await ref.update(data);
    await _cargarRutaDia(rutaSeleccionada!);
  }

  // Función para preguntar minutos manuales al docente
  Future<int?> _askEstimatedMinutes(BuildContext ctx, String message) async {
    final ctrl = TextEditingController();
    return showDialog<int>(
      context: ctx,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text('Estimación de tiempo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutos estimados',
                    hintText: 'Ej. 7',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );
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
            'Gestionar Ruta',
            style: TextStyle(color: Colors.red),
          ),
          iconTheme: const IconThemeData(color: Colors.red),
        ),
        body: const Center(
          child: Text(
            'Solo disponible en móvil: gestión de ubicación.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_locationGranted) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'Gestionar Ruta',
            style: TextStyle(color: Colors.red),
          ),
          iconTheme: const IconThemeData(color: Colors.red),
        ),

        body: Center(
          child: ElevatedButton(
            onPressed:
                _isRequesting
                    ? null
                    : () async {
                      setState(() => _isRequesting = true);
                      await _checkPermissions();
                      setState(() => _isRequesting = false);
                    },
            child: Text(
              _isRequesting ? 'Solicitando permisos...' : 'Permitir ubicación',
            ),
          ),
        ),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<DocumentSnapshot>(
              decoration: const InputDecoration(
                labelText: 'Selecciona una ruta',
              ),
              value: rutaSeleccionada,
              items:
                  rutasAsignadas.map((r) {
                    final data = r.data()! as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: r,
                      child: Text(data['nombre'] ?? 'Sin nombre'),
                    );
                  }).toList(),
              onChanged: (nuevaRuta) async {
                await _cargarRutaDia(nuevaRuta!);
                if (_locationGranted && rutaDiaDoc!['estado'] == 'activa') {
                  _startLocationUpdates();
                }
              },
            ),
            const SizedBox(height: 16),
            if (rutaDiaDoc != null) Expanded(child: _buildVistaRutaDia()),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaRutaDia() {
    final data = rutaDiaDoc!.data()! as Map<String, dynamic>;
    final estado = data['estado'] ?? 'pendiente';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ruta del día - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children:
                estudiantesDia.map((e) {
                  final direccionController = TextEditingController(
                    text: e['direccion'],
                  );
                  final recogido = e['recogido'] == true;
                  final esActivo = e['activo'] == true;

                  return ListTile(
                    title: Text(e['nombre']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          enabled: estado == 'pendiente',
                          controller: direccionController,
                          decoration: InputDecoration(
                            labelText: 'Dirección',
                            suffixIcon:
                                estado == 'pendiente'
                                    ? IconButton(
                                      icon: const Icon(Icons.save),
                                      onPressed: () async {
                                        final valor = direccionController.text;
                                        await _actualizarCampoEstudiante(e.id, {
                                          'direccion': valor,
                                        });
                                        await FirebaseFirestore.instance
                                            .collection('usuarios')
                                            .doc(e.id)
                                            .update({'direccionRuta': valor});
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Dirección actualizada',
                                            ),
                                          ),
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
                                  estado == 'pendiente'
                                      ? (val) => _actualizarCampoEstudiante(
                                        e.id,
                                        {'activo': val},
                                      )
                                      : null,
                            ),
                            const Text('Activo hoy'),
                          ],
                        ),
                        if (estado == 'activa')
                          ElevatedButton.icon(
                            icon: Icon(
                              recogido
                                  ? Icons.check_circle
                                  : Icons.directions_bus,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: recogido ? Colors.green : null,
                            ),
                            onPressed: () async {
                              if (recogido) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (ctx) => AlertDialog(
                                        title: const Text('Confirmar'),
                                        content: const Text(
                                          'Este estudiante ya fue marcado como recogido.\n¿Deseas cambiarlo?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(ctx, false),
                                            child: const Text('No'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(ctx, true),
                                            child: const Text('Sí'),
                                          ),
                                        ],
                                      ),
                                );
                                if (confirm != true) return;
                              }

                              await _actualizarCampoEstudiante(e.id, {
                                'recogido': !recogido,
                                'horaRecogida':
                                    !recogido ? Timestamp.now() : null,
                              });

                              if (!recogido) {
                                await _enviarNotificacionFCM(
                                  e.id,
                                  '✅ Estudiante recogido',
                                  'Tu hijo(a) ha sido recogido.',
                                );

                                final idx = estudiantesDia.indexOf(e);
                                try {
                                  final siguiente = estudiantesDia
                                      .skip(idx + 1)
                                      .firstWhere(
                                        (s) =>
                                            s['activo'] == true &&
                                            s['recogido'] == false,
                                      );
                                  final est2 = await _askEstimatedMinutes(
                                    context,
                                    '¿Cuántos minutos faltan para el próximo estudiante?',
                                  );
                                  final cuerpo =
                                      (est2 != null)
                                          ? 'La ruta llegará en aproximadamente $est2 min.'
                                          : 'Hora estimada no disponible.';
                                  await _enviarNotificacionFCM(
                                    siguiente['id'],
                                    '🚌 La ruta está cerca',
                                    cuerpo,
                                  );
                                } catch (_) {}
                              }
                            },
                            label: Text(
                              recogido ? 'Recogido' : 'Marcar como recogido',
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ),
        if (rutaDiaDoc!['estado'] == 'pendiente')
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar ruta'),
            onPressed: () async {
              await _actualizarRutaDia({
                'estado': 'activa',
                'horaInicio': Timestamp.now(),
              });
              if (_locationGranted) _startLocationUpdates();

              final est = await _askEstimatedMinutes(
                context,
                '¿Cuántos minutos faltan para el primer estudiante?',
              );
              final primer = estudiantesDia.firstWhere(
                (e) => e['activo'] == true && e['recogido'] == false,
              );
              if (est != null) {
                await _enviarNotificacionFCM(
                  primer['id'],
                  '⏱ Tiempo estimado de llegada',
                  'La ruta llegará en aproximadamente $est min.',
                );
              }
              for (final e in estudiantesDia.where(
                (e) => e['activo'] == true && e['id'] != primer['id'],
              )) {
                await _enviarNotificacionFCM(
                  e['id'],
                  '🚌 Ruta escolar iniciada',
                  'Ruta en camino.',
                );
              }
            },
          ),
        const SizedBox(height: 20),
        if (rutaDiaDoc!['estado'] == 'activa')
          ElevatedButton.icon(
            icon: const Icon(Icons.stop),
            label: const Text('Finalizar ruta'),
            onPressed: () async {
              for (final e in estudiantesDia.where(
                (e) => e['activo'] == true,
              )) {
                await _enviarNotificacionFCM(
                  e['id'],
                  '🏁 Ruta finalizada',
                  'La ruta escolar ha finalizado por hoy.',
                );
              }
              await _actualizarRutaDia({
                'estado': 'finalizada',
                'horaFin': Timestamp.now(),
              });
              _positionSub?.cancel();
            },
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _enviarNotificacionFCM(
    String uid,
    String titulo,
    String cuerpo,
  ) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final data = userDoc.data();
    if (data == null || data['fcmToken'] == null) return;
    await enviarNotificacionRuta(
      tokens: [data['fcmToken']],
      titulo: titulo,
      cuerpo: cuerpo,
    );
  }
}
