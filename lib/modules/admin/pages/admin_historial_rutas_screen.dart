import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminHistorialRutasScreen extends StatefulWidget {
  const AdminHistorialRutasScreen({super.key});

  @override
  State<AdminHistorialRutasScreen> createState() =>
      _AdminHistorialRutasScreenState();
}

class _AdminHistorialRutasScreenState
    extends State<AdminHistorialRutasScreen> {
  String _filtroNombre = '';

  Stream<List<Map<String, dynamic>>> _obtenerRutas() {
    final baseQuery = FirebaseFirestore.instance
        .collection('rutas_diarias')
        .where('estado', isEqualTo: 'finalizada')
        .orderBy('fecha', descending: true);

    return baseQuery.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {...doc.data(), 'docId': doc.id};
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> _cargarEstudiantes(String docId) async {
    final snap = await FirebaseFirestore.instance
        .collection('rutas_diarias')
        .doc(docId)
        .collection('estudiantes')
        .get();
    return snap.docs.map((e) => e.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de rutas finalizadas'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Filtrar por nombre de ruta',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _filtroNombre = value.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _obtenerRutas(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar rutas'));
                }

                final rutas = snapshot.data!
                    .where((ruta) {
                      final nombreRuta = (ruta['nombreRuta'] ?? '')
                          .toString()
                          .toLowerCase();
                      return _filtroNombre.isEmpty ||
                          nombreRuta.contains(_filtroNombre);
                    })
                    .toList();

                if (rutas.isEmpty) {
                  return const Center(
                    child: Text('No hay rutas finalizadas registradas.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rutas.length,
                  itemBuilder: (context, index) {
                    final ruta = rutas[index];
                    final fecha = (ruta['fecha'] as Timestamp?)?.toDate();
                    final horaInicio =
                        (ruta['horaInicio'] as Timestamp?)?.toDate();
                    final horaFin = (ruta['horaFin'] as Timestamp?)?.toDate();
                    final nombreRuta = ruta['nombreRuta'] ?? 'Sin nombre';
                    final gestionadaPor =
                        ruta['gestionadaPorNombre'] ?? 'Sin nombre';

                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cargarEstudiantes(ruta['docId']),
                      builder: (context, estudiantesSnap) {
                        final estudiantes = estudiantesSnap.data ?? [];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombreRuta,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fecha: ${fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-'}',
                                ),
                                Text('Gestionada por: $gestionadaPor'),
                                const SizedBox(height: 8),
                                Text(
                                  'Hora inicio: ${horaInicio != null ? DateFormat('HH:mm').format(horaInicio) : '-'}',
                                ),
                                Text(
                                  'Hora fin: ${horaFin != null ? DateFormat('HH:mm').format(horaFin) : '-'}',
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Estudiantes recogidos:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Divider(),
                                if (estudiantesSnap.connectionState ==
                                    ConnectionState.waiting)
                                  const Center(
                                      child: CircularProgressIndicator()),
                                ...estudiantes.map((est) {
                                  final nombre = est['nombre'] ?? '';
                                  final recogido = est['recogido'] == true;
                                  final horaRecogido =
                                      (est['horaRecogida'] is Timestamp)
                                          ? DateFormat('HH:mm').format(
                                              est['horaRecogida'].toDate())
                                          : '-';
                                  final direccion = est['direccion'] ?? '-';

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(nombre),
                                    subtitle: Text('Dirección: $direccion'),
                                    trailing: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(recogido
                                            ? '✅ Recogido'
                                            : '❌ No recogido'),
                                        Text('Hora: $horaRecogido'),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
