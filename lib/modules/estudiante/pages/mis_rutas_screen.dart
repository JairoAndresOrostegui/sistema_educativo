import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class MisRutasScreen extends StatefulWidget {
  const MisRutasScreen({super.key});
  @override
  State<MisRutasScreen> createState() => _MisRutasScreenState();
}

class _MisRutasScreenState extends State<MisRutasScreen> {
  GoogleMapController? _mapController;
  LatLng? posicionDocente;
  bool _locationGranted = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.location.status;
    if (status.isGranted) {
      setState(() => _locationGranted = true);
    } else {
      final result = await Permission.location.request();
      setState(() => _locationGranted = result.isGranted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Usuario no autenticado.')),
      );
    }
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'Mi ruta de hoy',
            style: TextStyle(color: Colors.red),
          ),
          iconTheme: const IconThemeData(color: Colors.red),
        ),
        body: const Center(
          child: Text(
            'La vista del mapa solo está disponible en dispositivos móviles.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }
    if (!_locationGranted) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'Mi ruta de hoy',
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
          'Mi ruta de hoy',
          style: TextStyle(color: Colors.red),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('rutas_diarias')
                .where(
                  'fecha',
                  isGreaterThanOrEqualTo: DateTime.now().subtract(
                    const Duration(hours: 12),
                  ),
                )
                .where(
                  'fecha',
                  isLessThanOrEqualTo: DateTime.now().add(
                    const Duration(hours: 12),
                  ),
                )
                .where('estado', whereIn: ['activa', 'finalizada'])
                .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          return FutureBuilder<DocumentSnapshot?>(
            future: _findMiRuta(docs, uid),
            builder: (context, rutaDocSnap) {
              if (rutaDocSnap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final rutaDoc = rutaDocSnap.data;
              if (rutaDoc == null) {
                return const Center(
                  child: Text('No hay ruta activa para hoy.'),
                );
              }

              return StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('rutas_diarias')
                        .doc(rutaDoc.id)
                        .snapshots(),
                builder: (context, rutaSnap) {
                  if (!rutaSnap.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final data = rutaSnap.data!.data() as Map<String, dynamic>;

                  final geo = data['posicionDocente'];
                  if (geo != null && geo['lat'] != null && geo['lng'] != null) {
                    final nuevaPos = LatLng(geo['lat'], geo['lng']);
                    if (posicionDocente == null ||
                        posicionDocente != nuevaPos) {
                      posicionDocente = nuevaPos;
                      if (_mapController != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLng(posicionDocente!),
                        );
                      }
                    }
                  }

                  return Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: GoogleMap(
                          onMapCreated: (c) => _mapController = c,
                          initialCameraPosition: CameraPosition(
                            target:
                                posicionDocente ??
                                const LatLng(7.119349, -73.122742),
                            zoom: 15,
                          ),
                          markers:
                              posicionDocente != null
                                  ? {
                                    Marker(
                                      markerId: const MarkerId('docente'),
                                      position: posicionDocente!,
                                      infoWindow: const InfoWindow(
                                        title: 'Ubicación del bus',
                                      ),
                                    ),
                                  }
                                  : {},
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: FutureBuilder<DocumentSnapshot>(
                          future:
                              FirebaseFirestore.instance
                                  .collection('rutas_diarias')
                                  .doc(rutaDoc.id)
                                  .collection('estudiantes')
                                  .doc(uid)
                                  .get(),
                          builder: (context, estSnap) {
                            if (!estSnap.hasData)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            if (!estSnap.data!.exists)
                              return const Center(
                                child: Text('No estás asignado a esta ruta.'),
                              );
                            final est =
                                estSnap.data!.data() as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Ruta escolar iniciada'),
                                  Text('Estado: ${data['estado']}'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Dirección asignada: ${est['direccion'] ?? 'Sin dirección'}',
                                  ),
                                  Text(
                                    'Recogido: ${est['recogido'] == true ? "Sí" : "No"}',
                                  ),
                                  if (est['horaRecogida'] != null)
                                    Text(
                                      'Hora de recogida: ${DateFormat('HH:mm').format((est['horaRecogida'] as Timestamp).toDate())}',
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
        },
      ),
    );
  }

  Future<DocumentSnapshot?> _findMiRuta(
    List<DocumentSnapshot> docs,
    String uid,
  ) async {
    for (final doc in docs) {
      final estSnap =
          await FirebaseFirestore.instance
              .collection('rutas_diarias')
              .doc(doc.id)
              .collection('estudiantes')
              .doc(uid)
              .get();
      if (estSnap.exists) return doc;
    }
    return null;
  }
}
